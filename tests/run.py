#!/usr/bin/env python3
"""Run the executable transcript examples used by the practical documents."""

from __future__ import annotations

import argparse
import difflib
import json
import re
import secrets
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXAMPLES = ROOT / "examples"
DEFAULT_TIMEOUT = 5
MARKER_PREFIX = "__PRACTICOS_SESSION_STATUS_"


class SessionError(RuntimeError):
    pass


@dataclass(frozen=True)
class Step:
    command: str
    expected: str


def parse_session(path: Path) -> list[Step]:
    steps: list[Step] = []
    command: str | None = None
    output: list[str] = []

    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(keepends=True), 1):
        if line.startswith("$ "):
            if command is not None:
                steps.append(Step(command, "".join(output)))
            command = line[2:].removesuffix("\n")
            output = []
            continue

        if command is None:
            if line.strip():
                raise SessionError(f"{path}:{line_number}: content before first '$ ' command")
            continue
        output.append(line)

    if command is None:
        raise SessionError(f"{path}: session contains no '$ ' commands")
    steps.append(Step(command, "".join(output)))
    return steps


def inline_regex(pattern: str) -> re.Pattern[str]:
    parts: list[str] = []
    cursor = 0
    found = False

    for match in re.finditer(r"\{\{(.*?)\}\}", pattern):
        found = True
        parts.append(re.escape(pattern[cursor : match.start()]))
        parts.append(f"(?:{match.group(1)})")
        cursor = match.end()

    if not found:
        raise SessionError(f"expected line contains '{{{{' without a complete '{{{{...}}}}' expression: {pattern!r}")

    parts.append(re.escape(pattern[cursor:]))
    try:
        return re.compile("".join(parts))
    except re.error as error:
        raise SessionError(f"invalid inline regular expression in {pattern!r}: {error}") from error


def line_matches(expected: str, actual: str) -> bool:
    expected_newline = expected.endswith("\n")
    actual_newline = actual.endswith("\n")
    if expected_newline != actual_newline:
        return False

    expected_body = expected.removesuffix("\n")
    actual_body = actual.removesuffix("\n")
    if "{{" not in expected_body:
        return expected == actual
    return inline_regex(expected_body).fullmatch(actual_body) is not None


def output_matches(expected: str, actual: str) -> bool:
    if "{{" not in expected:
        return expected == actual

    expected_lines = expected.splitlines(keepends=True)
    actual_lines = actual.splitlines(keepends=True)
    if len(expected_lines) != len(actual_lines):
        return False
    return all(line_matches(want, got) for want, got in zip(expected_lines, actual_lines))


def format_diff(expected: str, actual: str) -> str:
    return "".join(
        difflib.unified_diff(
            expected.splitlines(keepends=True),
            actual.splitlines(keepends=True),
            fromfile="expected",
            tofile="actual",
        )
    )


def load_spec(session: Path) -> dict:
    spec_path = session.with_suffix(".json")
    if not spec_path.exists():
        return {}
    try:
        return json.loads(spec_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise SessionError(f"{spec_path}: invalid JSON: {error}") from error


def run_session(session: Path) -> None:
    steps = parse_session(session)
    spec = load_spec(session)
    expected_exit_codes = spec.get("exit_codes", [0] * len(steps))
    if len(expected_exit_codes) != len(steps):
        raise SessionError(
            f"{session}: expected {len(steps)} exit_codes, got {len(expected_exit_codes)}"
        )

    timeout = float(spec.get("timeout", DEFAULT_TIMEOUT))
    marker = f"{MARKER_PREFIX}{secrets.token_hex(12)}_"
    script_parts: list[str] = []
    for step in steps:
        script_parts.append(step.command)
        script_parts.append(f"printf '{marker}%s\\n' \"$?\"")
    script = "\n".join(script_parts) + "\n"

    environment = {
        "HOME": "/tmp/practicos-home",
        "LANG": "C",
        "LC_ALL": "C",
        "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
        "TERM": "dumb",
        "TZ": "UTC",
    }
    environment.update({str(key): str(value) for key, value in spec.get("environment", {}).items()})

    with tempfile.TemporaryDirectory(prefix="practicos-") as temporary_directory:
        workdir = Path(temporary_directory) / session.parent.name
        shutil.copytree(session.parent, workdir)
        (workdir / "home").mkdir(exist_ok=True)
        environment["HOME"] = str(workdir / "home")

        try:
            completed = subprocess.run(
                ["/bin/bash", "--noprofile", "--norc", "-s"],
                cwd=workdir,
                env=environment,
                input=script,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=timeout,
            )
        except subprocess.TimeoutExpired as error:
            raise SessionError(f"{session}: timed out after {timeout:g}s") from error

    marker_text = marker
    cursor = 0
    for index, (step, expected_exit_code) in enumerate(zip(steps, expected_exit_codes), 1):
        marker_position = completed.stdout.find(marker_text, cursor)
        if marker_position == -1:
            raise SessionError(f"{session}: command {index} did not produce a status marker")

        actual_output = completed.stdout[cursor:marker_position]
        status_start = marker_position + len(marker_text)
        status_end = completed.stdout.find("\n", status_start)
        if status_end == -1:
            raise SessionError(f"{session}: malformed status marker after command {index}")
        try:
            actual_exit_code = int(completed.stdout[status_start:status_end])
        except ValueError as error:
            raise SessionError(f"{session}: malformed exit code after command {index}") from error
        cursor = status_end + 1

        if actual_exit_code != int(expected_exit_code):
            raise SessionError(
                f"{session}: command {index} exited {actual_exit_code}, expected {expected_exit_code}\n"
                f"  $ {step.command}\n"
                f"{format_diff(step.expected, actual_output)}"
            )
        if not output_matches(step.expected, actual_output):
            raise SessionError(
                f"{session}: output mismatch for command {index}\n"
                f"  $ {step.command}\n"
                f"{format_diff(step.expected, actual_output)}"
            )


def discover_sessions(selected: str | None) -> list[Path]:
    sessions = sorted((EXAMPLES / "tp1").rglob("*.session"))
    if selected is None:
        return sessions
    selected_path = Path(selected)
    if not selected_path.is_absolute():
        selected_path = ROOT / selected_path
    return [selected_path]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--session", help="run one session instead of all TP1 sessions")
    args = parser.parse_args()

    sessions = discover_sessions(args.session)
    if not sessions:
        print("no sessions found", file=sys.stderr)
        return 1

    failures = 0
    for session in sessions:
        try:
            run_session(session)
        except (OSError, SessionError) as error:
            failures += 1
            print(f"FAIL {session.relative_to(ROOT)}\n{error}", file=sys.stderr)
        else:
            print(f"PASS {session.relative_to(ROOT)}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())

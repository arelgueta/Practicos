# Transcript tests

Run the TP1 transcripts with:

```text
make test
```

Each `.session` file contains one or more commands. A line beginning with
`$ ` starts a command; the following lines are its expected combined terminal
output until the next command.

Output lines are exact by default. An output line may contain `{{...}}`; the
contents are interpreted as a raw Python regular expression and the complete
line must match. For example:

```text
-rwxr-xr-x {{\d+}} {{\S+}} {{\S+}} {{\d+}} {{.*}} hello.py
```

The optional JSON file beside a session controls timeouts, expected exit codes,
and environment variables. The runner copies the session directory to a
temporary directory before executing it, so compiled files and permission
changes do not modify the repository.

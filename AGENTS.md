# Contributor Guidance

Read [CONTEXT.md](./CONTEXT.md) before creating or revising TP material. It defines the intended role of regular TPs, inline `EXTRA` prompts, `-extra` companion documents, tracks, and bonus-point tasks.

## Extra TP introductions

Start `-extra` documents directly with their contents after the title and table
of contents. Keep prerequisites, track relationships, and measurement caveats
inside the track that needs them; do not add a document-wide generic preamble
about those topics.

## Student implementation languages

Describe student programs by their behavior and interface, leaving the
implementation language and filename extension open unless the language is the
learning objective. Use neutral command placeholders in examples; a
language-specific invocation is optional context, not a requirement.

## Terminology in Spanish material

When introducing an acronym or technical keyword in Spanish prose, clarify it
with the English expansion or term in parentheses on first use. For example,
write `ELF (Executable and Linkable Format)`. Keep the Spanish wording as the
main term and use the English parenthetical to disambiguate the concept.

## Spanish punctuation

In Spanish questions and exclamations, use only the closing question and
exclamation symbols; omit the corresponding opening symbols.

## Naturalidad de la prosa docente

Escribí con el tono claro y cercano de un profesor universitario. Explicá
directamente qué hace cada mecanismo y cuál es su consecuencia; preferí
formulaciones concretas y naturales a frases enfáticas o solemnes. En la
revisión final, reformulá expresiones como «no es un detalle decorativo»,
«no es X, sino Y» o «a mano» cuando funcionen como énfasis artificial en vez
de aportar una explicación técnica. Aplicá esta revisión por igual a las
versiones LaTeX y Typst y comprobá el texto tal como aparece en el PDF.

## Advertencias en las consignas

No agregues advertencias, precauciones ni descargos a las consignas. Indicá
directamente qué debe hacer el estudiante y qué resultado debe observar. Si la
actividad necesita un límite técnico, una condición de permisos o un recurso
de prueba, incorporalo como parte del procedimiento o del requisito, no como
una advertencia separada.

## Regular TP activities

Keep regular TP activities focused on guiding live experimentation and
understanding. Do not add hand-in artifacts such as comparison tables,
observation logs, or closing reports unless the task explicitly requests a
submission; reserve submission-oriented work for explicitly defined extra or
bonus tasks.

Place optional comparison, follow-up, and deeper-investigation questions in an
inline `EXTRA` block rather than in the main regular sequence. Keep the block
in both source versions, using `extrabox` in LaTeX and `#extra[...]` in Typst.

## Source files and included examples

Keep complete source files outside the reports under `examples/`;
the external file is the single source of truth for the code students create
and compile. Include it in both report formats: use
`\lstinputlisting{...}` in LaTeX and
`#raw(read("..."), lang: "...")` in Typst. Apply this to regular
and extra TPs alike. Keep short illustrative fragments, API declarations,
commands, and command output inline when they are not standalone source files.
When adding an example, update the corresponding CI path filter so changing
the example rebuilds the report that includes it.

## C example style

Use Java/K&R brace placement in C examples: put each opening brace on the same
line as the function, control statement, or initializer it belongs to, never on
a standalone line. Use four spaces for indentation.

## Building documents

Use the [Makefile](./Makefile) as the build entry point. It explicitly lists the document sources and provides the `pdf`, `typst`, and `all` targets; use `make all` to build both formats, or the relevant target while iterating. Do not treat generated PDFs as source files.

Keep each complete code block together on one page whenever possible. Insert a
page break before a listing or adjust nearby prose rather than leaving a code
listing split across pages.

Every document has two source versions: one LaTeX version and one Typst version. This applies to regular TPs and `-extra` TPs alike.

When adding a document, update every build and release registration point:

- Add its LaTeX source to `TEX_FILES` and its Typst source to `TYPST_FILES`.
- Update [`.github/workflows/build-pdfs.yml`](./.github/workflows/build-pdfs.yml) path filters so changes select the document.
- Add the document to the appropriate LaTeX or Typst build matrix, including its output PDF and artifact.
- Update any final release or publish condition that decides whether changed PDFs should be released.

After those updates, run the relevant Makefile target and confirm that both PDFs are produced. A document is not fully added until both source versions are built and the Makefile and GitHub Actions know about them.

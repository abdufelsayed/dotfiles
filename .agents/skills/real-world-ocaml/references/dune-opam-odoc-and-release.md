# Dune, opam, odoc, and release workflow

## Core judgment

For real OCaml work, the build graph, package metadata, test wiring, and docs are part of the design. Do not treat `dune`, `dune-project`, `*.opam`, `.mld`, or release scripts as admin debris. They decide what is public, what is installable, what is test-only, and what downstream users can actually consume.

When editing a repo:

- `dune` answers "what modules, executables, tests, parsers, stubs, and generated files exist?"
- `dune-project` answers "what packages exist, how are opam files generated, and what is repo-level metadata?"
- `*.opam` answers "what can a package depend on, build with, test with, and document with?"
- `odoc` answers "what API surface is actually documented?"

If you change code without updating the relevant metadata, you have probably only done half the job.

## Start by reading the project shape

Before editing OCaml source, inspect:

- `dune-project`
- nearby `dune` files
- root `*.opam` or `*.opam.template`
- `.ocamlformat`
- `doc/`, `*.mld`, or `index.mld`
- CI commands that run `dune build`, `dune runtest`, `dune build @doc`, `opam lint`, or `opam install . --deps-only`

Key questions:

1. Is this a single-package repo or a multi-package repo?
2. Are opam files generated from `dune-project`, checked in manually, or templated?
3. Does the repo use `Base`, `Core`, or `Stdlib`?
4. Are tests inline, expect-based, cram-based, executable-based, or mixed?
5. Are there internal libraries, private modules, Menhir parsers, or C stubs?

Do not invent a new layout if the repo already chose one.

## Greenfield Local Projects

If the user explicitly asks to create a new OCaml project in an empty directory, do not pause merely because there is no `dune-project`. Build the smallest layout that satisfies the request.

For a small library with tests:

```text
dune-project
lib/
  dune
  my_lib.ml
  my_lib.mli
test/
  dune
  test_my_lib.ml
```

Minimal `dune-project`:

```scheme
(lang dune 3.14)
(name my_project)
```

Minimal library stanza:

```scheme
(library
 (name my_lib))
```

Minimal test stanza:

```scheme
(test
 (name test_my_lib)
 (libraries my_lib))
```

Do not add `(package ...)`, `generate_opam_files`, `authors`, `maintainers`, release scripts, or opam constraints unless the user asks for an installable/publishable package. A local exercise, tool prototype, or test fixture does not need release metadata.

## Library names are not package names

Agents get this wrong constantly.

- In Dune, `(libraries ...)` refers to library names.
- In opam, `depends:` refers to opam package names.
- Those names are often related, but they are not interchangeable.

Example:

```scheme
(library
 (name mylib)
 (public_name mypkg))
```

This means:

- OCaml code in the repo links against library `mylib` or installed library `mypkg` depending on context and wrapping.
- opam dependency metadata refers to package `mypkg`, not `mylib`.

Another common pattern:

```scheme
(library
 (name cli_support)
 (public_name mypkg.cli_support)
 (package mypkg))
```

This still belongs to opam package `mypkg`, even though the installed library name is `mypkg.cli_support`.

Bad instinct:

```scheme
; Wrong mental model
(libraries cmdliner yojson)
; then in opam:
depends: [ "Cmdliner" "Yojson" ]
```

Correct:

- Dune libraries are usually lowercase library ids such as `cmdliner`, `yojson`, `base`, `stdio`.
- opam package names are also usually lowercase, but can differ from internal library names in bigger repos.
- Check the existing repo and installed package docs instead of guessing.

## `dune-project` is the repo-level source of truth

Modern repos often centralize package metadata in `dune-project` and generate opam files.

Typical high-signal fields:

```scheme
(lang dune 3.14)
(name myproj)
(generate_opam_files true)
(source (github org/myproj))
(license MIT)
(authors "Team <dev@example.com>")
(maintainers "Team <dev@example.com>")
(documentation "https://org.github.io/myproj/")
(package
 (name mypkg)
 (synopsis "Short package summary")
 (description "Longer package description")
 (depends
  (ocaml (>= 5.1))
  dune
  cmdliner
  (alcotest :with-test)
  (odoc :with-doc)))
```

Operational rules:

- If `generate_opam_files true` is present, prefer editing `dune-project` or `.opam.template`, not the generated `*.opam` file directly.
- If the repo has comments like "run `dune build @opam --auto-promote` after edits", follow that workflow.
- If multiple `(package ...)` stanzas exist, identify which package owns the code you touched before changing dependencies.

Real repo signal: `ocaml/dune` uses `generate_opam_files true`, multiple package stanzas, internal packages, and explicit comments reminding maintainers to regenerate `*.opam`.

## Dune directory stanzas: choose the smallest honest thing

Most changes boil down to editing one of these:

- `library`
- `executables` or `executable`
- `test` or `tests`
- rules for generated files
- parser/codegen stanzas like `menhir`, `ocamllex`, `foreign_stubs`

Prefer the smallest stanza that matches the intent.

### Public library

```scheme
(library
 (name interval)
 (public_name mypkg.interval)
 (libraries base sexplib0)
 (preprocess (pps ppx_jane)))
```

Use this when the library is installed for downstream use.

### Private library

```scheme
(library
 (name interval_test_support)
 (libraries base mypkg.interval alcotest))
```

No `public_name` means it is private to the workspace. This is often right for test helpers, internal build support, or implementation-only layers.

### Executable

```scheme
(executable
 (name main)
 (public_name mytool)
 (package mypkg)
 (libraries base cmdliner mypkg.interval))
```

Keep the executable thin. Business logic usually belongs in a library so it can be tested without top-level effects.

### Test executable

```scheme
(test
 (name interval_tests)
 (libraries base alcotest mypkg.interval))
```

Or multiple:

```scheme
(tests
 (names parse_tests roundtrip_tests)
 (libraries base alcotest mypkg.parser))
```

### Inline tests

```scheme
(library
 (name interval)
 (public_name mypkg.interval)
 (libraries base)
 (inline_tests)
 (preprocess (pps ppx_inline_test ppx_assert)))
```

Inline tests belong in libraries, not executables. If logic currently lives only under `bin/`, that is usually a hint to extract a library first.

### Cram tests

```scheme
(cram
 (deps %{bin:mytool}))
```

Or a repo may simply have `.t` files under a test directory with Dune cram enabled. Use cram for CLI and workflow behavior, not for pure library invariants.

## Public modules, private modules, and wrapping

When a library is public, decide what module surface it installs.

Useful knobs:

```scheme
(library
 (name mypkg)
 (public_name mypkg)
 (private_modules parser_state lexer_tables))
```

Use `private_modules` when a public library needs implementation files that should not become part of the supported API.

Also check whether the repo relies on Dune's wrapped-library behavior. In a wrapped library, modules are typically accessed under the library namespace, which is often what you want for public code.

Bad agent move:

- add a helper module file to a public library
- forget that it becomes a visible installed module
- accidentally widen the package API forever

If the module is not intentionally public, either make it private or move it to a private internal library.

## Internal libraries are a design tool, not clutter

Mature OCaml repos commonly split one repository into several libraries and packages:

- portable core library
- Unix or CLI layer
- test helper library
- parser/codegen support library
- private unstable support library

This is not overengineering when dependency boundaries differ.

Good pattern:

```scheme
; lib/core/dune
(library
 (name mypkg_core)
 (public_name mypkg.core)
 (libraries base))

; lib/unix/dune
(library
 (name mypkg_unix)
 (public_name mypkg.unix)
 (libraries base-unix mypkg.core))
```

Bad pattern:

```scheme
(library
 (name mypkg)
 (public_name mypkg)
 (libraries base base-unix cmdliner lwt yojson))
```

This forces every downstream user to inherit Unix and CLI concerns even if they only want the pure data model.

Real repo signals:

- `ocaml/opam` splits `opam-core`, `opam-format`, `opam-state`, `opam-client`, `opam-solver`, and more.
- `ocaml/dune` has many internal and public packages, including explicitly unstable private libraries.

## Preprocessing and PPX: keep it explicit and local

Preprocessing belongs in the stanza that needs it.

Typical examples:

```scheme
(library
 (name config)
 (libraries base sexplib0)
 (preprocess (pps ppx_sexp_conv)))
```

```scheme
(library
 (name ast)
 (libraries base)
 (preprocess (pps ppx_deriving.show)))
```

Rules:

- Do not add a large umbrella PPX if the repo uses narrow PPX packages already.
- Keep PPX dependencies out of packages that do not use them.
- If a type in a public `.mli` derives serialization or comparison behavior, make sure the generated functions belong in the intended API.
- Do not casually switch a project from explicit serializers to `[@@deriving]` across unrelated modules.

If a repo uses `ppx_jane`, `ppx_expect`, `ppx_inline_test`, or tightly curated PPX stacks, mirror the local style.

## Menhir, ocamllex, and generated parser code

Parser repos usually encode generation in Dune stanzas rather than scripts.

Examples:

```scheme
(menhir
 (modules parser))
```

```scheme
(ocamllex lexer)
```

Operational rules:

- Edit source grammar files, not generated parser output, unless the repo explicitly checks generated artifacts in and asks for them to be updated.
- If a generated file changes, verify whether CI expects it checked in or regenerated on demand.
- Keep parser support code in a library, not buried in an executable.
- Add parser failure tests, not just happy-path examples.

## Foreign stubs

Dune can wire C stubs directly into a library:

```scheme
(library
 (name fast_crc)
 (public_name mypkg.fast_crc)
 (foreign_stubs
  (language c)
  (names crc_stubs))
 (libraries base))
```

In larger repos you may also see flags, include fragments, discovery rules, or configurator libraries.

Agent guidance:

- Do not move C stubs into a pure portable library without noticing the portability cost.
- Check whether the package already depends on `dune-configurator`, `ctypes`, `base-unix`, or platform-specific flags.
- If build flags are generated by rules, edit the generating rule rather than hardcoding results.

Real repo signal: `janestreet/base` uses `foreign_stubs`, generated build fragments, and explicit preprocessing rather than pretending the native layer does not exist.

## Test wiring in Dune

Use Dune-native test wiring unless the repo clearly uses something else.

Common patterns:

- `inline_tests` in library stanzas
- test executables with `alcotest`, `ounit2`, or custom runners
- cram `.t` tests for CLI behavior
- expect tests via `ppx_expect`

High-signal structure:

```scheme
; lib/dune
(library
 (name parser)
 (public_name mypkg.parser)
 (libraries base)
 (inline_tests)
 (preprocess (pps ppx_inline_test ppx_expect)))

; test/dune
(library
 (name test_support)
 (libraries base mypkg.parser alcotest))

(test
 (name parser_cli_tests)
 (libraries base test_support))
```

Keep heavy testing dependencies in test-only stanzas or test-only libraries when possible.

## opam dependency discipline

In opam metadata, use real constraints tied to real needs.

Good:

```scheme
(depends
 (ocaml (>= 5.1))
 dune
 base
 (alcotest :with-test)
 (odoc :with-doc))
```

Sometimes necessary:

```scheme
(depends
 (ppxlib (>= 0.32.0)))
```

Bad:

```scheme
(depends
 (base (= v0.17.0))
 (odoc :build)
 (ocamlformat :with-test))
```

Why bad:

- strict equality constraints are hostile unless the repo genuinely requires an exact release
- `odoc` usually belongs behind `:with-doc`
- formatter/editor tools are usually not runtime or test dependencies

Remember the filters:

- `:with-test` for test-only dependencies
- `:with-doc` for documentation-only dependencies
- `:build` for build-time tools where appropriate

Do not cargo-cult all three. Use the minimum honest filter.

## Pins, local switches, and installability

When validating package metadata locally, useful commands include:

```sh
opam pin add mypkg . --no-action
opam install . --deps-only --with-test --with-doc
opam lint
```

What these answer:

- does opam understand the package metadata?
- are dependency constraints solvable?
- can the package be installed with tests and docs enabled?

For local development, repos may rely on:

- local switches
- `opam exec -- dune build`
- pins against the current checkout

Do not rewrite the workflow unless the user asked.

## odoc: docs come from interfaces

In OCaml, the public docs are usually driven by `.mli` files.

Practical rules:

- Put public doc comments in `.mli`, not only `.ml`.
- Use `.mld` pages for package overviews, tutorials, and architecture notes.
- If a type becomes abstract in the interface, make sure the docs still explain how to construct and inspect it.
- If you add a module to a public library, decide whether it should appear in docs at all.

Minimal docs support often looks like:

```scheme
(library
 (name mypkg)
 (public_name mypkg)
 (documentation))
```

And package docs may include `index.mld` or pages under `doc/`.

Useful checks:

```sh
dune build @doc
dune build @doc-private
```

`@doc-private` is useful when you intentionally need to inspect internal docs, but do not confuse that with the supported public surface.

## Release flow: boring is good

For release-facing changes, read the existing workflow before improvising. Common signals:

- `dune-release`
- `opam publish`
- GitHub Actions releasing tarballs
- `CHANGES.md` or `CHANGES`
- version sourced from VCS tags or generated modules

Typical conservative release flow:

1. update code, interfaces, docs, and metadata
2. run targeted builds and tests
3. run `dune build @opam`
4. run `opam lint`
5. build docs if public API changed
6. inspect generated diffs before promotion
7. only then consider release tooling such as `dune-release`

`dune-release` basics:

- it helps assemble release artifacts, tags, and package publication steps
- it is useful when the repo already uses it
- do not bolt it onto a repo mid-task unless the user asked for release automation work

## Good and bad examples

Good: thin binary over a testable library

```scheme
; lib/dune
(library
 (name digest_core)
 (public_name mypkg.digest_core)
 (libraries base core_unix))

; bin/dune
(executable
 (name md5)
 (public_name mypkg-md5)
 (package mypkg)
 (libraries digest_core cmdliner))
```

Bad: logic trapped in executable only

```scheme
(executable
 (name md5)
 (public_name mypkg-md5)
 (libraries base core_unix ppx_inline_test))
```

Why bad: hard to test without top-level effects, muddles test wiring, and couples CLI entrypoint to implementation.

Good: generated opam files from repo metadata

```scheme
(generate_opam_files true)
(package
 (name mypkg)
 (depends
  base
  (alcotest :with-test)
  (odoc :with-doc)))
```

Bad: hand-edit generated `mypkg.opam` while `dune-project` remains stale.

## Editing checklist for agents

- Identify the owning package before editing dependencies.
- Check whether opam files are generated.
- Distinguish Dune library names from opam package names.
- Keep pure libraries separate from Unix, CLI, parser-driver, and test layers.
- Use `public_name` only for intentionally installed libraries/executables.
- Use `private_modules` or private libraries to avoid accidental API expansion.
- Keep PPX, test, parser, and docs dependencies scoped to the stanzas that need them.
- Update `.mli` docs or `.mld` docs when public API changes.
- Inspect generated and promoted diffs manually.

## Verification

Choose the narrowest relevant commands first:

```sh
dune build <target>
dune runtest
dune build @doc
dune build @opam
opam lint
opam install . --deps-only --with-test --with-doc
```

Broaden only when the change touched package boundaries, public API, docs, generated opam, or release-facing metadata.

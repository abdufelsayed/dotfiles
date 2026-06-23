---
name: real-world-ocaml
description: "Use when writing, reviewing, refactoring, testing, documenting, packaging, or debugging real OCaml codebases: .ml/.mli, dune, dune-project, opam, ppx, odoc, modules/signatures, records, variants, GADTs, functors, Base/Core/Stdlib style, Lwt/Async/Eio, Dune tests, opam releases, or requests to make OCaml code idiomatic and production-quality."
---

# Real World OCaml

Use this skill to behave like an OCaml engineer inside real repositories while spending as few input tokens as possible. It distills Real World OCaml and mature repository practice into targeted references. Do not treat OCaml as syntax plus pattern matching. Shape types, module boundaries, public interfaces, build metadata, and tests before filling in implementation details.

## Token Discipline

Default to the smallest useful context.

- For a tiny, obvious edit in a familiar repo, read no reference unless the code shape is risky.
- For an unfamiliar repo, read `references/orientation.md` first, then at most one topic reference.
- For API/build/architecture changes, read only the 2-3 references that match the change surface.
- For broad reviews, migrations, packaging, or type-system design, use `scripts/ref-search.py` before opening long references.
- Never load all references "just in case." Search first, open narrowly, then expand only when blocked.

Each reference has YAML frontmatter with `summary`, `load_when`, `skip_when`, and `search_terms`. Treat that frontmatter as the routing contract. Prefer `scripts/ref-search.py --list` or a targeted query over opening reference files to inspect their purpose.

## First Pass

Before changing OCaml code:

1. Inspect `dune-project`, nearest `dune`, `*.opam`, `.ocamlformat`, `.mli`, tests, docs, and PPX stanzas.
2. If no OCaml metadata exists and the user did not ask for a new project, clarify before scaffolding. If creation is explicit, use a minimal local Dune layout.
3. Detect dialect and runtime: Stdlib/Base/Core; sync/Lwt/Async/Eio; public/private/test/executable/package.
4. Read `.mli` before `.ml`; update both when public behavior changes.
5. Preserve boundaries: do not casually add Unix, threads, Lwt, Async, Eio, PPX, Base, or Core to portable libraries.
6. Select references from the routing table below, inspect frontmatter with `python3 scripts/ref-search.py --list`, or run `python3 scripts/ref-search.py "<query>"`.
7. Verify with the narrowest Dune/opam target first; broaden only for public API, package, docs, or shared behavior.

## Reference Map

Open only what matches the task:

- New/unfamiliar repo audit: `orientation.md`.
- Function signatures, labels, optional args, pipelines: `functions-labels-and-api-shape.md`.
- Pattern matching, list recursion, folds, exhaustiveness: `patterns-lists-and-recursion.md`.
- Domain modeling with records/variants/polymorphic variants: `records-variants-and-domain-modeling.md`.
- GADTs, typed ASTs, witnesses, existentials: `gadts-type-witnesses-and-existentials.md`.
- `.mli`, abstract types, modules, `open`, `include`: `modules-signatures-and-interfaces.md`.
- Functors, first-class modules, objects/classes: `functors-first-class-modules-and-objects.md`.
- Errors, `option`/`result`, exceptions, cleanup: `errors-results-exceptions-and-resource-safety.md`.
- Map/Set/Hashtbl, comparators, equality, polymorphic compare: `collections-comparators-maps-and-hashtables.md`.
- Sexps, JSON, deriving, parsers, Menhir/ocamllex: `serialization-json-sexps-and-parsing.md`.
- Tests, expect, cram, properties, deterministic output: `testing-expect-cram-and-properties.md`.
- Lwt/Async/Eio, blocking IO, cancellation, backpressure: `concurrency-io-and-effects.md`.
- Allocation, representation, GC, perf hot paths: `runtime-memory-gc-and-performance.md`.
- PPX, generated code, compiler internals, FFI/stubs: `compiler-ppx-ffi-and-codegen.md`.
- Dune, opam, odoc, release metadata: `dune-opam-odoc-and-release.md`.
- Mature repo style and agent anti-patterns: `real-repo-patterns-and-agent-pitfalls.md`.

If uncertain, run:

```bash
python3 /path/to/real-world-ocaml/scripts/ref-search.py "typed AST equality witness"
```

Then open the reported file around the best heading. If the top hit is a `metadata` hit, read that file's frontmatter first; if it matches, open the relevant section.

## Working Rules

- Follow the repository's existing dialect. Do not convert a Stdlib project to Base/Core, an Lwt project to Eio, or a simple module into a functor stack without a real design reason.
- Treat `.mli` files as public contracts and documentation sources. If there is no `.mli`, infer whether the module is intentionally private before exposing more surface.
- Avoid vague `Util`, `Common`, and grab-bag helper modules. Prefer names that encode domain, package, backend, or abstraction boundaries.
- Do not hide compiler warnings with catch-all patterns, ignored values, broad opens, or weak type annotations. Let the type checker help.
- When adding dependencies, understand whether Dune needs a library name and opam needs a package name; they are often not the same.
- In a greenfield or no-existing-metadata case, distinguish "edit this repo" from "create a new project here." If creation is explicit, use the smallest honest Dune layout, usually library-first plus tests; add `bin/`, opam package stanzas, docs, or release metadata only when the request needs them. If creation is not explicit, clarify before scaffolding.
- For public or release-facing changes, check docs, changelog/release notes, generated opam files, and package constraints.

## Verification

Choose verification from the change surface:

- Narrow code changes: `dune build <target>` or `dune exec <exe> -- <args>`.
- Tests: `dune runtest`, a specific `@runtest` alias, or a specific cram/expect test target.
- Formatting: `dune build @fmt` then promote only when the user has approved file changes.
- Docs: `dune build @doc` or relevant odoc targets.
- Packages: `dune build @opam`, `opam lint`, `opam install . --deps-only --with-test --with-doc`, or package-specific CI commands when release-facing.

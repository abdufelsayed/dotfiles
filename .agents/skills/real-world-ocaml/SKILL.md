---
name: real-world-ocaml
description: "Use when writing, reviewing, refactoring, testing, documenting, packaging, or debugging real OCaml codebases: .ml/.mli, dune, dune-project, opam, ppx, odoc, modules/signatures, records, variants, GADTs, functors, Base/Core/Stdlib style, Lwt/Async/Eio, Dune tests, opam releases, or requests to make OCaml code idiomatic and production-quality."
---

# Real World OCaml

Use this skill to behave like an OCaml engineer inside real repositories. It distills Real World OCaml and mature repository practice into operational guidance for agents. Do not treat OCaml as syntax plus pattern matching. Shape types, module boundaries, public interfaces, build metadata, and tests before filling in implementation details.

## First Pass

Before changing OCaml code:

1. Inspect `dune-project`, local `dune` files, `*.opam`, `.ocamlformat`, `.mli`, test directories, docs, and PPX stanzas.
   If no OCaml project metadata is present and the user did not explicitly ask for a new project, stop and clarify whether to create one rather than assuming an existing layout. If the user did ask for a new project, proceed with a minimal local Dune layout.
2. Detect the local style: Stdlib, Base, or Core; Lwt, Async, Eio, or synchronous IO; public library, private library, executable, test, or tooling package.
3. Read the `.mli` before the `.ml`; update both when changing public behavior.
4. Preserve package and dependency boundaries. Do not add Unix, threads, Lwt, Async, Eio, PPX, or Base/Core dependencies to portable core libraries casually.
5. Prefer type and API design first: model impossible states out, expose abstract types when invariants matter, and design for call sites.
6. Load only the topic references needed for the task.
7. Verify with the narrowest relevant Dune/opam target first, then broaden when the change touches public API, package metadata, docs, or tests.

Start with `references/orientation.md` for the complete repo audit workflow and reference map.

## Reference Map

- `references/functions-labels-and-api-shape.md`: function shape, labeled/optional arguments, call-site design, argument order, partial application.
- `references/patterns-lists-and-recursion.md`: pattern matching, list recursion, folds, tail recursion, match exhaustiveness.
- `references/records-variants-and-domain-modeling.md`: records, variants, polymorphic variants, embedded records, domain modeling, refactoring hazards.
- `references/gadts-type-witnesses-and-existentials.md`: GADTs, locally abstract types, polymorphic recursion, typed ASTs, equality witnesses, existentials.
- `references/modules-signatures-and-interfaces.md`: files as modules, `.mli` contracts, abstract types, nested modules, openings, includes.
- `references/functors-first-class-modules-and-objects.md`: functors, first-class modules, sharing constraints, destructive substitution, object use cases.
- `references/errors-results-exceptions-and-resource-safety.md`: `option`, `result`, `Error.t`, `Or_error`, exceptions, cleanup, resource safety.
- `references/collections-comparators-maps-and-hashtables.md`: maps, sets, hashtables, comparator witnesses, explicit equality, polymorphic compare pitfalls.
- `references/serialization-json-sexps-and-parsing.md`: sexps, JSON, ppx deriving, ATD, ocamllex, Menhir, parser boundaries.
- `references/testing-expect-cram-and-properties.md`: inline tests, expect tests, property tests, cram tests, deterministic test output.
- `references/concurrency-io-and-effects.md`: Async, Lwt, Eio, blocking IO, cancellation, scheduler entrypoints, concurrency boundaries.
- `references/runtime-memory-gc-and-performance.md`: runtime representation, allocation, polymorphic comparison cost, GC, tail recursion, performance checks.
- `references/compiler-ppx-ffi-and-codegen.md`: compiler frontend/backend, PPX, generated code, FFI, stubs, runtime/debug tooling.
- `references/dune-opam-odoc-and-release.md`: Dune structure, opam metadata, generated opam files, odoc, ocamlformat, release etiquette.
- `references/real-repo-patterns-and-agent-pitfalls.md`: patterns from mature OCaml repos and mistakes agents commonly make.

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

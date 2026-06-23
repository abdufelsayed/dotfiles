# Orientation

## What This Skill Is For

Real OCaml work is rarely blocked on syntax. It is blocked on misunderstanding a repo's types, module boundaries, package layers, or test surface. Before editing, locate the public contract, the owning Dune stanza, the local dialect (`Stdlib` vs `Base/Core`), the runtime model, and the nearest existing example of the same kind of code.

If you skip that audit, you usually produce code that compiles locally and is architecturally wrong.

## First Pass

Read these in roughly this order:

1. `dune-project`
2. the nearest `dune` files
3. the target module's `.mli`, if present
4. the target module's `.ml`
5. nearby tests
6. the nearest similar module elsewhere in the repo
7. `*.opam` files if dependencies, packages, or installable artifacts may change

In OCaml, file layout and Dune stanzas often explain the architecture better than prose comments do.

## Greenfield Or Empty Directories

If no OCaml metadata exists, first decide whether the user asked to create a project or merely asked to change code.

- Explicit creation request: proceed with a minimal local Dune layout.
- Ambiguous edit request in an empty directory: clarify before scaffolding.
- Existing non-OCaml repo: ask where the OCaml component belongs unless the target path is clear.

For explicit creation, keep the layout honest:

```text
dune-project
lib/
  dune
  name.ml
  name.mli
test/
  dune
  test_name.ml
```

Add `bin/` only for an executable, opam package stanzas only for an installable package, PPX only when it buys clear value, and public release metadata only when the user is actually building something publishable.

## What To Learn From `dune-project`

Use `dune-project` to answer:

- is this one package or many?
- is `generate_opam_files` enabled?
- which Dune language version and extensions are in play?
- is the repo library-first, executable-first, parser-heavy, or test-heavy?
- are there clues about cram, mdx, Menhir, docs, PPX, or generated code?

If the repo exposes several packages, do not treat it as one unit. A change may belong in a private library, a backend package, or a test helper rather than the public API.

## What To Learn From Local `dune` Files

Every local `dune` file is an architecture document. Read it for:

- `library`, `executable`, `test`, and `rule` stanzas
- `public_name` vs internal `name`
- `libraries`
- `preprocess`
- `private_modules`
- `wrapped`
- `modules` filters
- inline tests, cram wiring, or generated rules

Questions to answer:

- which library or executable owns this file?
- is the module public, private, or test-only?
- does the repo already have an internal namespace convention?
- would a new dependency belong here, or in a higher package?

Do not add a module until you know which stanza compiles it.

## Detect The Local Dialect

Preserve the house style.

### Stdlib-style repos often show:

- `Stdlib`, `Result`, `Option`, `Map.Make`, `Set.Make`
- lighter PPX use
- `Format`, `Logs`, `Fmt`, `Cmdliner`, `Alcotest`, `Yojson`, and similar libraries
- fewer comparator witnesses and fewer pervasive labeled arguments

### Base/Core-style repos often show:

- `open Base` or `open Core`
- labeled APIs almost everywhere
- `Error.t`, `Or_error.t`, `Comparator.S`, `Comparable.S`
- `ppx_jane`, `ppx_inline_test`, sexp support, expect tests
- explicit comparator modules for `Map` and `Set`

Do not rewrite a Stdlib repo into Base idioms, or a Base repo into Stdlib idioms, unless the user asked for that migration.

## Detect The Runtime Model

Before changing behavior, determine whether the repo is synchronous, `Lwt`, `Async`, `Eio`, or multicore/effects aware. Do not casually cross these boundaries. A helper that blocks or performs Unix IO in the wrong layer can violate the repo's design.

## Read Interfaces Before Implementations

If a module has both `.mli` and `.ml`, read the `.mli` first and treat it as the contract. It tells you which types are abstract, which constructors are hidden, which nested modules are public, and whether the change is internal or API-visible. If public behavior changes, update both files.

If there is no `.mli`, do not assume the module is public. Many repos intentionally leave private modules interface-free.

## Find The Nearest Similar Module

Before inventing structure, search for:

- another parser module
- another backend split
- another `Intf` or signature file
- another `Make` functor
- another test of the same style
- another core-vs-Unix or core-vs-backend package split

In mature OCaml repos, repetition is often policy. Copy the local pattern unless the user asked for redesign.

## Smells To Notice Early

Watch for these before you edit:

- public modules without `.mli`
- new dependencies being pulled into portable core libraries
- `Util`, `Common`, or `Helpers` modules growing without a real abstraction
- broad `open` statements changing resolution across a file
- polymorphic compare creeping into domain logic
- backend-specific code leaking into shared libraries
- generated files edited by hand
- tests that assert unstable ordering, paths, or timing

If you see one of these, account for it. Do not amplify it.

## Which Reference To Load Next

Load references by task shape, not curiosity.

### Public API, module boundaries, `.mli`, `include`, `open`, aliases

Read:

- `modules-signatures-and-interfaces.md`
- `functions-labels-and-api-shape.md`

### Data modeling or impossible states

Read:

- `records-variants-and-domain-modeling.md`
- `gadts-type-witnesses-and-existentials.md` when the type index matters

### Collections, comparators, maps, sets, hashtables

Read:

- `collections-comparators-maps-and-hashtables.md`

### Functors, runtime module choice, sharing constraints, object-style dispatch

Read:

- `functors-first-class-modules-and-objects.md`

### Errors, cleanup, and effect boundaries

Read:

- `errors-results-exceptions-and-resource-safety.md`
- `concurrency-io-and-effects.md` for async/effects repos

### Build, packaging, docs, generated code, PPX, parsing

Read:

- `dune-opam-odoc-and-release.md`
- `compiler-ppx-ffi-and-codegen.md`
- `serialization-json-sexps-and-parsing.md` when parser/codegen details matter

### Tests

Read:

- `testing-expect-cram-and-properties.md`

### Performance-sensitive changes

Read:

- `runtime-memory-gc-and-performance.md`

## Editing Rules For Agents

- Prefer adding code in the owning module over creating a fresh helper module.
- Prefer a domain name over `Util`.
- Prefer a private nested module over widening a public surface.
- Prefer explicit qualification or local opens over new file-wide opens.
- Prefer changing the narrowest Dune stanza that owns the code.
- Prefer the repo's existing test style over your favorite one.

## Practical Audit Workflow

When asked to edit an unfamiliar OCaml repo:

1. Identify the owning Dune stanza.
2. Identify whether the target module is public or internal.
3. Read `.mli` before `.ml`.
4. Detect `Stdlib` vs `Base/Core`.
5. Detect synchronous vs `Lwt`/`Async`/`Eio`.
6. Find the nearest sibling module with similar responsibilities.
7. Find the nearest test covering the same kind of behavior.
8. Only then design the patch.

If you cannot answer steps 1 through 6, you do not know the repo well enough to edit it safely.

## Verification Strategy

Verify as narrowly as possible first:

- `dune build <target>` for the touched library or executable
- the smallest relevant `@runtest` alias or test target
- docs only if API/docs changed
- package checks only if packaging changed

Broaden when the change touches public interfaces, shared libraries, generated code, installable artifacts, or CLI behavior.

## What Good OCaml Edits Look Like

A strong change usually has these traits:

- the public interface stayed intentionally stable, or changed clearly
- the code fits the repo's package and module layering
- abstractions match the real variation point
- tests were updated in the repo's own style
- Dune and package metadata still tell the truth
- a future maintainer can understand why the code lives exactly where it does

That is the bar: architectural fit, not just local compilation.

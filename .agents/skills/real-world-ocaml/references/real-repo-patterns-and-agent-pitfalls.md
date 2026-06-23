# Real repo patterns and agent pitfalls

## Core judgment

Mature OCaml repos are opinionated systems, not piles of modules. Their package splits, `.mli` coverage, Dune layout, test strategy, and generated-file rules usually encode hard-won design decisions. If something looks more structured than a small demo would need, assume it protects an API boundary, a portability boundary, a release workflow, or a documentation promise.

The safest default is:

1. find the nearest similar code
2. copy its architectural pattern
3. only generalize when the repo already generalizes the same kind of thing

Agents get into trouble when they optimize for local tidiness while ignoring repo-level structure.

## Read interfaces first

In OCaml, `.mli` files are often the real contract:

- they define the supported API
- they hide invariants behind abstract types
- they drive public docs through `odoc`
- they reveal naming and error-shape conventions

Before editing a public module:

1. read the `.mli`
2. understand which types are abstract and why
3. check nearby modules for the same naming and documentation pattern
4. edit `.mli` and `.ml` together when behavior or surface area changes

Common agent failure:

- patch `foo.ml`
- leave `foo.mli` stale
- accidentally create an implementation/interface mismatch or undocumented behavior change

If a module has no `.mli`, do not assume it should gain a large public surface. In some repos that absence means "private implementation detail."

## Keep portable core code free of backend baggage

A very common mature-repo pattern is:

- pure core library
- platform or backend adapters
- CLI or service entrypoints on top

This shows up across the ecosystem because it works:

- easier testing
- fewer transitive dependencies
- better portability
- cleaner docs

Examples of the shape:

- `opam-core`, `opam-format`, `opam-client`, `opam-solver`
- portable libraries plus Unix layers
- parser/core libraries plus command drivers

Bad agent move:

- one helper needs filesystem or process access
- agent adds `base-unix`, `lwt_unix`, or `cmdliner` directly to the core library

That can be a real architectural regression.

Prefer:

- extract the IO-facing behavior upward
- or create a backend-specific library above the pure core

## Internal libraries are often the right abstraction

Do not treat internal libraries as unnecessary fragmentation.

They help with:

- breaking cycles
- keeping public APIs small
- isolating unstable support code
- separating codegen or parser support from user-facing packages
- controlling heavy dependencies

Real signal from `ocaml/dune`: multiple public and private packages, including libraries explicitly marked unstable or private. That is not clutter. It is dependency hygiene.

If the repo already has internal libs, use them. Do not collapse them into one big public library because a small task looked easier that way.

## Respect style and dialect boundaries

OCaml repos often have strong local style choices:

- `Stdlib` vs `Base` vs `Core`
- labeled-argument conventions
- error representation (`result`, `Or_error`, custom error types)
- deriving strategy
- module naming
- test style

Bad pattern:

- file uses `Stdlib`
- agent imports `Core` for one convenience function

Bad pattern:

- repo uses narrow PPX dependencies
- agent adds `ppx_jane` repo-wide because it is convenient

Bad pattern:

- repo uses explicit serializers
- agent switches one module to generated serializers with a different surface

Follow the dialect the file and its neighbors already speak.

## Do not import `Core` everywhere

This deserves special emphasis.

`Core` is not "better Base." It is a larger ecosystem choice with implications:

- heavier dependency surface
- different APIs and conventions
- different portability expectations

Many repos intentionally use:

- `Stdlib` only
- `Base` plus selected companion libraries
- minimal dependencies in lower layers

If a file already uses `Core`, fine. If a repo uses `Base` or `Stdlib`, do not casually escalate to `Core` for convenience. Reach for the local equivalent or write the small helper explicitly.

## Generated files need provenance

Real repos often contain generated artifacts:

- parser outputs
- generated opam files
- build-info modules
- codegen output
- docs snapshots
- promoted expect/cram outputs

Never assume a generated file should be hand-edited.

Check first:

- is there a Dune rule?
- is there a generator executable?
- is the file checked in or generated in CI only?
- does the repo require promoting generated output?

Real signals:

- comments in `dune-project` about regenerating `*.opam`
- `(rule ...)`, `ocamllex`, `menhir`, or codegen executables
- CI steps that fail if generated files are stale

Bad agent move:

- patch generated output directly
- leave the generator or source untouched
- repo immediately re-breaks on next regen

## Test where the repo tests

Mature repos tend to have a dominant testing style per behavior layer:

- inline/expect for library behavior
- cram for CLI workflows
- unit test executables for conventional API suites
- property tests for laws and generators

Real signal from `ocaml/dune`: a lot of black-box CLI testing. If you change user-facing command behavior in a repo like that, black-box tests usually matter more than adding one tiny unit test deep in a helper.

Bad agent move:

- change CLI output
- update no cram/expect coverage
- claim confidence because one internal function test still passes

Mirror the repo's testing strategy for the surface you changed.

## Module layout is design, not just file organization

RWO's files/modules/programs and functors chapters matter in real repos because files are modules and module boundaries are architectural.

Watch for these patterns:

- `foo.ml` and `foo.mli` define one deliberate abstraction
- `foo_intf.ml` or `Intf` modules centralize reusable signatures
- `Import` modules provide local prelude behavior
- thin `bin/main.ml` wrappers launch code from libraries
- functors are used for dependency injection, not generic cleverness contests

Agent pitfalls:

- create `util.ml`, `helpers.ml`, or `common.ml` without a domain boundary
- introduce a functor where the repo uses plain functions and records
- inline a module's abstraction into callers because it seems shorter

Prefer names and structures that encode purpose:

- `path_resolver`
- `rpc_client`
- `interval_intf`
- `test_support`

Not:

- `misc`
- `shared`
- `stuff`

## Abstraction leaks through public modules are sticky

In Dune, adding a module file to a public library can make it part of the installed surface unless the repo hides it intentionally.

That means a "small helper module" can become:

- documented
- imported by downstream users
- effectively supported forever

Before adding a module:

1. should this be public?
2. should it be private via `private_modules`?
3. should it live in an internal library instead?
4. should it be nested under an existing namespace module?

This matters more in OCaml than in languages where file-local helpers disappear automatically.

## Functors, first-class modules, and abstraction tools

RWO teaches these tools for a reason, but real repos use them selectively.

Use functors when they buy something real:

- dependency injection
- repeated structure over module inputs
- stateful module instantiation
- enforcing a signature-driven abstraction

Do not use functors to show that you know functors.

Bad:

- a one-off helper gets wrapped in a functor stack because it feels generic

Good:

- a reusable interval implementation parameterized by endpoint comparison
- pluggable storage backends through a narrow module signature

If the repo prefers records-of-functions or first-class modules for extensibility, follow that local pattern.

## Serialization and parsing belong at boundaries

From RWO's serialization chapter: parsing and serialization code tends to define trust boundaries.

Repo habits to respect:

- parse external input at the edge
- keep core domain types strong once data is validated
- use explicit error messages and failure tests
- expose serializers intentionally in interfaces

Agent pitfalls:

- sprinkle parsing logic through business code
- expose derived sexp/json functions from a public interface accidentally
- change serialization shape without updating docs/tests

If a type's representation should stay abstract, do not casually add `[@@deriving sexp]` to the public interface just because it is convenient for debugging.

## Command-line code should stay thin

RWO's command-line parsing chapter reinforces a real repo pattern:

- libraries hold logic
- command modules define flags and dispatch
- `main` only launches

Good:

```ocaml
let command = ...
let () = Command_unix.run command
```

with real work delegated into library modules.

Bad:

- parsing, file IO, business logic, formatting, and exit handling all jammed into `main.ml`

This is not just style. Thin command layers are easier to test and easier to port.

## CI commands are part of the contract

Read CI before deciding what "done" means.

Useful signals:

- `dune build @all`
- `dune runtest`
- `dune build @doc`
- `dune build @opam`
- `opam lint`
- formatting aliases
- multiple compiler versions or switches

If a repo checks docs, packaging, or generated files in CI, your task may require more than "the local module compiles."

Bad agent move:

- run only one narrow target
- miss that package generation or docs now fail

Good agent move:

- start narrow
- broaden verification when public APIs, metadata, generated files, or CLI behavior changed

## Good and bad examples

Good: extract logic from executable into library

```ocaml
; bin/main.ml
let () = Command_unix.run Mytool_command.command
```

```ocaml
; lib/mytool_command.ml
let command = ...
```

```ocaml
; lib/core_logic.ml
let run config = ...
```

Bad: everything in one entrypoint file with top-level side effects and no testable seam.

Good: private helper module in a public library

```scheme
(library
 (name mypkg)
 (public_name mypkg)
 (private_modules parser_state))
```

Bad: add `parser_state.ml` to the public library and accidentally export it.

Good: package split preserving portability

```scheme
(library
 (name mypkg_core)
 (public_name mypkg.core)
 (libraries base))

(library
 (name mypkg_unix)
 (public_name mypkg.unix)
 (libraries base-unix mypkg.core))
```

Bad: put `base-unix` in the core library because one call site needed the filesystem.

## High-signal repo clues

When orienting in a real OCaml repo, look for:

- `dune-project` package stanzas
- `generate_opam_files true`
- `.mli` density and doc-comment style
- internal libraries and `private_modules`
- `Import` or `*_intf` conventions
- test directories and `.t` files
- parser/codegen rules
- release or changelog tooling
- whether the repo stays in `Stdlib`, `Base`, or `Core`

Those clues usually tell you more than a fast skim of one implementation file.

## Editing checklist for agents

- Read the `.mli` before changing the `.ml`.
- Find the nearest similar library/module/test pattern and reuse it.
- Preserve package and backend boundaries.
- Keep executables thin and logic in libraries.
- Avoid exporting helper modules accidentally.
- Respect local style on `Stdlib`/`Base`/`Core`, PPX, errors, and tests.
- Edit generators or source metadata, not generated artifacts, unless the repo explicitly wants checked-in generated updates.
- Expand verification when public API, package metadata, docs, or CLI behavior changed.

## Verification

Start with the nearest target, then broaden:

```sh
dune build <target>
dune runtest
dune build @doc
dune build @opam
opam lint
```

If the repo is multi-package or release-sensitive, assume "compiles locally" is not the whole story.

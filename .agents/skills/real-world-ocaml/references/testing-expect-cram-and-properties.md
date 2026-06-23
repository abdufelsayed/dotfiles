# Testing: inline, expect, cram, and properties

## Core judgment

In OCaml, types remove a lot of trivial testing work, but they do not replace behavioral tests. The right move is not "test everything with one framework." The right move is to pick the cheapest test form that proves the behavior you care about.

Rough rule:

- `let%test` or `let%test_unit` for tiny local invariants
- `let%expect_test` for reviewable textual behavior
- test executables with Alcotest or similar for conventional library tests
- cram tests for CLI, shell, file layout, and workflow behavior
- property tests for laws, normalizers, serializers, parsers, and data structure invariants

The best OCaml repos usually mix these.

## What good tests should feel like

The RWO testing chapter points at the right qualities:

- easy to write
- easy to run
- easy to update
- fast
- deterministic
- understandable when they fail

If a test is flaky, huge, host-dependent, or impossible to read in review, fix that before adding more of the same style.

## Start by matching the tool to the behavior surface

Ask one question first:

"Where is the behavior observed?"

If the answer is:

- inside a pure function: use inline or ordinary unit tests
- in formatted structured output: use expect tests
- at the command line or shell boundary: use cram
- across many generated inputs and invariants: use property tests
- in a library API with fixtures and multiple assertions: use Alcotest-style test executables

Bad agent move: default to expect tests for everything because the diff is convenient.

## Inline tests

Inline tests are great for tiny, local truths.

Example:

```ocaml
open Base

let dedup_sorted xs =
  List.remove_consecutive_duplicates xs ~equal:Int.equal

let%test_unit "dedup_sorted removes adjacent duplicates" =
  [%test_eq: int list] (dedup_sorted [ 1; 1; 2; 2; 3 ]) [ 1; 2; 3 ]
```

Dune wiring:

```scheme
(library
 (name dedup)
 (libraries base)
 (inline_tests)
 (preprocess (pps ppx_inline_test ppx_assert)))
```

When inline tests are good:

- the invariant is tiny
- the test reads naturally beside the implementation
- you need direct access to internals that would be awkward to expose

When inline tests are not enough:

- behavior matters at the public API boundary
- setup is nontrivial
- the module becomes harder to read because the code is drowning in tests
- the test depends on executables, environment, or file system layout

RWO's advice is worth internalizing: keep the bulk of tests outside the production library unless there is a good reason not to. Inline tests are useful, not a license to stuff all testing into source modules.

## Expect tests

Expect tests shine when the output itself is the contract.

Use them for:

- pretty printers
- parse errors
- formatted diagnostics
- AST renderings
- command output after sanitization
- examples where reviewing the exact textual result is valuable

Example:

```ocaml
open Base
open Stdio

let render_user ~name ~id =
  printf "%s:%d\n" name id

let%expect_test "render_user" =
  render_user ~name:"alice" ~id:42;
  [%expect {| alice:42 |}]
```

Good expect tests:

- have small output
- make the assertion obvious from the snapshot
- sanitize nondeterministic details first
- use one test per behavioral idea

Bad expect tests:

- assert giant blobs no reviewer will read
- include timestamps, temp dirs, memory addresses, or host-specific paths
- use snapshots instead of reasoning about what matters
- get auto-promoted without diff inspection

### Stabilize before you snapshot

If output contains unstable data, normalize it.

Examples of instability to remove:

- absolute paths
- randomized ordering
- UUIDs
- timestamps
- platform-specific wording
- ANSI color escapes

Good:

```ocaml
let normalize_path s =
  String.substr_replace_all s ~pattern:(Sys.getcwd ()) ~with_:"$PWD"
```

Bad:

```ocaml
let%expect_test "error" =
  print_endline (run_tool ());
  [%expect {| Fatal error at /tmp/tmpA81b9/file.txt line 7 |}]
```

That test will age like milk.

## Cram tests

Cram tests are for black-box command behavior and workflows. If the user experience is "run this binary in a shell and inspect files/stdout/stderr," cram is often the right tool.

Use cram for:

- CLI argument parsing
- help text
- subcommands
- file generation
- end-to-end workflows
- regressions involving shell composition

Typical repo signals:

- `.t` files
- `(cram ...)` or cram-enabled test directories
- `dune runtest` invoking shell transcripts

What cram is good at:

- catching broken flags
- asserting install/runtime wiring
- testing realistic usage patterns
- proving that docs or examples actually execute

What cram is bad at:

- deep library logic
- large algebraic invariant spaces
- complicated fixture setup that would be clearer in OCaml

### Make cram tests deterministic

This matters a lot.

Stabilize:

- current working directory
- locale
- environment variables
- path separators if cross-platform behavior matters
- temp file names
- ordering of directory listings
- coloring and terminal width

Useful habits:

- invoke executables through `%{bin:tool}` when the repo does that
- redirect or sanitize stderr deliberately
- create only the files you need inside the test sandbox

Good cram fragment:

```text
  $ mytool --input sample.txt
  parsed 3 records
```

Bad cram fragment:

```text
  $ mytool --input /var/folders/83/xyz/T/sample.txt --debug
  parsed 3 records in 0.004381s on host macbook-pro-19
```

## Unit-test executables and test-only libraries

Not every repo uses only inline/expect/cram. Many mature repos keep most tests in dedicated test libraries or test executables.

Good pattern:

```scheme
; test/dune
(library
 (name parser_test_support)
 (libraries base mypkg.parser alcotest))

(test
 (name parser_tests)
 (libraries base parser_test_support))
```

Why this is often better than stuffing everything into the production library:

- no production dependency on test frameworks
- public API testing is encouraged
- helpers can be shared across multiple test files
- executable code can stay thin and side-effectful while core logic lives in testable libraries

If a repo already uses Alcotest, OUnit, or a custom runner, follow that style rather than forcing everything into expect tests.

## Property testing

Property tests are for statements like:

- parse then print then parse is stable
- serialization round-trips
- set union is commutative
- normalization is idempotent
- a comparator is consistent with equality
- a map built from an alist has the same lookup behavior as the source model

Common tools in the ecosystem:

- `Base_quickcheck`
- `QCheck`
- sometimes fuzz-style tooling such as `Crowbar`

Choose what the repo already uses.

### What makes a good property

A good property:

- states a semantic law
- has meaningful generators
- shrinks to useful counterexamples
- fails with localizable information

Weak property:

```ocaml
"sort returns a list"
```

The type system already told you that.

Better property:

```ocaml
"sort output is ordered and is a permutation of the input"
```

### Example property ideas

For comparators and collections:

- `compare x y = 0` agrees with intended equality
- inserting the same key twice has documented duplicate behavior
- `Set.of_list` membership matches list membership modulo duplicates

For serialization:

- `t |> sexp_of_t |> t_of_sexp` round-trips
- malformed input fails with a stable error shape

For normalization:

- `normalize (normalize x) = normalize x`

For parsers:

- pretty-print then parse preserves AST modulo normalization

## Turn property failures into regressions

When a property test finds a bug:

1. inspect the shrunk counterexample
2. fix the underlying code
3. add a small deterministic regression test for that exact case

Do not rely only on the property test to remember the bug.

This is one of the highest-signal testing habits in mature codebases.

## Determinism checklist

Before weakening assertions, remove sources of nondeterminism:

- time: inject or freeze clocks
- randomness: seed it or pass a deterministic PRNG
- file system paths: normalize temp dirs
- maps/hashtables: sort output before printing if order is not part of the contract
- environment: set needed variables explicitly
- external commands: pin exact invocation and sanitize host-dependent output
- colors and terminal effects: disable unless they are what you are testing

If a test still flakes, the answer is not "retry in CI until green." Fix the behavior or the test harness.

## Error-path tests matter more than agents think

OCaml agents often over-test success paths and under-test:

- parse failures
- duplicate keys
- malformed config
- missing files
- invalid command-line usage
- exception-to-error conversions
- resource cleanup after failure

These are exactly the places where real code breaks.

If you touch parsers, CLI handling, IO, or serialization, add at least one failure-path test unless the repo already covers it nearby.

## Good and bad examples

Good: expect test for a parser error

```ocaml
let%expect_test "reports missing colon" =
  show_parse_result "name alice";
  [%expect {| Error: expected ':' after field name |}]
```

Bad: expect test for a huge AST dump with unstable locations

```ocaml
let%expect_test "parse file" =
  print_s (parse_file "fixture.txt");
  [%expect {| ... 400 lines including absolute paths and offsets ... |}]
```

Good: cram for CLI help

```text
  $ mytool -help
  Usage: mytool [OPTION]... FILE
  ...
```

Bad: inline test inside executable-only code with top-level side effects

```ocaml
let () = connect_to_prod ()
let%test _ = important_check ()
```

That is a design smell. Extract a library.

## Repository signals to copy

What to look for before adding tests:

- `ppx_inline_test`, `ppx_expect`, `ppx_assert`
- `alcotest`, `ounit2`, `qcheck`, `base_quickcheck`, `crowbar`
- `.t` cram files
- helper modules that sanitize output
- issue-number regression tests
- Dune aliases and test-specific stanzas

Mirror the local style unless the existing choice is clearly inadequate for the behavior you are adding.

## Editing checklist for agents

- Pick the test style that matches where behavior is observed.
- Prefer API-level tests over implementation-detail tests unless internals are the point.
- Keep snapshots small and reviewable.
- Sanitize nondeterminism before asserting output.
- Add failure-path coverage for parser/IO/CLI changes.
- Keep heavy test dependencies in test-only libraries when feasible.
- Inspect promoted expect/cram diffs manually.
- Convert shrunk property failures into permanent regression tests.

## Verification

Useful commands, depending on the repo:

```sh
dune runtest
dune runtest path/to/testdir
dune build @runtest
dune promote
```

If output is promoted, inspect the diff. Promotion is not proof of correctness; it is only a mechanism for updating checked expectations.

---
summary: Serialization, sexps, JSON, deriving converters, schema evolution, defaults, opaque fields, parsers, lexers, AST boundaries, Menhir, ocamllex, config, and command-line parsing.
load_when:
  - Task touches sexps, JSON, deriving converters, schema evolution, defaults, opaque fields, parsers, lexers, AST boundaries, Menhir/ocamllex grammar usage, config formats, or command-line parsing.
skip_when:
  - Task is compiler PPX implementation details; use compiler-ppx-ffi-and-codegen.md instead.
search_terms:
  - '[@@deriving sexp]'
  - Yojson
  - ATD
  - defaults
  - opaque
  - Menhir
  - ocamllex
  - AST
---
# Serialization, JSON, S-Expressions, And Parsing

## Core Judgment
Serialization is boundary code. Its job is to turn bytes into trusted values and trusted values back into bytes without letting wire-format accidents infect the rest of the program.
Default pattern:
1. parse bytes into a syntactic representation
2. validate and convert into a domain type
3. keep the rest of the code on the domain type
Do not let business logic operate directly on raw JSON trees, sexps, or token streams unless those structures are themselves the domain.

## Choose The Format By Audience
Use:
- sexps for OCaml-facing config, tests, internal tooling, and rich debug data
- JSON for external APIs and cross-language interchange
- a real lexer/parser when the input is a language or nontrivial grammar
Do not choose JSON by reflex if the repo already uses sexps heavily. Do not export sexps to outside systems unless that ecosystem already expects them.

## S-Expressions: OCaml-Native And Ergonomic
RWO's practical lesson is that sexps are effective because the ecosystem gives you:
- a simple tree format
- `[@@deriving sexp]`
- good error locations when you load them correctly
- natural integration with `Error.t`
Typical shape:
```ocaml
type t =
  { host : string
  ; port : int
  }
[@@deriving sexp]
```
Load with the location-aware helper:
```ocaml
let load path =
  Sexp.load_sexp_conv_exn path t_of_sexp
```
Prefer that over:
```ocaml
let load path =
  Sexp.load_sexp path |> t_of_sexp
```
The helper preserves file, line, and column context in failures.

## Derived Converters Are The Default, Not The Whole Design
`[@@deriving sexp]` is the right default when the type structure already matches the serialized shape. But generated converters do not know your invariants.
RWO's interval example is the pattern to remember:
```ocaml
type t =
  | Range of int * int
  | Empty
[@@deriving sexp]

let create x y = if x > y then Empty else Range (x, y)

let t_of_sexp sexp =
  match t_of_sexp sexp with
  | Empty -> Empty
  | Range (x, y) -> create x y
```
This shadows the generated `t_of_sexp` and post-validates through a smart constructor.
Agent rule:
- derive when shape matches
- override deserialization when invariants matter
- keep the public type abstract if invalid states must stay unrepresentable

## Sexp Directives Worth Remembering
High-signal directives from RWO:
- `[@sexp.opaque]` for fields that should not serialize meaningfully
- `[@sexp.option]` for optional fields that may be absent in config syntax
- `[@default ...]` for omitted fields with schema defaults
- `[@sexp_drop_default.equal]` to avoid re-emitting default-valued fields
- `[@@deriving sexp_of]` or `[@@deriving of_sexp]` when only one direction is sensible
Example:
```ocaml
type t =
  { host : string [@default "localhost"] [@sexp_drop_default.equal]
  ; port : int [@default 8080] [@sexp_drop_default.equal]
  ; token : string option [@sexp.option]
  }
[@@deriving sexp]
```
This gives a cleaner config UX and a basic schema-evolution path.

## Opaque And Sensitive Fields
`[@sexp.opaque]` is useful for function values, caches, handles, and runtime-only state. It also signals that the serialized shape is not the entire truth of the type.
For secrets, do not assume deriving is safe by default. If a field should not be logged or written out, consider:
- a custom `sexp_of_t`
- a redacted pretty-printer
- splitting runtime-only values from persisted config
Do not let convenient deriving leak credentials into logs.

## JSON: Interop First, Domain Type Second
JSON trees are weakly typed. Your OCaml code should not stay that way longer than necessary.
Bad:
```ocaml
let is_admin json =
  json |> member "role" |> to_string = "admin"
```
deep inside domain logic.
Better:
```ocaml
type role = Admin | User
type account = { id : int; role : role }

val account_of_yojson : Yojson.Safe.t -> (account, string) result
```
Then the rest of the program operates on `account`, not raw JSON.
RWO shows `Yojson.Basic.Util.member`, `to_string`, `to_int`, and related helpers. Those are fine at the parsing edge, but they raise or shape control flow loosely if spread throughout the app. Keep them inside codec modules.

## Choosing A JSON Strategy
Choose based on schema size and stability:
- small internal JSON: hand-written codec or repo-local deriving style
- medium stable API: `ppx_deriving_yojson` or equivalent repo convention
- larger stable external schema: ATD or atdgen is often worth it
RWO's ATD lesson is practical: a schema language plus generated types and codecs reduces boilerplate and drift when the format is large enough.
Do not introduce ATD for one tiny payload in a repo that otherwise hand-writes codecs.

## Compatibility Decisions Must Be Explicit
For every persistent or public format, decide:
- are unknown fields ignored or rejected?
- are missing fields allowed?
- which fields have defaults?
- how are enums versioned?
- what happens when producers send the wrong scalar shape?
- is field order irrelevant? for JSON it usually must be
Generated codecs do not make these decisions for you. Document them in code if the format persists across releases or crosses process or language boundaries.

## Parse, Validate, Convert
Keep these phases separate even if they live in one module.
Example:
```ocaml
module Raw = struct
  type t =
    { port : int
    ; mode : string
    }
  [@@deriving yojson]
end

type mode = Read_only | Read_write
type t = { port : int; mode : mode }

let of_raw (raw : Raw.t) =
  match raw.mode with
  | "ro" -> Ok { port = raw.port; mode = Read_only }
  | "rw" -> Ok { port = raw.port; mode = Read_write }
  | s -> Error ("unknown mode: " ^ s)
```
This is often better than forcing the domain type itself to mirror the wire format's weak choices.

## Keep Parsing Out Of Business Logic
Bad:
```ocaml
let eval_json file =
  let json = Yojson.Basic.from_file file in
  ...
```
inside an evaluator, service core, or domain module.
Preferred split:
- `Config_loader` or `Api_codec` parses bytes
- `Config` or `Domain` validates and owns the trusted type
- the rest of the program consumes trusted values only
The same rule applies to Menhir: parsing should build syntax, not perform IO, mutation, environment lookup, or business execution.

## Menhir And OCamllex: Use For Real Grammars
If the input has nesting, precedence, ambiguity, or nontrivial error messages, stop splitting strings and write a real parser.
Use Menhir over `ocamlyacc` for new code unless the repo is pinned to older tooling. Minimal architecture:
- `ast.ml` defines syntax trees
- `lexer.mll` turns characters into tokens
- `parser.mly` turns tokens into AST
- `parse.ml` wires lexbuf, filename, and error reporting
Do not bury business semantics in `.mly` semantic actions. Build AST values there; elaborate or evaluate later.

## AST Shape Matters
Your AST should represent syntax, not already-evaluated semantics.
Good:
```ocaml
type expr =
  | Int of int
  | Add of expr * expr
  | Let of string * expr * expr
```
Bad:
```ocaml
type expr =
  | Evaluated_int of int
  | Bound_let of env * string * expr * expr
```
If later phases need stronger invariants, add a second validated representation after parsing.

## Error Messages: Location Beats Genericity
RWO's parser example highlights the key rule: report filename, line, and column whenever possible.
Typical pattern:
```ocaml
let print_position outx lexbuf =
  let pos = lexbuf.lex_curr_p in
  fprintf outx "%s:%d:%d" pos.pos_fname pos.pos_lnum
    (pos.pos_cnum - pos.pos_bol + 1)
```
Then catch lexer and parser failures at the boundary and turn them into useful diagnostics.
Prefer:
- field names for JSON or sexp conversion failures
- filename, line, and column for text parsers
- expected token or category where practical
Do not waste specific information by returning `"parse error"` after you already computed location data.

## Command-Line Parsing And Config
This belongs naturally here because CLI flags often feed config decoding.
Good executable flow:
1. parse flags with `Command`
2. load file config
3. apply CLI overrides in one explicit place
4. validate final config
Do not scatter env lookup, flag parsing, JSON or sexp loading, and defaults across `main`.

## Review Heuristics
Ask:
- Is the format internal, public, persistent, or user-edited?
- Is the domain type too contaminated by wire-format choices?
- Do generated converters preserve invariants, or is a custom loader needed?
- Are defaults and unknown-field behavior explicit?
- Are parser actions building syntax only?
- Do errors carry field names or positions?
Red flags:
- ad hoc string splitting for recursive syntax
- regexes pretending to parse nested grammars
- raw `Yojson.Basic.Util` calls throughout business logic
- `Sexp.load_sexp |> t_of_sexp` when location-aware helpers exist
- dependence on JSON object field order

## Editing Checklist
- choose the format based on audience and compatibility needs
- keep parsing separate from validation
- define a trusted domain type
- make defaults and schema evolution explicit
- preserve invariants with smart constructors or custom converters
- keep Menhir actions syntax-focused
- attach field and location context to errors

## Verification
- test valid, malformed, missing-field, and unknown-field inputs
- test old-version inputs when formats persist across releases
- add round-trip tests only when round-tripping is an actual contract
- verify line and column reporting on parser failures

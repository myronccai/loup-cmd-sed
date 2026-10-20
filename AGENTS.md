# AGENTS.md

This repository recreates GNU `sed` in the Loup programming language, as part
of the loup-cmd series of example applications. The program is `host.dual`
Loup built as a native executable. It is a small language implementation: a
lexer (`commands/lexer.loup`) and parser (`commands/parser.loup`) turn the
script into the enums and classes of `commands/program.loup`, and an
interpreter (`commands/machine.loup`) runs them. Regular expressions are
translated by `commands/pattern.loup` into the syntax of the standard
library's `system.regex`.

## Skills

| Skill | Location | Use it when |
|-------|----------|-------------|
| `loup-programmer` | [skills/loup-programmer/SKILL.md](skills/loup-programmer/SKILL.md) | Writing, reviewing, debugging or explaining Loup code: `.lpscr`, `.loup`, `.lphc`, `.lpweb` or `.lpfree` source files, `.lppkg` manifests, `@mode(...)` directives, or the `loup` / `loup-bootstrap` commands. |

Read `skills/loup-programmer/SKILL.md` before writing or changing any Loup code
in this repository. It links to detailed references under
`skills/loup-programmer/references/` for syntax, types and ownership, execution
modes and projects, errors and diagnostics, the standard library, and common
mistakes. Load those only as needed.

## Code layout

```text
.
├── package.lppkg                # Loup manifest: name, version, toolchain, [build] entry, [test] pattern
├── Makefile                     # run, check, test, build, e2e, ci, clean
├── source/                      # all Loup code; modules import each other by path from here
│   ├── main.loup                # entry point: func main() calls run(runtime.args())
│   ├── appinfo.loup             # APP_NAME, APP_VERSION, APP_SUMMARY, exit statuses 0/1/2/4
│   ├── cli/
│   │   ├── args.loup            # classes Options, ScriptPiece, ArgError; tokenize(), parse_args()
│   │   ├── usage.loup           # usage(), version_line()
│   │   └── app.loup             # run(): parse, usage errors, --help/--version, run_sed, exit status
│   └── commands/
│       ├── program.loup         # enums Address, Command, ReplPart; classes Instruction, Substitution, Program
│       ├── lexer.loup           # class Cursor: script characters, GNU error locations, delimited()
│       ├── parser.loup          # parse_script(): addresses, commands, blocks, s/y; ScriptError
│       ├── pattern.loup         # translate(): BRE / ERE -> system.regex syntax (from loup-cmd-grep)
│       ├── machine.loup         # classes Input, Machine: cycles, ranges, commands, output
│       └── sed.loup             # run_sed(): script files, inputs, -i, printing, exit status
├── tests/
│   ├── *_test.loup              # unit tests: func test_*(): void
│   ├── e2e.sh                   # end-to-end tests of the native binary
│   └── fixtures/                # input files and a script file
├── specs/sed/                   # requirements.md, design.md, tasks.md
├── skills/loup-programmer/      # the Loup skill and its references
├── .github/workflows/ci.yml     # installs Loup and runs `make ci`
└── build/                       # build output (git-ignored)
```

## Build, run and test

Prerequisites: Loup 1.26.0 (`loup` and `loup-bootstrap` on `PATH`), `make`,
and `clang` 17 or later for native builds.

Loup Lite comes from <https://github.com/code-craft-ai-company/loup-releases>;
[README.md](README.md#installing-loup-lite) has the install commands.

| Task | Command | Notes |
|------|---------|-------|
| Run from source | `make run ARGS="-n 2p README.md"` | `loup run source/main.loup -- ARGS` |
| Type-check | `make check` | checks `source/main.loup` and every module it imports; tests are not checked |
| Run all tests | `make test` | every `tests/*_test.loup` |
| Run matching tests | `make test TEST_ARGS="--filter value"` | tests whose name contains `value` |
| Run one test file | `make test TEST_ARGS="--file tests/args_test.loup"` | |
| Build | `make build` | native binary at `build/sed` |
| Run the binary | `build/sed --help` | |
| End-to-end tests | `make e2e` | runs `tests/e2e.sh build/sed`: stdout (and stderr for error cases) compared byte for byte |
| Everything CI runs | `make ci` | check, test, build, e2e, then `build/sed --version` |
| Clean | `make clean` | removes `build/` and `.temp/` |

Run `make ci` before reporting a change as done. `loup run` and the native
build do not support the same things, so a change can pass `make test` and
still fail `make build`.

Do not call `loup test` or `loup check` directly on Linux x86-64. There `loup`
is the self-hosted driver: it refuses `check`, and its test runner cannot
resolve this project's imports. The Makefile uses `loup-bootstrap` (Stage0) for
both, and sets `LOUPPATH=source` for tests.

## Making a change

1. Update the spec in `specs/sed/` (see [specs/README.md](specs/README.md)).
2. Change the code under `source/`.
3. Add or update unit tests in `tests/` and cases in `tests/e2e.sh`.
4. Run `make ci`.
5. Tick the finished tasks in `specs/sed/tasks.md`.

Keep behaviour in code that returns values (`parse_script` returns the
`Program`, `Machine` collects its output as a string) so unit tests can check
it; only `run_sed` and `app.run` print. A new command needs a `Command`
variant, a branch in `Parser.command`, an arm in the `match` in
`Machine.run`, and tests in `parser_test.loup` and `machine_test.loup`.

## Conventions

- Every source file is `@mode(host.dual)` with the `.loup` extension. Only
  `source/main.loup` has a `main()`.
- Modules import each other by path from `source/`:
  `from cli.args import (Options);`. Tests import them the same way. Do not
  use relative imports (`from .args import ...`): the self-hosted `loup run`
  on Linux x86-64 fails on them.
- Fields read from another module must be `pub`.
- Records that cross a module boundary (`Options`, `Instruction`,
  `Program`, ...) are **classes**, not structs. Native builds
  key struct field slots on the field name across the whole program, and a
  struct value returned or passed between modules is corrupted when another
  type declares the same field names in a different order. Structs are fine
  inside one module (`LongOption`). Assign class fields inside `safe { }` or a
  `safe func`; methods that call another object's `modifier` methods are
  `safe modifier func` (the parser's methods call the cursor's).
- In a `match` expression on an enum, `Option` or `Result`, do not build a new
  string in an arm (`Tok.Lit(x) => "lit " + x`): native builds return freed
  memory. Use the statement form with `return` or an assignment in each arm.
- Native builds cannot catch the `IoError` of a failed read: check `exists`
  and `isDir` before `readText`.
- Do not give a method's local variable the name of a field of its class:
  Stage0 (`make test`) applies `name += x` to the field.
- `global` is a reserved word (the `s///g` flag is `replace_all`).
- The native build supports less than `loup run` does. For example,
  `list.is_empty()` fails native codegen (`E-CODEGEN-UNHANDLED-METHOD`); use
  `len() == 0`, and annotate `let s: string = str(...)` before calling string
  methods on it.
- `system.regex` rejects `\_` (underscore is a word character); the
  translator writes it bare.
- User-thrown exceptions (`ScriptError`) are caught natively; the parser
  throws them and `parse_script` turns them into `Err`.
- Keep `APP_VERSION` in `source/appinfo.loup` equal to `version` in
  `package.lppkg`.
- The skill's examples use the `loup init` layout (`src/`, `tests/`, and
  `from ..src.x import` in tests). This project uses `source/` and
  `tests/` with plain imports; follow this file.
- The skill documents toolchain 1.25.1; this template targets 1.26.0. When
  they disagree, trust the toolchain's behaviour.

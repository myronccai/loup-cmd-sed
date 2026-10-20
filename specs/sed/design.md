# Design: sed

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses the options
into `Options`, handles `--help` and `--version`, and calls
`commands.sed.run_sed`. `run_sed` collects the script pieces (`-e` texts and
`-f` files), parses them into a `Program`, reads the inputs, runs the program
with a `Machine` and prints the output (or writes it back under `-i`).

```text
-e/-f pieces ─▶ Cursor (lexer) ─▶ parse_script (parser) ─▶ Program
                                                            ├ instructions: Address, Address, !, Command
                                                            ├ regexes (system.regex, from translate)
                                                            └ substitutions, transliterations
input lines ─▶ Machine.run (pattern space, cycles, ranges) ─▶ output text, exit status
```

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses 0/1/2/4 |
| `source/cli/args.loup` | class `Options`, `ScriptPiece`, `parse_args` (getopt_long style, `-i[SUFFIX]`) |
| `source/cli/usage.loup` | `usage()`, `version_line()` |
| `source/cli/app.loup` | `run()`: parse, usage errors, help/version, `run_sed` |
| `source/commands/pattern.loup` | `translate()`: POSIX BRE/ERE to `system.regex` syntax with capturing groups (copied from loup-cmd-grep and adapted) |
| `source/commands/program.loup` | the script's data types: enums `Address`, `Command`, `ReplPart`; classes `Instruction`, `Substitution`, `Transliteration`, `Program` |
| `source/commands/lexer.loup` | class `Cursor`: characters of the script pieces, positions for error messages, delimited strings |
| `source/commands/parser.loup` | `parse_script()`: addresses, commands, blocks, `s` and `y` arguments; `ScriptError` |
| `source/commands/machine.loup` | class `Machine`: the interpreter loop (pattern space, address and range matching, every command, output with missing-newline tracking) |
| `source/commands/sed.loup` | `run_sed()`: script files, inputs, `-i`, printing, exit status |

### Data types

```text
enum Address  { Missing, Line(number), Last, Match(regex) }        # regex: index, -1 = last used
enum Command  { Substitute(index), Transliterate(index), Delete, Print, Quit(status),
                LineNumber, Append(text), Insert(text), Change(text),
                BlockStart(end), BlockEnd }
enum ReplPart { Text(value), Group(number) }                        # 0 = the whole match
```

A program is a flat list of `Instruction { addr1, addr2, negate, command }`.
A block is two instructions: `BlockStart(end)` carries the index of its
`BlockEnd`, so the interpreter skips a block by jumping past it, as GNU sed
does. The parser patches `end` when it reaches the `}`.

### Lexer and parser

`Cursor` walks the script pieces as one character stream, inserting a newline
between pieces (so `-e 'a\' -e text` works). It remembers, for the current
position, the piece and how many characters of it were consumed, which gives
GNU's error locations: `-e expression #N, char C` (N counts `-e` pieces; the
script operand is expression #1) or `file F line L`.

The parser reads, per command: optional addresses (`N`, `$`, `/RE/`,
`\cREc`, each regex with an optional `I`), an optional `,` and second
address, `!`, then a command letter, and dispatches on it. Regex and `s`/`y`
arguments are read by `Cursor.delimited`, which ends at the unescaped
delimiter, turns `\DELIM` into DELIM and `\n` into a newline, and (for
regexes) does not stop inside a bracket expression. Errors are thrown as
`ScriptError` and returned by `parse_script` as `Err(message)`.

Regexes are translated by `pattern.translate` (the grep translator with
capturing groups, `\t`, and `.` matching a newline) and compiled once at
parse time; `s` validates `\N` references against the group count.

### Interpreter

`Machine.run(lines, ...)` keeps the line number across calls (one stream) or
is created per file (`-i`). For each line it runs the instructions from
`pc = 0`:

- an instruction applies when its addresses select the line: a single
  address matches; a range is a small state machine per instruction (inactive
  → active when A matches, closed on the line that matches B, or at once when
  B is a line number not after A); `!` inverts the result;
- `match` on the `Command` (statement form) performs it; `d` and `c` end the
  cycle without printing, `q` ends the run;
- at the end of the cycle the pattern space is printed (unless `-n`), then
  the text queued by `a`.

Output goes to a list of pieces. A line read without a trailing newline is
printed without one, and the newline is added back if anything is printed
after it, as GNU sed does.

`s` uses `findAll` on the pattern space, skipping an empty match that
directly follows the previous match (so `s/a*/x/g` on `baaac` gives
`xbxcx`), and replaces the Nth / all matches by expanding the `ReplPart`s.

## Differences from the original

- Not implemented, as the roadmap defers them: the hold space (`h H g G x`)
  and branching (`b t T :label`). Also not implemented: `n N D P l r R w W e F
  z Q v`, the `s` flags `w`, `e`, `m`/`M`, case conversion (`\U \L \u \l \E`)
  in replacements, the escapes `\cX \dNNN \oNNN \xHH`, the addresses
  `0,/RE/`, `FIRST~STEP`, `ADDR,+N`, `ADDR,~N`, and the options `-s`, `-z`,
  `-u`, `-l`, `--posix`, `--debug`, `--sandbox`, `--follow-symlinks`. Using
  one is an error with status 1 and the GNU message that fits the text (for
  example ``unknown command: `h'`` or `invalid option -- 's'`).
- Regular expressions match leftmost-first (`system.regex`) rather than POSIX
  leftmost-longest: `echo abcd | sed -E 's/ab|abcd/X/'` prints `Xcd` (GNU:
  `X`). Back-references inside a regex (`\(a\)\1`) are not supported.
  Bracket classes and `\w` cover ASCII only.
- `-i` overwrites the file in place and writes the backup as a copy, instead
  of renaming a temporary file.
- A file that exists but cannot be read (no permission) stops sed with
  `IoError: ...` and status 1: the native runtime's read error cannot be
  caught.
- All input is read before the script runs, so error messages about later
  files can appear before the output of earlier ones.
- `--help` lists only the implemented options; `--version` prints one line.

## Error handling

| Situation | Message | Status |
|---|---|---|
| bad option, no script | `sed: invalid option -- 'k'` etc., then the usage text (stderr) | 1 |
| invalid script | `sed: -e expression #1, char 3: unknown command: `` `k' `` etc. | 1 |
| missing `-f` file | `sed: couldn't open file F: No such file or directory` | 4 |
| missing input file | `sed: can't read F: No such file or directory` (continues) | 2 |
| directory as input | `sed: read error on D: Is a directory` / with `-i`: `sed: couldn't edit D: not a regular file` | 4 |
| `-i` without files | `sed: no input files` | 4 |
| `q5` | | 5 |

## Testing

- `tests/args_test.loup`: options, `-i` suffixes, script pieces, usage errors.
- `tests/lexer_test.loup`: the cursor across pieces, delimited strings, error
  locations.
- `tests/parser_test.loup`: addresses, every command, blocks, `s`/`y`
  arguments, every error message.
- `tests/pattern_test.loup`: translation with capturing groups and sed escapes.
- `tests/machine_test.loup`: cycles, ranges, `!`, blocks, each command,
  substitution flags and empty matches, missing newline, `q` status.
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/e2e.sh`: the native binary on fixtures, standard input, `-i` on
  copies under `$TMP`, error messages and statuses.

# loup-cmd-sed

GNU `sed` recreated in [Loup](https://code-craft.ai/references/loup): a stream
editor with the core of the sed language (addresses, ranges, `!`, `{ }`
blocks, `s y d p q = a i c`), `-n`, `-e`, `-f`, `-E` and in-place editing with
`-i`.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary. It is a small language
implementation: a lexer and parser turn the script into enums and classes,
and an interpreter loop runs them over the pattern space. Regular expressions
are POSIX BRE/ERE translated into the standard library's `system.regex`.

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. The full release is at
<https://code-craft.ai/loup/download>, and commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                            # native binary: build/sed
make ci                               # check, unit tests, build, end-to-end tests
make run ARGS="-n 2p README.md"       # run from source with loup run
```

```text
$ build/sed -n '2,3p' tests/fixtures/text.txt
foo bar
baz qux
$ build/sed 's/o/0/g' tests/fixtures/lines.txt
0ne
tw0
three
$ build/sed -E 's/([a-z]+) ([a-z]+)/\2 \1/' tests/fixtures/text.txt
world hello
bar foo
qux baz
Hagain ello
line last
$ build/sed -n '/^hello/I{=;p}' tests/fixtures/text.txt
1
hello world
4
Hello again
$ build/sed '2i\
-- inserted --' tests/fixtures/lines.txt
one
-- inserted --
two
three
$ build/sed '1,2c\
(first two lines)' tests/fixtures/lines.txt
(first two lines)
three
$ build/sed '$!d;y/abc/ABC/' tests/fixtures/text.txt
lAst line
$ build/sed -i.bak 's/^y=.*/y=3/' config.txt; cat config.txt config.txt.bak
x=1
y=3
x=1
y=2
$ build/sed 's/a/b' tests/fixtures/lines.txt; echo "exit $?"
sed: -e expression #1, char 5: unterminated `s' command
exit 1
$ build/sed --version
sed (loup-cmd-sed) 0.1.0
```

`sed [OPTION]... {script-only-if-no-other-script} [input-file]...`

| Option | Meaning |
|---|---|
| `-n`, `--quiet`, `--silent` | do not print the pattern space at the end of each cycle |
| `-e SCRIPT`, `--expression` | add SCRIPT (repeatable; pieces are joined with newlines) |
| `-f FILE`, `--file` | add the script in FILE (`-` for standard input) |
| `-E`, `-r`, `--regexp-extended` | extended regular expressions |
| `-i[SUFFIX]`, `--in-place[=SUFFIX]` | edit files in place, keeping FILE+SUFFIX as a backup (`*` in SUFFIX stands for the file name) |
| `--help`, `--version` | help text, version line |

Script language:

| Element | Meaning |
|---|---|
| `N`, `$`, `/RE/`, `\cREc`, `/RE/I` | line number (across all inputs), last line, regex match (`//` reuses the last regex) |
| `A,B`, `ADDR!` | range from A to the next B, negation |
| `{ ... }` | a block of commands for the selected lines (nestable) |
| `s/RE/REPL/FLAGS` | substitute; flags `g`, `N`, `p`, `i`/`I`; `&`, `\1`..`\9`, `\n` in REPL |
| `y/SRC/DST/` | transliterate characters |
| `d`, `p`, `=`, `q [STATUS]` | delete and start the next cycle, print, print the line number, quit |
| `a TEXT`, `i TEXT`, `c TEXT` | append, insert, change (also the `a\` multi-line form) |
| `#`, `;`, newline | comment, command separators; `#n` as the first line means `-n` |

Exit status: `0` on success, `1` for an invalid option, command or regular
expression, `2` if an input file could not be read, `4` for an I/O error
(such as a directory as input), or the status given to `q`.

## Differences from GNU sed

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

## Layout

```text
source/main.loup               # entry point
source/appinfo.loup            # name, version, exit statuses 0/1/2/4
source/cli/args.loup           # option parsing (-n -e -f -E -i)
source/cli/usage.loup          # --help and --version text
source/cli/app.loup            # run(): parse, usage errors, exit status
source/commands/program.loup   # Address, Command, ReplPart enums; Instruction, Program classes
source/commands/lexer.loup     # Cursor: script characters, error locations, delimited strings
source/commands/parser.loup    # parse_script(): the script language
source/commands/pattern.loup   # BRE / ERE -> system.regex syntax
source/commands/machine.loup   # Machine: the interpreter loop
source/commands/sed.loup       # run_sed(): script files, inputs, -i, output
tests/*_test.loup              # unit tests (make test)
tests/e2e.sh                   # end-to-end tests of build/sed (make e2e)
tests/fixtures/                # input files and a script file
specs/sed/                     # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

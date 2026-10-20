# Requirements: sed

## Introduction

`sed` is a stream editor: it reads its input line by line into a *pattern
space*, runs a small script of commands on it, and prints the result. This
repository recreates the core of GNU sed 4.9 in Loup: the script language
(addresses, ranges, negation, blocks and the commands `s y d p q = a i c`),
`-n`, `-e`, `-f`, `-E` and in-place editing with `-i`. The hold space and
branching are deferred.

## Requirements

### Requirement 1: Running a script

**User Story:** As a shell user, I want to edit a stream with a sed script so
that I can transform text in pipelines.

#### Acceptance Criteria

1. WHEN sed is run as `sed [OPTION]... SCRIPT [FILE]...`, THE program SHALL
   run SCRIPT on every line of the FILEs (standard input when there are none,
   or for `-`), treated as one continuous stream.
2. FOR each line, THE program SHALL put it in the pattern space, run the
   commands whose addresses select it, and then print the pattern space
   unless `-n` was given or the cycle was ended by `d` or `c`.
3. WHEN `-e SCRIPT` or `-f FILE` is given (repeatable, in any mix), THE
   program SHALL join the pieces with newlines into one script and treat every
   operand as a FILE.
4. WHEN the script begins with `#n`, THE program SHALL behave as if `-n` were
   given.
5. WHEN the last input line has no newline, THE program SHALL print it
   without one unless more output follows.

### Requirement 2: Addresses

**User Story:** As a script author, I want to choose lines by number, pattern
or range so that commands apply only where I want.

#### Acceptance Criteria

1. THE program SHALL support the addresses `N` (line number, counted across
   all inputs), `$` (last line), `/RE/` and `\cREc` (with an optional `I`
   flag for case-insensitive matching); an empty RE SHALL reuse the last RE
   used.
2. WHEN two addresses `A,B` are given, THE program SHALL select from the line
   matching A through the next line matching B; if B is a line number not
   greater than A's line, only that line SHALL be selected.
3. WHEN an address is followed by `!`, THE program SHALL select the lines the
   address does not select.
4. WHEN `{ ... }` follows an address, THE program SHALL run the enclosed
   commands only on the selected lines; blocks may nest.

### Requirement 3: Commands

**User Story:** As a script author, I want sed's editing commands so that I
can substitute, delete, print and insert text.

#### Acceptance Criteria

1. `s/RE/REPLACEMENT/FLAGS` SHALL replace the first match of RE, with the
   flags `g` (all matches), `N` (the Nth match; with `g`, the Nth and later),
   `p` (print if a replacement was made) and `i`/`I` (ignore case). In
   REPLACEMENT, `&` SHALL stand for the match, `\1` to `\9` for groups, `\n`
   for a newline, and `\&`, `\\` and `\DELIM` for those characters. Any
   character may be the delimiter.
2. `y/SOURCE/DEST/` SHALL replace each character of SOURCE with the
   corresponding character of DEST.
3. `d` SHALL delete the pattern space and start the next cycle; `p` SHALL
   print it; `=` SHALL print the line number.
4. `q [STATUS]` SHALL print the pattern space (unless `-n`) and any appended
   text, then exit with STATUS (default 0).
5. `a TEXT`, `i TEXT` and `c TEXT` (also the POSIX `a\` newline form, with
   `\` continuing lines) SHALL append text after the cycle, print text now,
   and replace the selected lines with text (once at the end of a range).
6. `#` SHALL start a comment; `;` and newlines SHALL separate commands.

### Requirement 4: Regular expressions

**User Story:** As a sed user, I want POSIX basic and extended regular
expressions so that my existing scripts keep working.

#### Acceptance Criteria

1. THE program SHALL use basic regular expressions by default and extended
   ones with `-E` (or `-r`), with grep's syntax rules: bracket expressions and
   classes, `\(\)`/`()` groups, intervals, `\+ \? \|`, `\w \W \s \S \b \B \< \>`.
2. THE program SHALL accept `\n` and `\t` in regular expressions as newline
   and tab.
3. WHEN a regular expression contains a back-reference, THE program SHALL
   report it as unsupported and exit with status 1.

### Requirement 5: In-place editing

**User Story:** As a developer, I want to edit files in place so that I do not
need temporary files.

#### Acceptance Criteria

1. WHEN `-i` is given, THE program SHALL process each FILE separately (line
   numbers and `$` per file) and write the output back to the file.
2. WHEN `-i` has a SUFFIX (`-iSUFFIX`, `--in-place=SUFFIX`), THE program SHALL
   first save the original as FILE plus SUFFIX (a `*` in SUFFIX stands for
   the file name).
3. WHEN `-i` is given without files, THE program SHALL print
   `sed: no input files` and exit with status 4.

### Requirement 6: Errors and exit status

**User Story:** As a script author, I want GNU's messages and statuses so
that failures are easy to locate.

#### Acceptance Criteria

1. WHEN the script is invalid, THE program SHALL print
   `sed: -e expression #N, char C: MESSAGE` (or `sed: file F line L: MESSAGE`
   for `-f`) with GNU's messages and exit with status 1 before reading input.
2. WHEN an option is unknown or no script is given, THE program SHALL print
   the message and the usage text on standard error and exit with status 1.
3. WHEN an input file cannot be read, THE program SHALL print
   `sed: can't read F: No such file or directory`, continue, and exit with
   status 2; a directory SHALL stop sed with status 4.
4. WHEN `--help` or `--version` is given, THE program SHALL print the help
   text or `sed (loup-cmd-sed) 0.1.0` and exit with status 0.

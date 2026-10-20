# Tasks: sed

- [x] 1. Parse sed's command line (`-n`, `-e`, `-f`, `-E`/`-r`, `-i[SUFFIX]`, long options and prefixes, usage errors)
  - _Requirements: 1.3, 5.1, 5.2, 6.2, 6.4_
- [x] 2. Lexer: a cursor over the script pieces with GNU error locations and delimited strings
  - _Requirements: 1.3, 6.1_
- [x] 3. Parser: addresses, `!`, blocks, every command, `s`/`y` arguments and flags, `#n`, GNU error messages
  - _Requirements: 1.4, 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 6.1_
- [x] 4. Regular expressions: the grep translator adapted for sed (capturing groups, `\n`, `\t`), `I` flag, last-regex reuse
  - _Requirements: 2.1, 4.1, 4.2, 4.3_
- [x] 5. Interpreter: cycles, address and range matching, commands, substitution, output and missing newline, `q` status
  - _Requirements: 1.1, 1.2, 1.5, 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.3, 3.4, 3.5_
- [x] 6. Inputs and in-place editing: files, standard input, missing files, directories, `-i` with backups
  - _Requirements: 1.1, 5.1, 5.2, 5.3, 6.3_
- [x] 7. Unit tests and end-to-end tests of the native binary
  - _Requirements: all_

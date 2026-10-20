#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), and for error cases its standard error, and its exit
# status with the expected ones. Run from the repository root.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
FIX=$(pwd)/tests/fixtures
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_err NAME STATUS EXPECTED_STDOUT EXPECTED_STDERR [ARGS...]
# As check, and standard error must equal EXPECTED_STDERR too.
check_err() {
    local name=$1 want_status=$2 want_err=$4
    printf '%s' "$3" > "$TMP/want"
    shift 4
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    printf '%s' "$want_err" > "$TMP/want_err"
    if [ "$status" -eq "$want_status" ] && cmp -s "$TMP/want" "$TMP/out" && cmp -s "$TMP/want_err" "$TMP/err"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff "$TMP/want" "$TMP/out" | sed 's/^/    stdout /' | head -10
        diff "$TMP/want_err" "$TMP/err" | sed 's/^/    stderr /' | head -10
    fi
}

# check_tree NAME EXPECTED_CONTENT FILE: FILE must hold EXPECTED_CONTENT.
check_tree() {
    printf '%s' "$2" > "$TMP/want"
    if cmp -s "$TMP/want" "$3"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $1"
        diff "$TMP/want" "$3" | sed 's/^/    /' | head -10
    fi
}

USAGE=$("$BIN" --help)$'\n'
cd "$FIX" || exit 1
seq 1 12 > "$TMP/n"
N=$TMP/n
LINES=$'one\ntwo\nthree\n'

# Cycles and simple commands
check "empty script"       0 "$LINES"                             '' lines.txt
check "p"                  0 $'one\none\ntwo\ntwo\nthree\nthree\n'   p lines.txt
check "-n p"               0 "$LINES"                             -n p lines.txt
check "d"                  0 $'one\nthree\n'                      2d lines.txt
check "="                  0 $'1\none\n2\ntwo\n3\nthree\n'        = lines.txt
check "q"                  0 $'1\n2\n'                            2q "$N"
check "q status"           5 $'1\n2\n'                            2q5 "$N"
check "\$= over two files" 0 $'8\n'                               -n '$=' text.txt lines.txt
check "\$!d"               0 $'12\n'                              '$!d' "$N"
check "comment and ;"      0 $'two\n'                             -n '# note
2p; # another'                                                                lines.txt
check "#n"                 0 $'two\n'                             $'#n\n2p' lines.txt
IN=lines.txt check "stdin" 0 $'two\n'                             -n 2p
IN=lines.txt check "stdin dash" 0 $'three\nhello world\n'         -n '3p;4p' - text.txt

# Addresses
check "range"              0 $'2\n3\n4\n'                         -n 2,4p "$N"
check "range ends before"  0 $'4\n'                               -n 4,2p "$N"
check "regex range"        0 $'hello world\nfoo bar\nHello again\nlast line\n'   -n /o/,/a/p text.txt
check "range restarts"     0 $'2\n3\n4\n5\n12\n'                      -n '/[24]/,/[0-9]/p' "$N"
check "to \$"              0 $'11\n12\n'                          -n '11,$p' "$N"
check "negation"           0 $'1\n5\n'                            -n '2,4!p;5q' "$N"
check "I flag"             0 $'hello world\nHello again\n'        -n '/^hello/Ip' text.txt
check "custom delimiter"   0 $'foo bar\n'                         -n '\,f/*o,p' text.txt
check "empty regex"        0 $'hell0 w0rld\nf00 bar\nHell0 again\n'                         -n '/o/s//0/gp' text.txt
check "blocks"             0 $'3\n=5\n'                           -n '2,6{/[35]/{/5/s/^/=/;p}}' "$N"

# s and y
check "s first"            0 $'he1lo world\n'                     -n '1s/l/1/p' text.txt
check "s g"                0 $'hell0 w0rld\nf00 bar\nHell0 again\n'            -n 's/o/0/gp' text.txt
check "s N"                0 $'hello w0rld\nfo0 bar\n'            -n 's/o/0/2p' text.txt
check "s Ng"               0 $'hel1o wor1d\n'                     -n '1s/l/1/2gp' text.txt
check "s I"                0 $'X world\nX again\n'                -n 's/hello/X/Ip' text.txt
check "s groups BRE"       0 $'world hello\n'                     -n '1s/\([a-z]*\) \([a-z]*\)/\2 \1/p' text.txt
check "s groups ERE"       0 $'world-hello\n'                     -nE '1s/([a-z]+) ([a-z]+)/\2-\1/p' text.txt
check "s &"                0 $'[h]e[l][l]o\n'                     -n '1s/[hl]/[&]/gp;1q' <(echo hello)
check "s escapes"          0 $'a&b\\c/d\n'                        's/x/\&b\\c\/d/' <(echo ax)
check "s newline and tab"  0 $'a\nb\tc\n'                         's/ /\n/;s/_/\t/' <(echo 'a b_c')
check "s empty matches"    0 $'xbxcx\n'                           's/a*/x/g' <(echo baaac)
check "s other delimiter"  0 $'/usr/local\n'                      's|/opt|/usr|' <(echo /opt/local)
check "s bracket delim"    0 $'axb\n'                             's/[/]/x/' <(echo a/b)
check "y"                  0 $'ONE\ntwO\nthrEE\n'                 'y/one/ONE/' lines.txt
check "y escapes"          0 $'a\nb\n'                            'y/_/\n/' <(echo a_b)

# a, i, c
check "a\\"                0 $'one\ntwo\nX\nY\nthree\n'           '2a\
X\
Y' lines.txt
check "a one line"         0 $'one\nadded text\ntwo\nthree\n'     '1a   added text' lines.txt
check "i"                  0 $'one\nI\ntwo\nthree\n'              '2i\I' lines.txt
check "c"                  0 $'one\nC\nthree\n'                   '2c C' lines.txt
check "c range"            0 $'C\nthree\n'                        '1,2c C' lines.txt
check "c negated"          0 $'one\nC\nC\n'                       '1!c C' lines.txt
check "a after q"          0 $'one\nA\n'                          'a A
q' lines.txt
check "a across -e"        0 $'one\nfoo\ntwo\nthree\n'            -e '1a\' -e 'foo' lines.txt

# Missing final newline
printf 'a\nb' > "$TMP/nonl"
check "no final newline"   0 $'a\na\nb\nb'                        p "$TMP/nonl"
check "newline put back"   0 $'a\nb\nend\n'                       '$a end' "$TMP/nonl"
check "files joined"       0 $'a\nb\none\ntwo\nthree\n'             '' "$TMP/nonl" lines.txt

# Script sources
check "-f"                 0 $'1\nworld hello\n2\nbar foo\n'      -f swap.sed -e 2q text.txt
check "-e and -f order"    0 $'0\n1\nworld hello\n'               -e '1i 0' -f swap.sed -e 1q text.txt

# In place
cp lines.txt "$TMP/a.txt"; printf 'x\ny' > "$TMP/b.txt"
check "-i output"          0 ''                                   -i.bak -e 's/o/0/' -e '$s/$/!/' "$TMP/a.txt" "$TMP/b.txt"
check_tree "-i file a"     $'0ne\ntw0\nthree!\n'                  "$TMP/a.txt"
check_tree "-i file b"     $'x\ny!'                               "$TMP/b.txt"
check_tree "-i backup"     "$LINES"                               "$TMP/a.txt.bak"
cp lines.txt "$TMP/c.txt"
check "-n -i"              0 ''                                   -n -i 2p "$TMP/c.txt"
check_tree "-n -i file"    $'two\n'                               "$TMP/c.txt"
cp lines.txt "$TMP/d.txt"; mkdir "$TMP/old"
cd "$TMP" || exit 1
check "-i * suffix"        0 ''                                   -i'old/*.orig' 1d d.txt
cd "$FIX" || exit 1
check_tree "-i * backup"   "$LINES"                               "$TMP/old/d.txt.orig"
check_tree "-i * file"     $'two\nthree\n'                        "$TMP/d.txt"

# Errors and exit statuses
check_err "unknown command" 1 '' $'sed: -e expression #1, char 3: unknown command: `k\'\n'   'p;k' lines.txt
check_err "unterminated s" 1 '' $'sed: -e expression #1, char 5: unterminated `s\' command\n'   's/a/b' lines.txt
check_err "s option"       1 '' $'sed: -e expression #1, char 7: unknown option to `s\'\n'   's/a/b/q' lines.txt
check_err "unmatched {"    1 '' $'sed: -e expression #2, char 0: unmatched `{\'\n'   -e p -e '{' lines.txt
check_err "unexpected }"   1 '' $'sed: -e expression #1, char 2: unexpected `}\'\n'   'p}' lines.txt
check_err "y lengths"      1 '' $'sed: -e expression #1, char 7: strings for `y\' command are different lengths\n'   'y/ab/x/' lines.txt
check_err "bad reference"  1 '' $'sed: -e expression #1, char 11: invalid reference \\2 on `s\' command\'s RHS\n'   's/\(a\)/\2/' lines.txt
check_err "missing command" 1 '' $'sed: -e expression #1, char 1: missing command\n'   1 lines.txt
check_err "extra characters" 1 '' $'sed: -e expression #1, char 3: extra characters after command\n'   'p p' lines.txt
check_err "one address"    1 '' $'sed: -e expression #1, char 4: command only uses one address\n'   '1,2q' lines.txt
check_err "bad regex"      1 '' $'sed: -e expression #1, char 8: Unmatched ( or \\(\n'   's/a\(/x/' lines.txt
printf 'p\n\nk\n' > "$TMP/bad.sed"
check_err "file line"      1 '' "sed: file $TMP/bad.sed line 3: unknown command: \`k'"$'\n'   -f "$TMP/bad.sed" lines.txt
check_err "no previous RE" 1 '' $'sed: -e expression #1, char 0: no previous regular expression\n'   -n '//p' lines.txt
check_err "hold space"     1 '' $'sed: -e expression #1, char 1: unknown command: `h\'\n'   h lines.txt
check_err "missing file"   2 "$LINES" $'sed: can\'t read nope.txt: No such file or directory\n'   '' nope.txt lines.txt
check_err "directory"      4 '' $'sed: read error on .: Is a directory\n'   p .
check_err "missing -f"     4 '' $'sed: couldn\'t open file nope.sed: No such file or directory\n'   -f nope.sed lines.txt
check_err "-i no files"    4 '' $'sed: no input files\n'          -i p
check_err "-i directory"   4 '' $'sed: couldn\'t edit .: not a regular file\n'   -i p .
check_err "no script"      1 '' "$USAGE"
check_err "bad option"     1 '' "sed: invalid option -- 'k'"$'\n'"$USAGE"   -k p
check_err "bad long"       1 '' "sed: unrecognized option '--posix'"$'\n'"$USAGE"   --posix p
check "version"            0 $'sed (loup-cmd-sed) 0.1.0\n'        --version
check "long options"       0 $'two\n'                             --quiet --expression=2p lines.txt
check "options after files" 0 $'two\n'                            2p lines.txt -n

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

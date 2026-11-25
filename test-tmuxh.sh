#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
tmxh=$source_dir/bin/tmxh
tmux_bin=$(command -v tmux)
test_dir=$(mktemp -d)
export TMUXH_TEST_SOCKET="$test_dir/socket" TMUXH_TEST_TMUX="$tmux_bin"

cleanup() {
    "$tmux_bin" -S "$TMUXH_TEST_SOCKET" kill-server >/dev/null 2>&1 || true
    if [[ ${KEEP:-0} == 1 ]]; then
        printf 'Tesztfájlok: %s\n' "$test_dir"
    else
        rm -rf -- "$test_dir"
    fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

cat > "$test_dir/tmux" <<'WRAPPER'
#!/bin/sh
exec "$TMUXH_TEST_TMUX" -S "$TMUXH_TEST_SOCKET" -f /dev/null "$@"
WRAPPER
chmod +x "$test_dir/tmux"
printf 'state_dir = %s/state\nsession_name = selftest\nstart_cwd = %s\n' "$test_dir" "$test_dir" > "$test_dir/config"
unset TMUX TMUX_PANE TMUXH_WINDOW TMUXH_PANE
export TMUXH_TMUX="$test_dir/tmux" TMUXH_CONFIG="$test_dir/config" SHELL=/bin/bash
cd -- "$test_dir"

json_check() {
    perl -MJSON::PP -e 'local $/; my $data = decode_json(<STDIN>); die "Hibás JSON-eredmény ($ARGV[0]): " . encode_json($data) . "\n" unless eval $ARGV[0];' "$1"
}

[[ $("$tmxh" version) == 'tmxh 1.2.6' ]]
"$tmxh" help | grep -F '~/tmux/config' >/dev/null
"$tmxh" --create >/dev/null
"$tmxh" doctor --no-probe | grep -F 'shell proba    : kihagyva' >/dev/null
"$tmxh" doctor --json | json_check '$data->{probe_ok} == 1'
"$tmxh" wait --all --json | json_check 'ref($data->{jobs}) eq "ARRAY" && !@{$data->{jobs}}'

value="a b='c'; \$(printf EXPANDED)"
"$tmxh" run --timeout 5 --env "TMXH_CHECK=$value" --env TMXH_EMPTY= --json \
    'printf "ENV=<%s> EMPTY=<%s>\n" "$TMXH_CHECK" "${TMXH_EMPTY-unset}"' |
    TMXH_EXPECTED="$value" json_check 'grep { $_ eq "ENV=<$ENV{TMXH_EXPECTED}> EMPTY=<>" } split /\r?\n\r?/, $data->{output}'

rc=0
"$tmxh" run --timeout 5 --env 'BAD-NAME=value' 'touch unexpected' >/dev/null 2>&1 || rc=$?
[[ $rc == 2 && ! -e unexpected ]]

response=$("$tmxh" run --timeout 5 --json "printf '\303\241rv\303\255z\n'")
utf8_check='grep { $_ eq "\x{e1}rv\x{ed}z" } split /\r?\n\r?/, $data->{output}'
json_check "$utf8_check" <<< "$response"
job=$(perl -MJSON::PP -ne 'print decode_json($_)->{job}' <<< "$response")
"$tmxh" read "$job" --all --no-advance --json | json_check "$utf8_check"
"$tmxh" read "$job" --all --raw --json |
    json_check 'index($data->{output}, "\xc3\xa1rv\xc3\xadz") >= 0 && $data->{new_bytes} == length($data->{output})'

rc=0
"$tmxh" run --timeout 5 --json '(exit 7)' > exit.json || rc=$?
[[ $rc == 7 ]]
json_check '$data->{status} eq "done" && $data->{exit} == 7' < exit.json
job=$("$tmxh" bg 'sleep 1; echo BACKGROUND')
"$tmxh" wait "$job" --timeout 5 --json | json_check '$data->{jobs}[0]{status} eq "done"'
"$tmxh" read "$job" --json | json_check 'grep { $_ eq "BACKGROUND" } split /\r?\n\r?/, $data->{output}'

printf '\000\001\377\n' > source
"$tmxh" push source "$test_dir/space dir/destination" --verify md5 --json | json_check '$data->{ok} == 1'
cmp source "$test_dir/space dir/destination"
printf 'A tmxh önteszt sikeres.\n'

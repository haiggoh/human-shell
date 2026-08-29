#!/bin/zsh -f
# Differential safety tests for multiline diagnostics. Each scenario runs in
# clean child shells with diagnostics off and on. Diagnostic memory itself is
# excluded; all user-observable outputs and state must remain identical.

emulate -R zsh
setopt no_aliases

repo="${HUMAN_SHELL_TEST_REPO:-${0:A:h:h}}"

# ---------------------------------------------------------------------------
# Worker mode.
# ---------------------------------------------------------------------------

if [[ "${1-}" == "--worker" ]]; then
  mode="$2"
  scenario="$3"
  result_dir="$4"

  mkdir -p -- "$result_dir" || exit 1

  unset \
    HUMAN_SHELL_STATUS \
    HUMAN_SHELL_READY \
    HUMAN_SHELL_LAUNCHER \
    HUMAN_SHELL_DIAGNOSTICS

  source "$repo/human-shell.zsh" || exit 1

  HUMAN_SHELL_DIAGNOSTICS="$mode"
  _human_shell_diagnostics_reset

  _hs_finish_case() {
    local -a captured=( "$@" )
    local scalar="${captured[1]}"
    local pipeline=''

    if (( ${#captured} > 1 )); then
      pipeline="${(j:,:)captured[2,-1]}"
    fi

    print -r -- "status=$scalar" >"$result_dir/result"
    print -r -- "pipeline=$pipeline" >>"$result_dir/result"

    _human_shell_diagnostics_finish "$scalar"
    return 0
  }

  case "$scenario" in
    output)
      source_text=$'print first\nfalse\nprint last'
      _human_shell_diagnostics_begin "$source_text"

      {
        print -r -- 'first'
        print -u2 -r -- 'warning on stderr'
        false
        print -r -- 'last'
      } >"$result_dir/stdout" 2>"$result_dir/stderr"

      captured=( "$?" "${pipestatus[@]}" )
      _hs_finish_case "${captured[@]}"
      ;;

    redirects)
      source_text=$'print alpha >generated\nfalse\nprint omega >>generated'
      _human_shell_diagnostics_begin "$source_text"

      print -r -- 'alpha' >"$result_dir/generated"
      print -u2 -r -- 'redirected warning' 2>"$result_dir/generated.stderr"
      false
      print -r -- 'omega' >>"$result_dir/generated"
      true

      captured=( "$?" "${pipestatus[@]}" )
      _hs_finish_case "${captured[@]}"
      ;;

    heredocs)
      source_text=$'cat <<EOF\nexpanded\nEOF\ncat <<\'EOF\'\nliteral\nEOF'
      _human_shell_diagnostics_begin "$source_text"

      token='expanded value'

      cat >"$result_dir/unquoted" <<HUMAN_SHELL_UNQUOTED_HEREDOC
$token
$(print -r -- 'command substitution value')
HUMAN_SHELL_UNQUOTED_HEREDOC

      cat >"$result_dir/quoted" <<'HUMAN_SHELL_QUOTED_HEREDOC'
$token
$(print -r -- 'literal command substitution')
HUMAN_SHELL_QUOTED_HEREDOC

      captured=( "$?" "${pipestatus[@]}" )
      _hs_finish_case "${captured[@]}"
      ;;

    substitution)
      source_text=$'value="$(false\nprint value)"\nprint "$value"'
      _human_shell_diagnostics_begin "$source_text"

      value="$(
        false
        print -r -- 'substitution value'
      )"

      assignment_status=$?

      print -r -- "$value" >"$result_dir/value"
      print -r -- "assignment_status=$assignment_status" \
        >"$result_dir/assignment"

      captured=( "$?" "${pipestatus[@]}" )
      _hs_finish_case "${captured[@]}"
      ;;

    pipeline)
      source_text=$'setopt pipe_fail\nprint value | grep missing | cat'
      _human_shell_diagnostics_begin "$source_text"

      setopt pipe_fail

      print -r -- 'pipeline value' |
        grep 'missing' |
        cat >"$result_dir/pipeline.stdout" \
          2>"$result_dir/pipeline.stderr"

      captured=( "$?" "${pipestatus[@]}" )

      unsetopt pipe_fail
      _hs_finish_case "${captured[@]}"
      ;;

    shell-state)
      source_text=$'cd child\nsetopt pipe_fail\nprint descriptor >&9'
      _human_shell_diagnostics_begin "$source_text"

      mkdir -p -- "$result_dir/child" || exit 1
      cd -- "$result_dir/child" || exit 1

      setopt pipe_fail

      exec 9>"$result_dir/fd9"
      print -r -- 'descriptor output' >&9
      exec 9>&-

      relative_pwd="${PWD#$result_dir/}"

      {
        print -r -- "pwd=$relative_pwd"
        print -r -- "pipe_fail=$([[ -o PIPE_FAIL ]] && print on || print off)"
        print -r -- "local_traps=$([[ -o LOCAL_TRAPS ]] && print on || print off)"
        print -r -- "err_exit=$([[ -o ERR_EXIT ]] && print on || print off)"
        print -r -- "err_return=$([[ -o ERR_RETURN ]] && print on || print off)"
      } >"$result_dir/shell-state"

      captured=( "$?" "${pipestatus[@]}" )
      _hs_finish_case "${captured[@]}"
      ;;

    err-exit)
      HS_REPO="$repo" \
      HS_MODE="$mode" \
      HS_SOURCE=$'print before\nfalse\nprint after' \
        /bin/zsh -f -c '
          emulate -R zsh
          setopt no_aliases

          source "$HS_REPO/human-shell.zsh" || exit 90

          HUMAN_SHELL_DIAGNOSTICS="$HS_MODE"
          _human_shell_diagnostics_reset

          setopt err_exit
          _human_shell_diagnostics_begin "$HS_SOURCE"

          print -r -- before
          false
          print -r -- after
        ' >"$result_dir/child.stdout" 2>"$result_dir/child.stderr"

      child_exit=$?
      print -r -- "child_exit=$child_exit" >"$result_dir/child.status"

      captured=( 0 0 )
      _hs_finish_case "${captured[@]}"
      ;;

    err-return)
      HS_REPO="$repo" \
      HS_MODE="$mode" \
      HS_SOURCE=$'f() {\n  print function-before\n  false\n  print function-after\n}\nf\nprint caller-after' \
        /bin/zsh -f -c '
          emulate -R zsh
          setopt no_aliases

          source "$HS_REPO/human-shell.zsh" || exit 90

          HUMAN_SHELL_DIAGNOSTICS="$HS_MODE"
          _human_shell_diagnostics_reset

          setopt err_return
          _human_shell_diagnostics_begin "$HS_SOURCE"

          f() {
            print -r -- function-before
            false
            print -r -- function-after
          }

          f
          function_exit=$?

          print -r -- "function_exit=$function_exit"
          print -r -- caller-after

          _human_shell_diagnostics_finish "$function_exit"
          exit 0
        ' >"$result_dir/child.stdout" 2>"$result_dir/child.stderr"

      child_exit=$?
      print -r -- "child_exit=$child_exit" >"$result_dir/child.status"

      captured=( 0 0 )
      _hs_finish_case "${captured[@]}"
      ;;

    exec-replacement)
      HS_REPO="$repo" \
      HS_MODE="$mode" \
      HS_SOURCE=$'print before\nexec /bin/zsh -f -c replacement' \
        /bin/zsh -f -c '
          emulate -R zsh
          setopt no_aliases

          source "$HS_REPO/human-shell.zsh" || exit 90

          HUMAN_SHELL_DIAGNOSTICS="$HS_MODE"
          _human_shell_diagnostics_reset
          _human_shell_diagnostics_begin "$HS_SOURCE"

          print -r -- before-exec
          exec /bin/zsh -f -c "print -r -- replacement-output; exit 7"
        ' >"$result_dir/child.stdout" 2>"$result_dir/child.stderr"

      child_exit=$?
      print -r -- "child_exit=$child_exit" >"$result_dir/child.status"

      captured=( 0 0 )
      _hs_finish_case "${captured[@]}"
      ;;

    trap-conflict)
      typeset -gi _HS_USER_TRAP_COUNT=0

      TRAPZERR() {
        (( _HS_USER_TRAP_COUNT += 1 ))
        return 0
      }

      source_text=$'false\ntrue'
      trap_before="${functions[TRAPZERR]}"

      _human_shell_diagnostics_begin "$source_text"
      trap_after_begin="${functions[TRAPZERR]}"

      false
      true

      captured=( "$?" "${pipestatus[@]}" )
      _human_shell_diagnostics_finish "${captured[1]}"

      trap_after_finish="${functions[TRAPZERR]}"

      {
        if [[ "$trap_before" == "$trap_after_begin" ]]; then
          print -r -- 'trap_after_begin=same'
        else
          print -r -- 'trap_after_begin=changed'
        fi

        if [[ "$trap_before" == "$trap_after_finish" ]]; then
          print -r -- 'trap_after_finish=same'
        else
          print -r -- 'trap_after_finish=changed'
        fi

        print -r -- "trap_count=$_HS_USER_TRAP_COUNT"
      } >"$result_dir/trap-state"

      _hs_finish_case "${captured[@]}"
      unfunction TRAPZERR
      ;;

    *)
      print -u2 -- "Unknown differential scenario: $scenario"
      exit 2
      ;;
  esac

  exit 0
fi

# ---------------------------------------------------------------------------
# Parent test runner.
# ---------------------------------------------------------------------------

typeset -i passed=0 failed=0

check() {
  local description="$1" expected="$2" actual="$3"

  if [[ "$expected" == "$actual" ]]; then
    (( passed += 1 ))
    print -r -- "PASS: $description"
  else
    (( failed += 1 ))
    print -u2 -r -- "FAIL: $description"
    print -u2 -r -- "  expected: [$expected]"
    print -u2 -r -- "  actual:   [$actual]"
  fi
}

scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT

scenarios=(
  output
  redirects
  heredocs
  substitution
  pipeline
  shell-state
  err-exit
  err-return
  exec-replacement
  trap-conflict
)

for scenario in "${scenarios[@]}"; do
  off_dir="$scratch/$scenario/off"
  details_dir="$scratch/$scenario/details"
  off_stdout="$scratch/$scenario/off.worker.stdout"
  off_stderr="$scratch/$scenario/off.worker.stderr"
  details_stdout="$scratch/$scenario/details.worker.stdout"
  details_stderr="$scratch/$scenario/details.worker.stderr"

  mkdir -p -- "$off_dir" "$details_dir"

  HUMAN_SHELL_TEST_REPO="$repo" \
    /bin/zsh -f "$0" \
      --worker off "$scenario" "$off_dir" \
      >"$off_stdout" 2>"$off_stderr"
  off_exit=$?

  HUMAN_SHELL_TEST_REPO="$repo" \
    /bin/zsh -f "$0" \
      --worker details "$scenario" "$details_dir" \
      >"$details_stdout" 2>"$details_stderr"
  details_exit=$?

  check "$scenario: diagnostics-off worker succeeds" \
    "0" "$off_exit"

  check "$scenario: diagnostics-on worker succeeds" \
    "0" "$details_exit"

  if (( off_exit != 0 || details_exit != 0 )); then
    comparison='worker failure'

    print -u2 -- "WORKER FAILURE: $scenario"
    print -u2 -- "-- off stdout (exit $off_exit) --"
    [[ -s "$off_stdout" ]] && cat "$off_stdout" >&2 || print -u2 -- 'empty'
    print -u2 -- "-- off stderr --"
    [[ -s "$off_stderr" ]] && cat "$off_stderr" >&2 || print -u2 -- 'empty'

    print -u2 -- "-- details stdout (exit $details_exit) --"
    [[ -s "$details_stdout" ]] &&
      cat "$details_stdout" >&2 ||
      print -u2 -- 'empty'
    print -u2 -- "-- details stderr --"
    [[ -s "$details_stderr" ]] &&
      cat "$details_stderr" >&2 ||
      print -u2 -- 'empty'
  elif /usr/bin/cmp -s "$off_stdout" "$details_stdout" &&
       /usr/bin/cmp -s "$off_stderr" "$details_stderr" &&
       /usr/bin/diff -ru "$off_dir" "$details_dir" >/dev/null 2>&1
  then
    comparison='identical'
  else
    comparison='different'

    print -u2 -- "DIFF: $scenario worker stdout"
    /usr/bin/diff -u "$off_stdout" "$details_stdout" >&2 || true

    print -u2 -- "DIFF: $scenario worker stderr"
    /usr/bin/diff -u "$off_stderr" "$details_stderr" >&2 || true

    print -u2 -- "DIFF: $scenario generated state"
    /usr/bin/diff -ru "$off_dir" "$details_dir" >&2 || true
  fi

  check "$scenario: diagnostics on and off are observationally identical" \
    "identical" "$comparison"
done

rm -rf -- "$scratch"
trap - EXIT

print
print -r -- "$passed passed, $failed failed."
(( failed == 0 ))

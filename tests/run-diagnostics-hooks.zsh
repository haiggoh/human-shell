#!/bin/zsh -f
# Contract for connecting the silent multiline collector to Human Shell's
# existing preexec/precmd lifecycle. Hook calls execute in this shell; only
# their output is redirected, so state changes remain observable.

emulate -R zsh
setopt no_aliases

repo="${HUMAN_SHELL_TEST_REPO:-${0:A:h:h}}"

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

typeset capture_dir
capture_dir="$(mktemp -d)"
trap 'rm -rf -- "$capture_dir"' EXIT

capture_preexec() {
  local source="$1"
  local output_file="$capture_dir/preexec"

  _human_shell_preexec "$source" >"$output_file" 2>&1
  typeset -g HOOK_STATUS=$?
  typeset -g HOOK_OUTPUT="$(<"$output_file")"
  return 0
}

capture_precmd() {
  local exit_code="$1"
  local output_file="$capture_dir/precmd"

  (exit "$exit_code")
  _human_shell_precmd >"$output_file" 2>&1
  typeset -g HOOK_STATUS=$?
  typeset -g HOOK_OUTPUT="$(<"$output_file")"
  return 0
}

strip_report() {
  print -r -- "$1" |
    /usr/bin/sed $'s/\e\\[[0-9;]*m//g;s/^ *//'
}

unset \
  HUMAN_SHELL_STATUS \
  HUMAN_SHELL_READY \
  HUMAN_SHELL_LAUNCHER \
  HUMAN_SHELL_DIAGNOSTICS

source "$repo/human-shell.zsh"

HUMAN_SHELL_STATUS=all
HUMAN_SHELL_DIAGNOSTICS=details
HUMAN_SHELL_COMMAND_RAN=0
HUMAN_SHELL_LAST_COMMAND=''
HUMAN_SHELL_SUPPRESS_REPORT=0
COLUMNS=50

# ---------------------------------------------------------------------------
# Multiline preexec automatically arms collection.
# ---------------------------------------------------------------------------

_human_shell_diagnostics_reset

typeset multiline_source=$'print first\nfalse\nprint last'

capture_preexec "$multiline_source"

check "multiline preexec remains silent" \
  "" "$HOOK_OUTPUT"
check "multiline preexec marks that a command ran" \
  "1" "${HUMAN_SHELL_COMMAND_RAN:-0}"
check "multiline preexec preserves the complete submitted source" \
  "$multiline_source" "${HUMAN_SHELL_LAST_COMMAND-}"
check "multiline preexec automatically arms diagnostics" \
  "1" "${_HUMAN_SHELL_DIAG_ACTIVE:-0}"
check "multiline preexec installs the collector trap" \
  "1" "$(( ${+functions[TRAPZERR]} ))"

# Keep the red phase usable before integration exists.
if [[ "${_HUMAN_SHELL_DIAG_ACTIVE:-0}" != "1" ]]; then
  _human_shell_diagnostics_begin "$multiline_source"
fi

false
true

check "an intermediate failure is collected before precmd" \
  "1" "${#_HUMAN_SHELL_DIAG_EVENT_STATUS}"
check "the collected intermediate status is retained" \
  "1" "${_HUMAN_SHELL_DIAG_EVENT_STATUS[1]-}"

# ---------------------------------------------------------------------------
# Precmd freezes before rendering the unchanged aggregate badge.
# ---------------------------------------------------------------------------

typeset original_report="${functions[_human_shell_report]}"
typeset -g _HS_STATE_AT_REPORT=''
typeset -g _HS_OVERALL_AT_REPORT=''

_human_shell_report() {
  typeset -g _HS_STATE_AT_REPORT="${_HUMAN_SHELL_DIAG_STATE:-missing}"
  typeset -g _HS_OVERALL_AT_REPORT="${_HUMAN_SHELL_DIAG_OVERALL_STATUS:-missing}"
  return 0
}

capture_precmd 0
precmd_status="$HOOK_STATUS"

functions[_human_shell_report]="$original_report"

check "precmd itself returns success" \
  "0" "$precmd_status"
check "precmd freezes diagnostics before reporting" \
  "complete" "$_HS_STATE_AT_REPORT"
check "precmd exposes aggregate status before reporting" \
  "0" "$_HS_OVERALL_AT_REPORT"
check "precmd disarms the collector" \
  "0" "${_HUMAN_SHELL_DIAG_ACTIVE:-0}"
check "precmd removes Human Shell's collector trap" \
  "0" "$(( ${+functions[TRAPZERR]} ))"
check "precmd freezes a complete snapshot" \
  "complete" "${_HUMAN_SHELL_DIAG_STATE:-missing}"
check "precmd stores the aggregate block status" \
  "0" "${_HUMAN_SHELL_DIAG_OVERALL_STATUS:-missing}"
check "precmd preserves the intermediate event" \
  "1" "${#_HUMAN_SHELL_DIAG_EVENT_STATUS}"

if [[ "${_HUMAN_SHELL_DIAG_ACTIVE:-0}" == "1" ]]; then
  _human_shell_diagnostics_finish 0
fi

# Aggregate reporting remains unchanged.
_human_shell_diagnostics_reset
capture_preexec "$multiline_source"

if [[ "${_HUMAN_SHELL_DIAG_ACTIVE:-0}" != "1" ]]; then
  _human_shell_diagnostics_begin "$multiline_source"
fi

false
true
capture_precmd 0

check "successful multiline aggregate keeps the existing success badge" \
  "success [exit 0]" "$(strip_report "$HOOK_OUTPUT")"

if [[ "${_HUMAN_SHELL_DIAG_ACTIVE:-0}" == "1" ]]; then
  _human_shell_diagnostics_finish 0
fi

# ---------------------------------------------------------------------------
# Single-line commands and details preserve a frozen snapshot.
# ---------------------------------------------------------------------------

typeset -g _HUMAN_SHELL_DIAG_STATE=complete
typeset -g _HUMAN_SHELL_DIAG_REASON=''
typeset -g _HUMAN_SHELL_DIAG_SOURCE="$multiline_source"
typeset -g _HUMAN_SHELL_DIAG_OVERALL_STATUS=0
typeset -g _HUMAN_SHELL_DIAG_OVERFLOW=0
typeset -ga _HUMAN_SHELL_DIAG_EVENT_STATUS=(1)
typeset -ga _HUMAN_SHELL_DIAG_EVENT_PIPELINE=(1)
typeset -ga _HUMAN_SHELL_DIAG_EVENT_TRACE=('')

capture_preexec 'print ordinary'
capture_precmd 0

check "a later single-line command preserves snapshot state" \
  "complete" "$_HUMAN_SHELL_DIAG_STATE"
check "a later single-line command preserves snapshot source" \
  "$multiline_source" "$_HUMAN_SHELL_DIAG_SOURCE"
check "a later single-line command preserves snapshot events" \
  "1" "${(j:,:)_HUMAN_SHELL_DIAG_EVENT_STATUS}"

typeset continued_details_source=$'human-shell details \\\n  --plain'

capture_preexec "$continued_details_source"

check "standalone continued details preexec requests report suppression" \
  "1" "${HUMAN_SHELL_SUPPRESS_REPORT:-0}"
check "standalone continued details installs no collector trap" \
  "0" "$(( ${+functions[TRAPZERR]} ))"
check "standalone continued details preserves snapshot state before rendering" \
  "complete" "$_HUMAN_SHELL_DIAG_STATE"
check "standalone continued details preserves snapshot source before rendering" \
  "$multiline_source" "$_HUMAN_SHELL_DIAG_SOURCE"
check "standalone continued details preserves snapshot events before rendering" \
  "1" "${(j:,:)_HUMAN_SHELL_DIAG_EVENT_STATUS}"

human-shell details --plain >"$capture_dir/details-render" 2>&1
capture_precmd 0

check "standalone continued details precmd emits no ordinary badge" \
  "" "$HOOK_OUTPUT"
check "standalone continued details consumes report suppression" \
  "0" "${HUMAN_SHELL_SUPPRESS_REPORT:-0}"
check "standalone continued details preserves snapshot state" \
  "complete" "$_HUMAN_SHELL_DIAG_STATE"
check "standalone continued details preserves snapshot source" \
  "$multiline_source" "$_HUMAN_SHELL_DIAG_SOURCE"
check "standalone continued details preserves snapshot events" \
  "1" "${(j:,:)_HUMAN_SHELL_DIAG_EVENT_STATUS}"

typeset nested_details_source=$'print before\nhuman-shell details --plain\nfalse'

capture_preexec "$nested_details_source"

check "nested details preexec does not request report suppression" \
  "0" "${HUMAN_SHELL_SUPPRESS_REPORT:-0}"

human-shell details --plain >"$capture_dir/nested-details-render" 2>&1
false
capture_precmd 1

check "nested details keeps the enclosing multiline failure badge" \
  "failed [exit 1]" "$(strip_report "$HOOK_OUTPUT")"
check "nested details leaves its multiline snapshot complete" \
  "complete" "${_HUMAN_SHELL_DIAG_STATE:-missing}"

capture_preexec 'human-shell details; false'

check "compound details preexec does not request report suppression" \
  "0" "${HUMAN_SHELL_SUPPRESS_REPORT:-0}"

human-shell details --plain >"$capture_dir/compound-details-render" 2>&1
false
capture_precmd 1

check "compound details keeps the enclosing command-list failure badge" \
  "failed [exit 1]" "$(strip_report "$HOOK_OUTPUT")"

# ---------------------------------------------------------------------------
# Explicit off and trap conflicts remain fail-closed.
# ---------------------------------------------------------------------------

_human_shell_diagnostics_reset
HUMAN_SHELL_DIAGNOSTICS=off

typeset off_source=$'false\ntrue'
capture_preexec "$off_source"

check "diagnostics off keeps preexec silent" \
  "" "$HOOK_OUTPUT"
check "diagnostics off installs no collector trap" \
  "0" "$(( ${+functions[TRAPZERR]} ))"
check "diagnostics off leaves snapshot state idle" \
  "idle" "${_HUMAN_SHELL_DIAG_STATE:-missing}"

capture_precmd 0

check "diagnostics off preserves normal aggregate reporting" \
  "success [exit 0]" "$(strip_report "$HOOK_OUTPUT")"

_human_shell_diagnostics_reset
HUMAN_SHELL_DIAGNOSTICS=details

TRAPZERR() {
  typeset -g _HS_USER_ZERR_RAN=1
  return 0
}

typeset user_trap_before="${functions[TRAPZERR]}"
typeset conflict_source=$'false\ntrue'

capture_preexec "$conflict_source"
typeset user_trap_after_begin="${functions[TRAPZERR]}"

check "a ZERR conflict prevents collection" \
  "0" "${_HUMAN_SHELL_DIAG_ACTIVE:-0}"
check "a ZERR conflict creates an unavailable snapshot" \
  "unavailable" "${_HUMAN_SHELL_DIAG_STATE:-missing}"
check "a ZERR conflict records its reason" \
  "existing ZERR trap" "${_HUMAN_SHELL_DIAG_REASON-}"
check "preexec preserves the existing user trap" \
  "$user_trap_before" "$user_trap_after_begin"

capture_precmd 0

check "conflict handling preserves normal aggregate reporting" \
  "success [exit 0]" "$(strip_report "$HOOK_OUTPUT")"
check "precmd preserves the unavailable snapshot" \
  "unavailable" "${_HUMAN_SHELL_DIAG_STATE:-missing}"
check "precmd preserves the conflict reason" \
  "existing ZERR trap" "${_HUMAN_SHELL_DIAG_REASON-}"
check "precmd preserves the existing user trap" \
  "$user_trap_before" "${functions[TRAPZERR]}"

unfunction TRAPZERR
_human_shell_diagnostics_reset

unset COLUMNS
rm -rf -- "$capture_dir"
trap - EXIT

print
print -r -- "$passed passed, $failed failed."
(( failed == 0 ))

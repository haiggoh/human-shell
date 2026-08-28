#!/bin/zsh -f
# Contract tests for Human Shell's opt-in multiline diagnostics collector.
# This file is intentionally added before the collector implementation and is
# wired into the complete suite only after the implementation satisfies it.

emulate -R zsh
setopt no_aliases

repo="${0:A:h:h}"

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

finish() {
  print
  print -r -- "$passed passed, $failed failed."
  (( failed == 0 ))
}

unset \
  HUMAN_SHELL_STATUS \
  HUMAN_SHELL_READY \
  HUMAN_SHELL_LAUNCHER \
  HUMAN_SHELL_DIAGNOSTICS

source "$repo/human-shell.zsh"

check "diagnostics are disabled by default" \
  "off" "${HUMAN_SHELL_DIAGNOSTICS:-off}"

typeset -a required_functions=(
  _human_shell_diagnostics_begin
  _human_shell_diagnostics_finish
  _human_shell_diagnostics_reset
)

typeset -a missing_functions=()
typeset function_name

for function_name in "${required_functions[@]}"; do
  if (( ! ${+functions[$function_name]} )); then
    missing_functions+=("$function_name")
  fi
done

check "the diagnostics collector API is available" \
  "none" "${(j:,:)missing_functions:-none}"

# Before implementation, stop after reporting the exact missing API. This keeps
# the contract executable without producing a cascade of command-not-found
# errors. Once the functions exist, every behavioral assertion below runs.
if (( ${#missing_functions} )); then
  finish
  exit $?
fi

_human_shell_diagnostics_reset

check "reset leaves collection inactive" \
  "0" "${_HUMAN_SHELL_DIAG_ACTIVE:-0}"
check "reset leaves the collector idle" \
  "idle" "${_HUMAN_SHELL_DIAG_STATE:-missing}"
check "reset removes any event statuses" \
  "0" "${#_HUMAN_SHELL_DIAG_EVENT_STATUS}"
check "reset removes any event pipelines" \
  "0" "${#_HUMAN_SHELL_DIAG_EVENT_PIPELINE}"
check "reset removes any event locations" \
  "0" "${#_HUMAN_SHELL_DIAG_EVENT_TRACE}"
check "reset removes the stored source" \
  "" "${_HUMAN_SHELL_DIAG_SOURCE-}"
check "reset leaves no ZERR trap" \
  "0" "$(( ${+functions[TRAPZERR]} ))"

# Disabled diagnostics must not retain source, install a trap, or become active.
HUMAN_SHELL_DIAGNOSTICS=off
_human_shell_diagnostics_begin $'print first\nfalse'

check "disabled diagnostics do not arm" \
  "0" "${_HUMAN_SHELL_DIAG_ACTIVE:-0}"
check "disabled diagnostics remain idle" \
  "idle" "${_HUMAN_SHELL_DIAG_STATE:-missing}"
check "disabled diagnostics install no trap" \
  "0" "$(( ${+functions[TRAPZERR]} ))"
check "disabled diagnostics retain no source" \
  "" "${_HUMAN_SHELL_DIAG_SOURCE-}"

# Details mode is multiline-only. A normal one-line command must stay on the
# existing Human Shell path without occupying ZERR.
HUMAN_SHELL_DIAGNOSTICS=details
_human_shell_diagnostics_begin 'false'

check "a single-line command does not arm diagnostics" \
  "0" "${_HUMAN_SHELL_DIAG_ACTIVE:-0}"
check "a single-line command leaves the collector idle" \
  "idle" "${_HUMAN_SHELL_DIAG_STATE:-missing}"
check "a single-line command installs no trap" \
  "0" "$(( ${+functions[TRAPZERR]} ))"

# A multiline command in details mode starts one silent collection session.
typeset multiline_source=$'print first\nfalse\nprint last'
_human_shell_diagnostics_begin "$multiline_source"

check "a multiline command arms diagnostics" \
  "1" "${_HUMAN_SHELL_DIAG_ACTIVE:-0}"
check "an armed collector reports collecting state" \
  "collecting" "${_HUMAN_SHELL_DIAG_STATE:-missing}"
check "the exact multiline source is retained" \
  "$multiline_source" "${_HUMAN_SHELL_DIAG_SOURCE-}"
check "arming installs a function-form ZERR trap" \
  "1" "$(( ${+functions[TRAPZERR]} ))"

# A recovered standalone failure is observed without changing the later
# aggregate success.
false
true
typeset -a observed_after_failure=( "$?" "${pipestatus[@]}" )

check "collection preserves a later aggregate success" \
  "0,0" "${(j:,:)observed_after_failure}"
check "the collector records one recovered failure" \
  "1" "${#_HUMAN_SHELL_DIAG_EVENT_STATUS}"
check "the collector records the scalar status" \
  "1" "${_HUMAN_SHELL_DIAG_EVENT_STATUS[1]-}"
check "the collector records pipestatus independently" \
  "1" "${_HUMAN_SHELL_DIAG_EVENT_PIPELINE[1]-}"

if [[ -n "${_HUMAN_SHELL_DIAG_EVENT_TRACE[1]-}" ]]; then
  location_result='present'
else
  location_result='missing'
fi

check "the collector records a location candidate" \
  "present" "$location_result"

_human_shell_diagnostics_finish 0

check "finishing disarms collection" \
  "0" "${_HUMAN_SHELL_DIAG_ACTIVE:-0}"
check "finishing freezes a complete snapshot" \
  "complete" "${_HUMAN_SHELL_DIAG_STATE:-missing}"
check "finishing removes Human Shell's own trap" \
  "0" "$(( ${+functions[TRAPZERR]} ))"
check "finishing preserves the frozen event" \
  "1" "${#_HUMAN_SHELL_DIAG_EVENT_STATUS}"
check "finishing stores the aggregate status" \
  "0" "${_HUMAN_SHELL_DIAG_OVERALL_STATUS:-missing}"

# Collection itself must emit no bytes on either output channel.
typeset silent_dir silent_stdout silent_stderr
silent_dir="$(mktemp -d)"

{
  _human_shell_diagnostics_reset
  HUMAN_SHELL_DIAGNOSTICS=details
  _human_shell_diagnostics_begin $'false\ntrue'
  false
  true
  _human_shell_diagnostics_finish 0
} >"$silent_dir/stdout" 2>"$silent_dir/stderr"

silent_stdout="$(<"$silent_dir/stdout")"
silent_stderr="$(<"$silent_dir/stderr")"
rm -rf -- "$silent_dir"

check "arming, collecting, and finishing emit no stdout" \
  "" "$silent_stdout"
check "arming, collecting, and finishing emit no stderr" \
  "" "$silent_stderr"

# Existing user traps are singleton resources. Human Shell must fail closed,
# retain no source, and leave the existing definition untouched.
_human_shell_diagnostics_reset

TRAPZERR() {
  typeset -g _HS_USER_TRAP_RAN=1
  return 0
}

typeset user_trap_before="${functions[TRAPZERR]}"
HUMAN_SHELL_DIAGNOSTICS=details
_human_shell_diagnostics_begin $'false\ntrue'
typeset user_trap_after="${functions[TRAPZERR]}"

check "an existing ZERR trap prevents collection" \
  "0" "${_HUMAN_SHELL_DIAG_ACTIVE:-0}"
check "a trap conflict is recorded as unavailable" \
  "unavailable" "${_HUMAN_SHELL_DIAG_STATE:-missing}"
check "a trap conflict records a reason" \
  "existing ZERR trap" "${_HUMAN_SHELL_DIAG_REASON-}"
check "a trap conflict preserves the existing definition" \
  "$user_trap_before" "$user_trap_after"
check "a trap conflict retains no source text" \
  "" "${_HUMAN_SHELL_DIAG_SOURCE-}"

unfunction TRAPZERR
_human_shell_diagnostics_reset

# A list-form trap is visible through the trap builtin but not through the
# functions table. It must be detected and preserved independently.
trap 'typeset -g _HS_LIST_TRAP_RAN=1' ZERR
typeset list_trap_before="$(trap)"

HUMAN_SHELL_DIAGNOSTICS=details
_human_shell_diagnostics_begin $'false\ntrue'

typeset list_trap_after="$(trap)"

check "a list-form ZERR trap is absent from the functions table" \
  "0" "$(( ${+functions[TRAPZERR]} ))"
check "a list-form ZERR trap prevents collection" \
  "0" "${_HUMAN_SHELL_DIAG_ACTIVE:-0}"
check "a list-form conflict is recorded as unavailable" \
  "unavailable" "${_HUMAN_SHELL_DIAG_STATE:-missing}"
check "a list-form conflict records the ZERR reason" \
  "existing ZERR trap" "${_HUMAN_SHELL_DIAG_REASON-}"
check "a list-form conflict preserves exact trap state" \
  "$list_trap_before" "$list_trap_after"
check "a list-form conflict retains no source text" \
  "" "${_HUMAN_SHELL_DIAG_SOURCE-}"

trap - ZERR
_human_shell_diagnostics_reset

# Caller option state is preserved, while Human Shell's trap installation and
# cleanup still persist when LOCAL_TRAPS is enabled.
setopt local_traps
HUMAN_SHELL_DIAGNOSTICS=details
_human_shell_diagnostics_begin $'false\ntrue'

check "LOCAL_TRAPS remains enabled after collector installation" \
  "on" "$([[ -o LOCAL_TRAPS ]] && print on || print off)"
check "the collector trap persists with LOCAL_TRAPS enabled" \
  "1" "$(( ${+functions[TRAPZERR]} ))"

false
true

check "collection works with LOCAL_TRAPS enabled" \
  "1" "${#_HUMAN_SHELL_DIAG_EVENT_STATUS}"
check "collection retains the failure with LOCAL_TRAPS enabled" \
  "1" "${_HUMAN_SHELL_DIAG_EVENT_STATUS[1]-}"

_human_shell_diagnostics_finish 0

check "LOCAL_TRAPS remains enabled after collector cleanup" \
  "on" "$([[ -o LOCAL_TRAPS ]] && print on || print off)"
check "collector cleanup persists with LOCAL_TRAPS enabled" \
  "0" "$(( ${+functions[TRAPZERR]} ))"
check "the LOCAL_TRAPS snapshot completes normally" \
  "complete" "${_HUMAN_SHELL_DIAG_STATE:-missing}"

unsetopt local_traps
_human_shell_diagnostics_reset

# Source retention is bounded at 256 KiB. The exact boundary is accepted.
typeset source_at_limit=$'\n'"${(l:262143::x:)}"

HUMAN_SHELL_DIAGNOSTICS=details
_human_shell_diagnostics_begin "$source_at_limit"

check "a source exactly 256 KiB is accepted" \
  "1" "${_HUMAN_SHELL_DIAG_ACTIVE:-0}"
check "the exact source limit is retained completely" \
  "262144" "${#_HUMAN_SHELL_DIAG_SOURCE}"
check "the exact source limit installs the collector trap" \
  "1" "$(( ${+functions[TRAPZERR]} ))"

_human_shell_diagnostics_finish 0
_human_shell_diagnostics_reset

# One byte beyond the bound fails closed without retaining source or occupying
# the singleton ZERR trap.
typeset source_over_limit="${source_at_limit}x"

HUMAN_SHELL_DIAGNOSTICS=details
_human_shell_diagnostics_begin "$source_over_limit"

check "a source over 256 KiB does not arm collection" \
  "0" "${_HUMAN_SHELL_DIAG_ACTIVE:-0}"
check "an oversized source is recorded as unavailable" \
  "unavailable" "${_HUMAN_SHELL_DIAG_STATE:-missing}"
check "an oversized source records the size-limit reason" \
  "source exceeds 256 KiB" "${_HUMAN_SHELL_DIAG_REASON-}"
check "an oversized source is not retained" \
  "" "${_HUMAN_SHELL_DIAG_SOURCE-}"
check "an oversized source installs no trap" \
  "0" "$(( ${+functions[TRAPZERR]} ))"

_human_shell_diagnostics_reset

# Storage is bounded. Additional events set an overflow flag rather than growing
# the in-memory arrays without limit.
HUMAN_SHELL_DIAGNOSTICS=details
_human_shell_diagnostics_begin $'false\ntrue'

typeset -i event_index
for event_index in {1..260}; do
  false
done
true

check "event storage is bounded at 256 statuses" \
  "256" "${#_HUMAN_SHELL_DIAG_EVENT_STATUS}"
check "event storage is bounded at 256 pipelines" \
  "256" "${#_HUMAN_SHELL_DIAG_EVENT_PIPELINE}"
check "event storage is bounded at 256 locations" \
  "256" "${#_HUMAN_SHELL_DIAG_EVENT_TRACE}"
check "additional events set the overflow flag" \
  "1" "${_HUMAN_SHELL_DIAG_OVERFLOW:-0}"

_human_shell_diagnostics_finish 0

# If code in the multiline block replaces Human Shell's temporary trap, cleanup
# must not overwrite or remove the user's resulting definition.
_human_shell_diagnostics_reset
HUMAN_SHELL_DIAGNOSTICS=details
_human_shell_diagnostics_begin $'false\ntrue'

TRAPZERR() {
  typeset -g _HS_REPLACEMENT_TRAP_RAN=1
  return 0
}

typeset replacement_before_finish="${functions[TRAPZERR]}"
_human_shell_diagnostics_finish 0
typeset replacement_after_finish="${functions[TRAPZERR]}"

check "a replacement trap survives collector cleanup" \
  "$replacement_before_finish" "$replacement_after_finish"
check "trap replacement marks the snapshot incomplete" \
  "incomplete" "${_HUMAN_SHELL_DIAG_STATE:-missing}"
check "trap replacement records an ownership-change reason" \
  "ZERR trap changed during collection" "${_HUMAN_SHELL_DIAG_REASON-}"

unfunction TRAPZERR
_human_shell_diagnostics_reset

finish

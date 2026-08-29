#!/bin/zsh -f
# Contract tests for the zsh semantics on which multiline diagnostics relies.
# These characterize zsh itself; the production collector is tested separately.

emulate -R zsh
setopt no_aliases

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

zmodload zsh/parameter || {
  print -u2 -- 'FAIL: zsh/parameter is unavailable.'
  exit 1
}

typeset -ga _HS_EVENT_STATUS=()
typeset -ga _HS_EVENT_PIPELINE=()
typeset -ga _HS_EVENT_TRACE=()

TRAPZERR() {
  # All expansions in this first command occur before the trap changes either
  # status parameter. The scalar status and pipestatus are intentionally stored
  # separately because they do not agree in every execution context.
  local -a _hs_capture=( "$?" "${pipestatus[@]}" )
  local _hs_pipeline=''

  if (( ${#_hs_capture} > 1 )); then
    _hs_pipeline="${(j:,:)_hs_capture[2,-1]}"
  fi

  _HS_EVENT_STATUS+=("${_hs_capture[1]}")
  _HS_EVENT_PIPELINE+=("$_hs_pipeline")
  _HS_EVENT_TRACE+=("${funcfiletrace[1]-}")

  return 0
}

_hs_reset_events() {
  _HS_EVENT_STATUS=()
  _HS_EVENT_PIPELINE=()
  _HS_EVENT_TRACE=()
  return 0
}

_hs_status_seven() {
  return 7
}

# A function can return an arbitrary nonzero status without terminating this
# test script. Both the caller and trap must retain that exact value.
_hs_reset_events
_hs_status_seven
typeset -a _hs_observed=( "$?" "${pipestatus[@]}" )

check "an arbitrary function status survives a function-form ZERR trap" \
  "7,7" "${(j:,:)_hs_observed}"
check "ZERR records the arbitrary scalar status" \
  "7" "${_HS_EVENT_STATUS[1]-}"
check "ZERR records its corresponding pipeline status" \
  "7" "${_HS_EVENT_PIPELINE[1]-}"

# Expected failures used for shell control flow must not become diagnostics.
_hs_reset_events
false || true
_hs_observed=( "$?" "${pipestatus[@]}" )

check "an OR-list recovery finishes successfully" \
  "0,0" "${(j:,:)_hs_observed}"
check "an OR-list test does not trigger ZERR" \
  "0" "${#_HS_EVENT_STATUS}"

_hs_reset_events
if false; then
  true
else
  true
fi
_hs_observed=( "$?" "${pipestatus[@]}" )

check "an if condition finishes through its selected branch" \
  "0,0" "${(j:,:)_hs_observed}"
check "an if condition does not trigger ZERR" \
  "0" "${#_HS_EVENT_STATUS}"

# A standalone failure remains observable even when a later command makes the
# complete submission successful.
_hs_reset_events
false
true
_hs_observed=( "$?" "${pipestatus[@]}" )

check "a later success remains the aggregate result" \
  "0,0" "${(j:,:)_hs_observed}"
check "an earlier standalone failure remains observable" \
  "1" "${_HS_EVENT_STATUS[1]-}"
check "the earlier standalone failure is recorded once" \
  "1" "${#_HS_EVENT_STATUS}"

# PIPE_FAIL controls whether a failed non-final pipeline component becomes an
# unsuppressed aggregate pipeline failure.
_hs_reset_events
unsetopt pipe_fail
false | true
_hs_observed=( "$?" "${pipestatus[@]}" )

check "a pipeline without PIPE_FAIL preserves every component status" \
  "0,1,0" "${(j:,:)_hs_observed}"
check "a successful aggregate pipeline does not trigger ZERR" \
  "0" "${#_HS_EVENT_STATUS}"

_hs_reset_events
setopt pipe_fail
true | false | true
_hs_observed=( "$?" "${pipestatus[@]}" )
unsetopt pipe_fail

check "PIPE_FAIL makes the failed three-stage pipeline nonzero" \
  "1,0,1,0" "${(j:,:)_hs_observed}"
check "ZERR records the PIPE_FAIL scalar status" \
  "1" "${_HS_EVENT_STATUS[1]-}"
check "ZERR atomically records all three pipeline components" \
  "0,1,0" "${_HS_EVENT_PIPELINE[1]-}"

# In-memory mutations made inside a successful subshell do not propagate back
# to its parent. This is an explicit first-version collection boundary.
_hs_reset_events
(
  false
  true
)
_hs_observed=( "$?" "${pipestatus[@]}" )

check "a recovered failure inside a subshell leaves the parent successful" \
  "0,0" "${(j:,:)_hs_observed}"
check "a recovered subshell failure is not visible in parent memory" \
  "0" "${#_HS_EVENT_STATUS}"

# If the subshell itself fails, its aggregate failure is visible to the parent.
_hs_reset_events
(
  false
)
_hs_observed=( "$?" "${pipestatus[@]}" )

check "a failing subshell returns failure to its parent" \
  "1,1" "${(j:,:)_hs_observed}"
check "a failing subshell creates one parent-visible aggregate event" \
  "1" "${#_HS_EVENT_STATUS}"
check "the failing subshell aggregate status is retained" \
  "1" "${_HS_EVENT_STATUS[1]-}"

# Command substitutions have the same process-boundary behavior.
_hs_reset_events
_hs_value="$(
  false
  print -r -- value
)"
_hs_observed=( "$?" "${pipestatus[@]}" )

check "a recovered command-substitution failure leaves assignment successful" \
  "0,0" "${(j:,:)_hs_observed}"
check "a successful command substitution returns its intended output" \
  "value" "$_hs_value"
check "a recovered substitution failure is not visible in parent memory" \
  "0" "${#_HS_EVENT_STATUS}"

# A failing substitution is parent-visible, but zsh reports scalar status 1
# while pipestatus is 0. This proves the collector must preserve both fields
# independently rather than reconstructing either one from the other.
_hs_reset_events
_hs_value="$(false)"
_hs_observed=( "$?" "${pipestatus[@]}" )

check "a failing command substitution returns scalar 1 and pipestatus 0" \
  "1,0" "${(j:,:)_hs_observed}"
check "the failing substitution creates one parent-visible event" \
  "1" "${#_HS_EVENT_STATUS}"
check "the failing substitution event retains scalar status 1" \
  "1" "${_HS_EVENT_STATUS[1]-}"
check "the failing substitution event independently retains pipestatus 0" \
  "0" "${_HS_EVENT_PIPELINE[1]-}"

if [[ -n "${_HS_EVENT_TRACE[1]-}" && "${_HS_EVENT_TRACE[1]}" == *:<-> ]]; then
  _hs_location_result='validated candidate'
else
  _hs_location_result='unavailable'
fi

check "funcfiletrace supplies a file-and-line location candidate" \
  "validated candidate" "$_hs_location_result"

unfunction TRAPZERR

print
print -r -- "$passed passed, $failed failed."

if (( failed == 0 )); then
  exit 0
else
  exit 1
fi

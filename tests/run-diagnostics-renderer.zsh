#!/bin/zsh -f
# Contract for rendering frozen multiline-diagnostics snapshots.
# Command identity and exact pasted-line attribution are deliberately excluded:
# TRAPZERR does not expose reliable command text, and interactive line mapping
# has not passed a deterministic PTY test.

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

contains() {
  local description="$1" needle="$2" haystack="$3"

  if [[ "$haystack" == *"$needle"* ]]; then
    (( passed += 1 ))
    print -r -- "PASS: $description"
  else
    (( failed += 1 ))
    print -u2 -r -- "FAIL: $description"
    print -u2 -r -- "  missing: [$needle]"
    print -u2 -r -- "  output:  [$haystack]"
  fi
}

excludes() {
  local description="$1" needle="$2" haystack="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    (( passed += 1 ))
    print -r -- "PASS: $description"
  else
    (( failed += 1 ))
    print -u2 -r -- "FAIL: $description"
    print -u2 -r -- "  forbidden: [$needle]"
    print -u2 -r -- "  output:    [$haystack]"
  fi
}

unset \
  HUMAN_SHELL_STATUS \
  HUMAN_SHELL_READY \
  HUMAN_SHELL_LAUNCHER \
  HUMAN_SHELL_DIAGNOSTICS

source "$repo/human-shell.zsh"

typeset render_dir
render_dir="$(mktemp -d)"
trap 'rm -rf -- "$render_dir"' EXIT

capture_details() {
  local output_file="$render_dir/details"

  _human_shell_details "$@" >"$output_file"
  typeset -g DETAILS_STATUS=$?
  typeset -g DETAILS_OUTPUT="$(<"$output_file")"
  return 0
}

# ---------------------------------------------------------------------------
# No frozen snapshot.
# ---------------------------------------------------------------------------

_human_shell_diagnostics_reset

capture_details --plain
no_snapshot="$DETAILS_OUTPUT"
no_snapshot_status="$DETAILS_STATUS"

check "details returns success when no snapshot exists" \
  "0" "$no_snapshot_status"
check "details explains that no snapshot exists" \
  "No multiline diagnostics are available." "$no_snapshot"

# ---------------------------------------------------------------------------
# Complete snapshot with two anonymous observed events.
# ---------------------------------------------------------------------------

typeset -g _HUMAN_SHELL_DIAG_STATE=complete
typeset -g _HUMAN_SHELL_DIAG_REASON=''
typeset -g _HUMAN_SHELL_DIAG_SOURCE=$'print first\nfalse\nmissing-command\nprint last'
typeset -g _HUMAN_SHELL_DIAG_OVERALL_STATUS=0
typeset -g _HUMAN_SHELL_DIAG_OVERFLOW=0
typeset -ga _HUMAN_SHELL_DIAG_EVENT_STATUS=(1 127)
typeset -ga _HUMAN_SHELL_DIAG_EVENT_PIPELINE=(1 127)
typeset -ga _HUMAN_SHELL_DIAG_EVENT_TRACE=(
  ''
  '/tmp/deploy.zsh:42'
)

capture_details --plain
complete_output="$DETAILS_OUTPUT"
complete_status="$DETAILS_STATUS"

check "rendering a complete snapshot returns success" \
  "0" "$complete_status"
contains "complete output has a heading" \
  "Human Shell diagnostics" "$complete_output"
contains "complete output reports collection state" \
  "Collection: complete" "$complete_output"
contains "complete output retains aggregate success" \
  "Overall result: success [exit 0]" "$complete_output"
contains "complete output reports the observed event count" \
  "Observed nonzero events: 2" "$complete_output"
contains "anonymous status 1 is described conservatively" \
  "Event 1: observed nonzero status [exit 1]" "$complete_output"
contains "status 127 retains its portable meaning" \
  "Event 2: not found [exit 127]" "$complete_output"
contains "pipeline status is displayed independently" \
  "pipeline: 1" "$complete_output"
contains "missing attribution is stated explicitly" \
  "source location unavailable" "$complete_output"
contains "a trace is presented only as a location candidate" \
  "location candidate: /tmp/deploy.zsh:42" "$complete_output"

# Renderer-controlled text must make terminal control bytes inert. The raw
# snapshot remains untouched; only its displayed representation is escaped.
typeset raw_trace=$'/tmp/\e[31mbad\tname\r.zsh:9'
_HUMAN_SHELL_DIAG_EVENT_TRACE[2]="$raw_trace"

capture_details --plain
escaped_output="$DETAILS_OUTPUT"

contains "control characters are rendered visibly and inertly" \
  "location candidate: /tmp/^[[31mbad\\tname^M.zsh:9" \
  "$escaped_output"
excludes "escaped output contains no raw escape byte" \
  $'\e' "$escaped_output"
excludes "escaped output contains no raw tab byte" \
  $'\t' "$escaped_output"
excludes "escaped output contains no raw carriage return" \
  $'\r' "$escaped_output"
check "escaping does not rewrite the retained raw trace" \
  "$raw_trace" "${_HUMAN_SHELL_DIAG_EVENT_TRACE[2]}"

_HUMAN_SHELL_DIAG_EVENT_TRACE[2]='/tmp/deploy.zsh:42'

excludes "anonymous status 1 is not called a diff" \
  "diff detected" "$complete_output"
excludes "anonymous status 1 is not called no-match" \
  "no match" "$complete_output"
excludes "renderer does not invent pasted line numbers" \
  "line 2" "$complete_output"
excludes "plain output contains no ANSI escape byte" \
  $'\e' "$complete_output"

# Ordinary rendering must not consume or rewrite the snapshot.
check "ordinary rendering preserves snapshot state" \
  "complete" "$_HUMAN_SHELL_DIAG_STATE"
check "ordinary rendering preserves event statuses" \
  "1,127" "${(j:,:)_HUMAN_SHELL_DIAG_EVENT_STATUS}"
check "ordinary rendering preserves retained source" \
  $'print first\nfalse\nmissing-command\nprint last' \
  "$_HUMAN_SHELL_DIAG_SOURCE"

# ---------------------------------------------------------------------------
# Incomplete, unavailable, and overflow states.
# ---------------------------------------------------------------------------

typeset -g _HUMAN_SHELL_DIAG_STATE=incomplete
typeset -g _HUMAN_SHELL_DIAG_REASON='ZERR trap changed during collection'

capture_details --plain
incomplete_output="$DETAILS_OUTPUT"

contains "incomplete output identifies the incomplete snapshot" \
  "Collection: incomplete" "$incomplete_output"
contains "incomplete output explains why collection stopped" \
  "ZERR trap changed during collection" "$incomplete_output"

_human_shell_diagnostics_reset
typeset -g _HUMAN_SHELL_DIAG_STATE=unavailable
typeset -g _HUMAN_SHELL_DIAG_REASON='existing ZERR trap'

capture_details --plain
unavailable_output="$DETAILS_OUTPUT"

contains "unavailable output identifies unavailable collection" \
  "Collection: unavailable" "$unavailable_output"
contains "unavailable output reports the fail-closed reason" \
  "existing ZERR trap" "$unavailable_output"

_human_shell_diagnostics_reset
typeset -g _HUMAN_SHELL_DIAG_STATE=complete
typeset -g _HUMAN_SHELL_DIAG_OVERALL_STATUS=1
typeset -g _HUMAN_SHELL_DIAG_OVERFLOW=1
typeset -ga _HUMAN_SHELL_DIAG_EVENT_STATUS=({1..256})
typeset -ga _HUMAN_SHELL_DIAG_EVENT_PIPELINE=({1..256})
typeset -ga _HUMAN_SHELL_DIAG_EVENT_TRACE=(${(l:256:::)""})

capture_details --plain
overflow_output="$DETAILS_OUTPUT"

contains "overflow output reports the retained event count" \
  "Observed nonzero events: 256" "$overflow_output"
contains "overflow output warns that additional events were omitted" \
  "Additional events were omitted after the 256-event limit." \
  "$overflow_output"

# ---------------------------------------------------------------------------
# Clear and usage behavior.
# ---------------------------------------------------------------------------

capture_details --clear --plain
clear_output="$DETAILS_OUTPUT"
clear_status="$DETAILS_STATUS"

check "clear returns success" "0" "$clear_status"
check "clear confirms that diagnostics were erased" \
  "Multiline diagnostics cleared." "$clear_output"
check "clear returns snapshot state to idle" \
  "idle" "$_HUMAN_SHELL_DIAG_STATE"
check "clear removes retained source" \
  "" "$_HUMAN_SHELL_DIAG_SOURCE"
check "clear removes retained events" \
  "0" "${#_HUMAN_SHELL_DIAG_EVENT_STATUS}"

_human_shell_details --unknown >/dev/null 2>&1
unknown_status=$?

check "an unknown details option is rejected with status 2" \
  "2" "$unknown_status"

rm -rf -- "$render_dir"
trap - EXIT

print
print -r -- "$passed passed, $failed failed."
(( failed == 0 ))

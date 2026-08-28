#!/bin/zsh -f
# Product-interface contract for default multiline diagnostics and the concise
# `human details` command. Collector mechanics are covered separately.

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

fresh() {
  /usr/bin/env \
    -u HUMAN_SHELL_STATUS \
    -u HUMAN_SHELL_READY \
    -u HUMAN_SHELL_LAUNCHER \
    -u HUMAN_SHELL_DIAGNOSTICS \
    HS_REPO="$repo" \
    /bin/zsh -f -c "$1"
}

# Sourcing Human Shell into an ordinary shell must not enable diagnostics or
# install the short command. Only an active Human Shell receives the feature.
check "a plain shell remains outside diagnostics" \
  "unset:0" \
  "$(fresh '
      source "$HS_REPO/human-shell.zsh"
      print -r -- "${HUMAN_SHELL_DIAGNOSTICS-unset}:$(( ${+functions[human]} ))"
    ')"

# Both active launcher modes collect qualifying multiline diagnostics by
# default. HUMAN_SHELL_READY avoids startup output in this isolated test.
for mode in all failures; do
  check "$mode mode enables diagnostics and the human shorthand by default" \
    "details:1" \
    "$(fresh "
        HUMAN_SHELL_STATUS='$mode'
        HUMAN_SHELL_READY=1
        source \"\$HS_REPO/human-shell.zsh\"
        print -r -- \"\${HUMAN_SHELL_DIAGNOSTICS-unset}:\$(( \${+functions[human]} ))\"
      ")"
done

# Explicit opt-out remains available, but the active-shell command namespace is
# still present so status/help behavior remains consistent.
check "an active user can explicitly disable automatic collection" \
  "off:1" \
  "$(fresh '
      HUMAN_SHELL_STATUS=all
      HUMAN_SHELL_READY=1
      HUMAN_SHELL_DIAGNOSTICS=off
      source "$HS_REPO/human-shell.zsh"
      print -r -- "${HUMAN_SHELL_DIAGNOSTICS-unset}:$(( ${+functions[human]} ))"
    ')"

# Existing user functions and aliases named human must remain untouched.
check "an existing human function is preserved" \
  "same:original-human" \
  "$(fresh '
      human() { print -r -- original-human; }
      before="${functions[human]}"
      HUMAN_SHELL_STATUS=all
      HUMAN_SHELL_READY=1
      source "$HS_REPO/human-shell.zsh"
      after="${functions[human]}"
      [[ "$before" == "$after" ]] && state=same || state=changed
      print -r -- "$state:$(human)"
    ')"

check "an existing human alias is preserved" \
  "same:print -r -- alias-human:0" \
  "$(fresh '
      alias human="print -r -- alias-human"
      before="${aliases[human]}"
      HUMAN_SHELL_STATUS=all
      HUMAN_SHELL_READY=1
      source "$HS_REPO/human-shell.zsh"
      after="${aliases[human]}"
      [[ "$before" == "$after" ]] && state=same || state=changed
      print -r -- "$state:$after:$(( ${+functions[human]} ))"
    ')"

# An executable already named human also owns that command name.
typeset collision_dir
collision_dir="$(mktemp -d)"

cat >"$collision_dir/human" <<'HUMAN_SHELL_EXISTING_HUMAN'
#!/bin/zsh
print -r -- external-human
HUMAN_SHELL_EXISTING_HUMAN
chmod 755 "$collision_dir/human"

check "an existing human executable is not shadowed" \
  "$collision_dir/human:0" \
  "$(
    PATH="$collision_dir:$PATH" \
    HUMAN_SHELL_STATUS=all \
    HUMAN_SHELL_READY=1 \
    HS_REPO="$repo" \
      /bin/zsh -f -c '
        source "$HS_REPO/human-shell.zsh"
        print -r -- "$(command -v human):$(( ${+functions[human]} ))"
      '
  )"

rm -rf -- "$collision_dir"

# The guaranteed namespaced form routes details arguments without launching a
# replacement shell. The dispatcher suppresses its own ordinary status badge.
unset \
  HUMAN_SHELL_STATUS \
  HUMAN_SHELL_READY \
  HUMAN_SHELL_LAUNCHER \
  HUMAN_SHELL_DIAGNOSTICS

source "$repo/human-shell.zsh"

_human_shell_details() {
  typeset -g _HS_DETAILS_CALLED="${(j: :)@}"
  return 0
}

typeset -g _HS_DETAILS_CALLED=''
typeset -g HUMAN_SHELL_SUPPRESS_REPORT=0

human-shell details --plain
details_status=$?

check "human-shell details returns success" \
  "0" "$details_status"
check "human-shell details routes renderer arguments" \
  "--plain" "$_HS_DETAILS_CALLED"
check "human-shell details suppresses its own ordinary badge" \
  "1" "${HUMAN_SHELL_SUPPRESS_REPORT:-0}"

# The preferred shorthand routes through the same renderer in an active Human
# Shell and accepts detail options.
check "human details routes to the diagnostics renderer" \
  "--clear:0:1" \
  "$(fresh '
      HUMAN_SHELL_STATUS=all
      HUMAN_SHELL_READY=1
      source "$HS_REPO/human-shell.zsh"

      _human_shell_details() {
        print -r -- "${(j: :)@}:0:${HUMAN_SHELL_SUPPRESS_REPORT:-0}"
        return 0
      }

      human details --clear
    ')"

# The shorthand is a narrow dispatcher, not a new general-purpose namespace.
check "an unknown human action is rejected with status 2" \
  "2" \
  "$(fresh '
      HUMAN_SHELL_STATUS=all
      HUMAN_SHELL_READY=1
      source "$HS_REPO/human-shell.zsh"
      human nonsense >/dev/null 2>&1
      print -r -- "$?"
    ')"

print
print -r -- "$passed passed, $failed failed."
(( failed == 0 ))

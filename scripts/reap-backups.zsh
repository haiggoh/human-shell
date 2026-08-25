#!/bin/zsh
# Keep the newest few backups matching a prefix and remove the rest.
#
# Human Shell writes a timestamped backup on every install: the previous user
# copy under ~/.local/share/human-shell, and the previous ~/.zshrc in the home
# directory. Both exist so a failed install can be rolled back, and neither was
# ever removed once the install had succeeded, so each accumulated one entry per
# run forever. This is the one implementation both installers call.
#
# Usage:
#   reap-backups.zsh --dir DIR --prefix PREFIX [--suffix SUFFIX]
#                    [--keep N] [--kind file|directory]
#                    [--label SINGULAR] [--label-plural PLURAL]
#
# Selection is deliberately narrow. A backup is a candidate only when it sits
# directly in DIR, its name starts with PREFIX and ends with SUFFIX, and it is
# of the requested kind. Newest by modification time are kept.

set -e

directory=''
prefix=''
suffix=''
keep=3
kind='directory'
label='backup'
label_plural=''

while (( $# )); do
  case "$1" in
    --dir)    directory="${2-}"; shift 2 ;;
    --prefix) prefix="${2-}";    shift 2 ;;
    --suffix) suffix="${2-}";    shift 2 ;;
    --keep)   keep="${2-}";      shift 2 ;;
    --kind)   kind="${2-}";      shift 2 ;;
    --label)  label="${2-}";     shift 2 ;;
    --label-plural) label_plural="${2-}"; shift 2 ;;
    *) print -u2 "FAIL: unknown argument: $1"; exit 2 ;;
  esac
done

# An empty prefix would match every entry in the directory, so it is refused
# rather than defaulted: the cost of getting this wrong is deleting the user's
# files, and no caller has a legitimate reason to pass one.
if [[ -z "$prefix" ]]; then
  print -u2 "FAIL: --prefix is required and must not be empty."
  exit 2
fi

if [[ -z "$directory" ]]; then
  print -u2 "FAIL: --dir is required."
  exit 2
fi

if [[ "$keep" != <-> ]]; then
  print -u2 "FAIL: --keep must be a non-negative integer, got: $keep"
  exit 2
fi

# English plurals are not a suffix rule -- "user copy" would become "user copys"
# -- so the plural is given rather than derived, defaulting only for labels the
# naive rule happens to get right.
: "${label_plural:=${label}s}"

case "$kind" in
  file|directory) ;;
  *) print -u2 "FAIL: --kind must be file or directory, got: $kind"; exit 2 ;;
esac

# Nothing to do rather than an error: the very first install has no backups yet,
# and an uninstalled directory may not exist at all.
[[ -d "$directory" ]] || exit 0

# N skips the "no matches" error, om orders newest first, and the type qualifier
# keeps a file from being mistaken for a directory backup or the reverse.
if [[ "$kind" == 'directory' ]]; then
  backups=("$directory/$prefix"*"$suffix"(N/om))
else
  backups=("$directory/$prefix"*"$suffix"(N.om))
fi

(( ${#backups} > keep )) || exit 0

stale=("${backups[@]:$keep}")
for entry in "${stale[@]}"; do
  rm -rf -- "$entry"
done

if (( ${#stale} == 1 )); then
  print "PASS: pruned 1 superseded $label, kept the newest $keep."
else
  print "PASS: pruned ${#stale} superseded $label_plural, kept the newest $keep."
fi

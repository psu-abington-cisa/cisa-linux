#!/usr/bin/env bash
# Syntax-check all shell scripts and flag Windows (CRLF) line endings.
cd "$(dirname "$0")/.."
rc=0
for f in build.sh auto/* branding/make-branding.sh tools/*.sh \
         config/hooks/live/* config/includes.chroot/usr/local/bin/*; do
  bash -n "$f" || { echo "SYNTAX FAIL: $f"; rc=1; }
done
if grep -rlI $'\r' auto build.sh branding/*.sh tools config; then
  echo "^ files above have CRLF line endings"; rc=1
fi
[[ $rc -eq 0 ]] && echo "lint OK"
exit $rc

#!/usr/bin/env bash
# Verify every package in config/package-lists exists in Debian trixie (amd64).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IDX=/var/tmp/trixie-idx/names.txt
mkdir -p "$(dirname "$IDX")"

if [[ ! -s $IDX ]]; then
  for suite in trixie trixie-updates; do
    for area in main contrib non-free non-free-firmware; do
      curl -fsSL "http://deb.debian.org/debian/dists/$suite/$area/binary-amd64/Packages.xz" | xz -d
    done
  done | grep -E '^(Package|Provides):' \
       | sed -E 's/^(Package|Provides): //' | tr ',' '\n' \
       | sed -E 's/^ +//; s/ .*//' | sort -u > "$IDX"
fi

missing=0
for f in "$ROOT"/config/package-lists/*.list.chroot "$ROOT"/config/package-lists/*.list.binary; do
  while read -r p; do
    [[ -z $p || $p == \#* ]] && continue
    if ! grep -qx "$p" "$IDX"; then
      echo "MISSING in $(basename "$f"): $p"
      missing=1
    fi
  done < "$f"
done
[[ $missing -eq 0 ]] && echo "All packages found in trixie."
exit $missing

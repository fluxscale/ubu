#!/usr/bin/env bash
# Checks LISTING.md against App Store Connect character limits.
set -euo pipefail

LISTING="$(dirname "${BASH_SOURCE[0]}")/LISTING.md"
status=0

section() { awk "/<!-- $1 -->/{f=1;next}/<!-- \/$1 -->/{f=0}f" "$LISTING"; }
field() { grep -E "^\| $1 \|" "$LISTING" | head -1 | awk -F' \\| ' '{print $2}' | sed 's/ |$//'; }

check() {
    local name="$1" limit="$2" text="$3"
    local length
    length=$(printf '%s' "$text" | wc -m | tr -d ' ')
    if (( length > limit )); then
        printf '✗ %-18s %4d / %d\n' "$name" "$length" "$limit"
        status=1
    else
        printf '✓ %-18s %4d / %d\n' "$name" "$length" "$limit"
    fi
}

check "Name" 30 "$(field Name)"
check "Subtitle" 30 "$(field Subtitle)"
check "Promotional text" 170 "$(section promo)"
check "Description" 4000 "$(section description)"
check "Keywords" 100 "$(section keywords)"
check "What's New" 4000 "$(section whatsnew)"
check "Review notes" 4000 "$(section review)"
exit $status

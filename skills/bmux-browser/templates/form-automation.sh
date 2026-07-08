#!/usr/bin/env bash
set -euo pipefail

URL="${1:-https://example.com/form}"
SURFACE="${2:-surface:1}"

bmux browser "$SURFACE" goto "$URL"
bmux browser "$SURFACE" get url
bmux browser "$SURFACE" wait --load-state complete --timeout-ms 15000
bmux browser "$SURFACE" snapshot --interactive

echo "Now run fill/click commands using refs from the snapshot above."

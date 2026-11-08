#!/usr/bin/env bash
# Builds docs/install-and-permissions-guide.{ar,en}.pdf from the Markdown guide.
# Needs Node and Google Chrome (or Edge: set CHROME=path/to/msedge.exe).
# Usage (from the repo root): bash tool/install_guide/build.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOCS="$ROOT/docs"
MD="$DOCS/install-and-permissions-guide.ar.md"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CHROME="${CHROME:-}"
if [ -z "$CHROME" ]; then
  for c in "/c/Program Files/Google/Chrome/Application/chrome.exe" \
           "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" \
           "$(command -v google-chrome || true)" "$(command -v chromium || true)"; do
    if [ -n "$c" ] && [ -x "$c" ]; then CHROME="$c"; break; fi
  done
fi
[ -n "$CHROME" ] || { echo "Chrome/Edge not found; set CHROME=..." >&2; exit 1; }

AR_VERSION="$(node "$ROOT/tool/install_guide/md2html.js" "$MD" "$TMP/ar.html" ar)"
EN_VERSION="$(node "$ROOT/tool/install_guide/md2html.js" "$MD" "$TMP/en.html" en)"
if [ "$AR_VERSION" != "$EN_VERSION" ]; then
  echo "Version mismatch: Arabic part says $AR_VERSION, English part says $EN_VERSION" >&2
  exit 1
fi

# Chrome on Windows needs native paths, not Git Bash's /tmp/... ones.
native() { if command -v cygpath >/dev/null; then cygpath -m "$1"; else echo "$1"; fi; }

for L in ar en; do
  PDF="$DOCS/install-and-permissions-guide.$L.pdf"
  rm -f "$PDF"
  "$CHROME" --headless=new --disable-gpu --allow-file-access-from-files --no-pdf-header-footer \
    --print-to-pdf="$(native "$PDF")" "file:///$(native "$TMP/$L.html")" 2>/dev/null || true
  [ -s "$PDF" ] || { echo "Chrome did not produce $PDF" >&2; exit 1; }
done
echo "Built guide version $AR_VERSION:"
ls -la "$DOCS"/install-and-permissions-guide.*.pdf

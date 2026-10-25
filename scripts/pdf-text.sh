#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 INPUT.pdf OUTPUT.txt [FIRST_PAGE [LAST_PAGE]]" >&2
  echo "Extracts selectable PDF text; does not OCR scanned pages." >&2
}

if [[ $# -lt 2 || $# -gt 4 ]]; then usage; exit 2; fi
input=$1
output=$2
first=${3:-1}
last=${4:-}

case "$input" in -*) input="./$input" ;; esac
case "$output" in -*) output="./$output" ;; esac

[[ -f "$input" ]] || { echo "Input PDF not found: $input" >&2; exit 1; }
command -v pdftotext >/dev/null 2>&1 || { echo "Missing pdftotext. In Termux run: pkg install poppler" >&2; exit 1; }
command -v pdfinfo >/dev/null 2>&1 || { echo "Missing pdfinfo. In Termux run: pkg install poppler" >&2; exit 1; }
[[ "$first" =~ ^[0-9]+$ ]] || { echo "FIRST_PAGE must be a positive integer." >&2; exit 2; }
first=$((10#$first))
(( first >= 1 )) || { echo "FIRST_PAGE must be a positive integer." >&2; exit 2; }
if [[ -n "$last" ]]; then
  [[ "$last" =~ ^[0-9]+$ ]] || { echo "LAST_PAGE must be an integer >= FIRST_PAGE." >&2; exit 2; }
  last=$((10#$last))
  (( last >= first )) || { echo "LAST_PAGE must be an integer >= FIRST_PAGE." >&2; exit 2; }
fi
[[ ! -e "$output" ]] || { echo "Refusing to overwrite existing file: $output" >&2; exit 1; }

pages=$(pdfinfo "$input" 2>/dev/null | awk '/^Pages:/ {print $2; exit}') || {
  echo "Could not read PDF metadata: $input" >&2
  exit 1
}
[[ "$pages" =~ ^[0-9]+$ ]] || { echo "Could not determine PDF page count." >&2; exit 1; }
(( first <= pages )) || { echo "FIRST_PAGE $first is beyond the PDF's $pages pages." >&2; exit 2; }
if [[ -n "$last" ]]; then
  (( last <= pages )) || { echo "LAST_PAGE $last is beyond the PDF's $pages pages." >&2; exit 2; }
fi

mkdir -p "$(dirname "$output")"
tmp=$(mktemp "${output}.tmp.XXXXXX")
trap 'rm -f "$tmp"' EXIT
if [[ -n "$last" ]]; then
  pdftotext -f "$first" -l "$last" -layout "$input" "$tmp"
else
  pdftotext -f "$first" -layout "$input" "$tmp"
fi
if ! grep -q '[[:alnum:]]' "$tmp"; then
  echo "No selectable text found in this page range. It may be a scan; use OCR only for selected pages." >&2
  exit 3
fi
mv -n "$tmp" "$output"
if [[ -e "$tmp" ]]; then
  echo "Refusing to overwrite existing file: $output" >&2
  exit 1
fi
trap - EXIT
echo "Saved extracted text to: $output"
echo "PDF metadata:"
pdfinfo "$input" | grep -E '^(Title|Pages|Page size|File size):' || true

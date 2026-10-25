#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 INPUT.pdf OUTPUT_DIR FIRST_PAGE LAST_PAGE" >&2
  echo "Render 1-6 selected PDF pages to PNG for visual review; requires poppler." >&2
}
if [[ $# -ne 4 ]]; then usage; exit 2; fi
input=$1
outdir=$2
first=$3
last=$4

case "$input" in -*) input="./$input" ;; esac
case "$outdir" in -*) outdir="./$outdir" ;; esac
while [[ "$outdir" == */ && "$outdir" != "/" ]]; do outdir=${outdir%/}; done
[[ -n "$outdir" ]] || { echo "OUTPUT_DIR must not be empty." >&2; exit 2; }
[[ "$outdir" != "/" ]] || { echo "Choose a subdirectory, not the filesystem root." >&2; exit 2; }

[[ -f "$input" ]] || { echo "Input PDF not found: $input" >&2; exit 1; }
command -v pdfinfo >/dev/null 2>&1 && command -v pdftoppm >/dev/null 2>&1 || { echo "Missing Poppler tools. In Termux run: pkg install poppler" >&2; exit 1; }
[[ "$first" =~ ^[0-9]+$ && "$last" =~ ^[0-9]+$ ]] || { echo "Page numbers must be positive integers." >&2; exit 2; }
first=$((10#$first))
last=$((10#$last))
(( first >= 1 && last >= first )) || { echo "Require 1 <= FIRST_PAGE <= LAST_PAGE." >&2; exit 2; }
(( last - first + 1 <= 6 )) || { echo "Limit each batch to 6 pages to keep image size and review focused." >&2; exit 2; }
pages=$(pdfinfo "$input" 2>/dev/null | awk '/^Pages:/ {print $2; exit}') || {
  echo "Could not read PDF metadata: $input" >&2
  exit 1
}
[[ "$pages" =~ ^[0-9]+$ ]] || { echo "Could not determine PDF page count." >&2; exit 1; }
(( last <= pages )) || { echo "Requested page $last but PDF has $pages pages." >&2; exit 2; }
if [[ -e "$outdir" && ! -d "$outdir" ]]; then
  echo "Output path exists but is not a directory: $outdir" >&2
  exit 1
fi
if [[ -d "$outdir" ]] && compgen -G "$outdir/page-*.png" >/dev/null; then
  echo "Refusing to overwrite existing page-*.png files in: $outdir" >&2
  echo "Choose a new empty output directory." >&2
  exit 1
fi

outparent=$(dirname "$outdir")
mkdir -p "$outparent"
tmpdir=''
cleanup() {
  if [[ -n "$tmpdir" && -d "$tmpdir" ]]; then
    rm -rf -- "$tmpdir"
  fi
}
trap cleanup EXIT
tmpdir=$(mktemp -d "${outdir}.tmp.XXXXXX")
pdftoppm -png -r 150 -f "$first" -l "$last" -forcenum "$input" "$tmpdir/page"
compgen -G "$tmpdir/page-*.png" >/dev/null || { echo "pdftoppm produced no PNG files." >&2; exit 1; }

if [[ -d "$outdir" ]] && compgen -G "$outdir/page-*.png" >/dev/null; then
  echo "Refusing to overwrite existing page-*.png files in: $outdir" >&2
  echo "Choose a new empty output directory." >&2
  exit 1
fi
mkdir -p "$outdir"
mv -n "$tmpdir"/page-*.png "$outdir"/
if compgen -G "$tmpdir/page-*.png" >/dev/null; then
  echo "Some PNG files were not moved because the destination already contains them: $outdir" >&2
  exit 1
fi
echo "Rendered pages $first-$last (of $pages) into: $outdir"
echo "Attach the PNGs to an OpenCode prompt using a vision-capable model to review handwriting/drawings."

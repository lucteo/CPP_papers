#!/bin/bash

set -e

# Check input argument
SOURCE_FILENAME=$1
if [ -z "$SOURCE_FILENAME" ]; then
  echo "Usage: $0 <source_filename>"
  exit 1
fi

if [ ! -f "$SOURCE_FILENAME" ]; then
  echo "Source file not found!"
  exit 1
fi

# Extract base filename and extension
SOURCE_FILENAME_EXT="${SOURCE_FILENAME##*.}"
SOURCE_FILENAME_BASE="${SOURCE_FILENAME%.*}"
SOURCE_FILENAME_NAME="${SOURCE_FILENAME_BASE##*/}"
FILTERED_BIBLIOGRAPHY="generated/${SOURCE_FILENAME_NAME}.csl.json"
OUTPUT_FILENAME="generated/${SOURCE_FILENAME_NAME}.html"
PANDOC_BIN="wg21/deps/pandoc/2.18/pandoc"
echo "Source filename: $SOURCE_FILENAME"
echo "Source filename base: $SOURCE_FILENAME_BASE"
echo "Source filename ext: $SOURCE_FILENAME_EXT"

generate_filtered_bibliography() {
  mkdir -p generated
  wg21/deps/python/bin/python3 tools/filter-csl-bibliography.py \
    "${SOURCE_FILENAME}" \
    wg21/data/csl.json \
    "${FILTERED_BIBLIOGRAPHY}"
}

generate_html() {
  local toc_depth
  local pandoc_args

  generate_filtered_bibliography
  toc_depth="$(wg21/deps/python/bin/python3 wg21/data/toc-depth.py < "${SOURCE_FILENAME}")"

  pandoc_args=(
    "${SOURCE_FILENAME}"
    -o "${OUTPUT_FILENAME}"
    --mathjax
    -d wg21/data/defaults.yaml
    --bibliography "${FILTERED_BIBLIOGRAPHY}"
  )
  if [ -f defaults.yaml ]; then
    pandoc_args+=(-d defaults.yaml)
  fi
  if [ -f metadata.yaml ]; then
    pandoc_args+=(--metadata-file metadata.yaml)
  fi
  if [ -n "${toc_depth}" ]; then
    pandoc_args+=(--toc-depth "${toc_depth}")
  fi

  PATH="wg21/deps/python/bin:wg21/deps/pandoc/2.18:${PATH}" "${PANDOC_BIN}" "${pandoc_args[@]}"
}

# Bikeshed case
if [ "$SOURCE_FILENAME_EXT" == "bs" ]; then
  # First, open the HTML in the default browser
  open "http://localhost:8000/${SOURCE_FILENAME_BASE}.html"
  # Then, run bikeshed serve, to continuously serve the file
  pipx run bikeshed serve ${SOURCE_FILENAME}
fi

# Markdown case
if [ "$SOURCE_FILENAME_EXT" == "md" ]; then
  # Update the references
  make -f wg21/Makefile update
  # Generate the HTML file for the first time
  generate_html
  # Open the HTML in the default browser
  open "./${OUTPUT_FILENAME}"
  # Now, watch for changes in the source file, and regenerate the HTML file
  fswatch -o "${SOURCE_FILENAME}" | while read; do
    echo "Regenerating HTML file..."
    generate_html
    echo "you can refresh the browser to see the changes"
  done
fi

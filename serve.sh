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
echo "Source filename: $SOURCE_FILENAME"
echo "Source filename base: $SOURCE_FILENAME_BASE"
echo "Source filename ext: $SOURCE_FILENAME_EXT"

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
  # Generate the HTML file fort the first time
  make -f wg21/Makefile "${SOURCE_FILENAME_BASE}.html"
  # Open the HTML in the default browser
  open "./generated/${SOURCE_FILENAME_BASE}.html"
  # Now, watch for changes in the source file, and regenerate the HTML file
  fswatch -o "${SOURCE_FILENAME}" | while read; do
    echo "Regenerating HTML file..."
    make -f wg21/Makefile "${SOURCE_FILENAME_BASE}.html"
  done
fi
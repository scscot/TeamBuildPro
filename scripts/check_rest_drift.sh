#!/bin/bash

# STEP 1: Define patterns that indicate REST-based logic
REST_PATTERNS='http\\.post|http\\.get|securetoken\\.googleapis\\.com|identitytoolkit\\.googleapis\\.com|documents:runQuery'

# STEP 2: Create a list of Dart files in lib/ that still reference REST
echo "🔍 Scanning lib/ for REST-based logic..."
grep -rlE "$REST_PATTERNS" lib/ --include="*.dart" > _rest_based_files.txt

# STEP 3: Extract filenames from Dart_Files.zip for comparison
unzip -l Dart_Files.zip "*.dart" | awk '{print $NF}' | grep '\.dart$' | sed 's|.*/||' | sort > _canvas_file_names.txt

# STEP 4: Compare REST-flagged files to canvas-based files
echo "📄 REST-flagged files not present in SDK canvas:"
while IFS= read -r filepath; do
  filename=$(basename "$filepath")
  if ! grep -q "$filename" _canvas_file_names.txt; then
    echo "⚠️  $filepath"
  fi
done < _rest_based_files.txt

# Cleanup (optional)
# rm _rest_based_files.txt _canvas_file_names.txt

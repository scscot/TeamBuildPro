#!/bin/bash
echo "🧼 Running Dart Formatter and Lint Checker..."

# Format all .dart files
dart format .

# Show any remaining issues via analyzer (optional)
dart analyze .

echo "✅ Project formatted and analyzed."

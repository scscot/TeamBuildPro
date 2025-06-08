#!/bin/bash

# Absolute path to your Flutter project directory
PROJECT_DIR="$HOME/Desktop/tbp"

# AppleScript to open new Terminal tab and run flutter attach with graceful exit
osascript <<EOF
tell application "Terminal"
  activate
  do script "cd \"$PROJECT_DIR\" && flutter attach 2>&1 | grep -v 'Bad state: Stream has already been listened to.'"
end tell
EOF

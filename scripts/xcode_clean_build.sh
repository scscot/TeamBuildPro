#!/bin/bash

# After your Mac has restarted and you've logged back in, open your terminal, navigate back to your project root (cd ~/tbpapp), and run:
# flutter create --org com.scott --platforms=ios .
# flutter pub get
# cd ios && pod install --repo-update && cd ..

# --- Part 1: Manual Aggressive Cleanup of Flutter Project and Xcode Caches ---

echo "--- Phase 1: Aggressive Cleanup Started ---"

# 1. Quit Xcode and any Simulators/Devices
echo "Quitting Xcode and Simulators/Devices..."
killall "Xcode"
killall "Simulator"
# Add any other specific app names you want to ensure are closed, e.g., "iPhone Simulator"
# It might take a moment for apps to fully terminate.

# 2. Navigate to your project root directory
# IMPORTANT: Adjust this path if your project is not in ~/tbpapp
PROJECT_ROOT="$HOME/tbpapp"
echo "Navigating to project root: $PROJECT_ROOT"
cd "$PROJECT_ROOT" || { echo "Error: Project root directory not found. Exiting."; exit 1; }

# 3. Delete the entire ios directory
echo "Deleting existing 'ios' directory..."
rm -rf ios

# 4. Clean Flutter's build artifacts
echo "Cleaning Flutter build artifacts..."
flutter clean

# 5. Delete Flutter's cached engine artifacts and signatures
echo "Deleting Flutter's cached engine artifacts and signatures..."
FLUTTER_ROOT=$(dirname $(dirname $(command -v flutter)))
if [ -z "$FLUTTER_ROOT" ]; then
    echo "Error: Flutter SDK path not found. Please ensure Flutter is in your PATH."
    exit 1
fi
echo "Flutter SDK root found at: $FLUTTER_ROOT"
rm -rf "$FLUTTER_ROOT/bin/cache/artifacts"
echo "Force precaching Flutter artifacts..."
flutter precache --ios --force

# 6. Clean Xcode's derived data and caches
echo "Cleaning Xcode derived data and caches..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/Library/Developer/Xcode/Archives/*
rm -rf ~/Library/Caches/com.apple.dt.Xcode/*
rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/*
rm -rf ~/Library/Developer/Xcode/UserData/IB\ Support/*

# 7. Clear Xcode authentication session and preference files
echo "Clearing Xcode authentication session and preference files..."
rm -rf ~/Library/Developer/Xcode/AuthSession
rm -f ~/Library/Preferences/com.apple.dt.Xcode.plist
rm -f ~/Library/Preferences/com.apple.dt.Xcode.plist.lockfile

# 8. Clean provisioning profiles (if they exist)
echo "Cleaning provisioning profiles..."
if [ -d "~/Library/MobileDevice/Provisioning Profiles/" ]; then
    rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/*
else
    echo "Provisioning Profiles directory not found or already cleaned."
fi

echo "--- Phase 1: Cleanup Finished ---"
echo "Please restart your Mac now. After restarting, run this script again for Phase 2."
echo "You can run 'bash ios_clean_build.sh --phase2' after restart."
exit 0
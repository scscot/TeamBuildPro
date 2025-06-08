#!/bin/bash

# This script performs a comprehensive and aggressive cleanup of Flutter and Xcode caches,
# derived data, and provisioning profiles to ensure a clean build environment.

# Exit immediately if a command exits with a non-zero status.
set -e

echo "🧹 Starting aggressive cleanup of Flutter and Xcode..."

# --- Pre-requisite: Determine FLUTTER_ROOT ---
# This is crucial for commands that rely on the Flutter SDK path.
if [ -z "$FLUTTER_ROOT" ]; then
  FLUTTER_ROOT=$(dirname $(dirname $(command -v flutter)))
  if [ ! -d "$FLUTTER_ROOT/packages/flutter_tools/bin" ]; then
    echo "❌ ERROR: Could not automatically determine FLUTTER_ROOT."
    echo "         Please ensure Flutter SDK is in your PATH or set FLUTTER_ROOT environment variable manually."
    exit 1
  fi
fi
echo "✅ FLUTTER_ROOT detected: $FLUTTER_ROOT"

# --- 1. Terminate Xcode and Simulator processes ---
echo "--- Terminating Xcode and Simulator processes ---"
killall -9 Xcode || true
killall -9 "Simulator" || true
echo "✅ Xcode and Simulator processes terminated."

# --- 2. Clean Flutter project ---
echo "--- Cleaning Flutter project ---"
flutter clean
echo "✅ Flutter project cleaned."

# --- 3. Clean Flutter's cached engine artifacts and signatures ---
echo "--- Cleaning Flutter's cached engine artifacts and codesignatures ---"
rm -rf "$FLUTTER_ROOT/bin/cache/artifacts" || true # Remove all cached engine artifacts
echo "  Removed all cached Flutter engine artifacts."

# Explicitly remove codesignatures from Flutter.framework within Flutter's cache
# This forces a fresh signing by Xcode during the next build.
if [ -d "$FLUTTER_ROOT/bin/cache/artifacts/engine/ios/Flutter.framework" ]; then
  codesign --remove-signature "$FLUTTER_ROOT/bin/cache/artifacts/engine/ios/Flutter.framework" || true
  echo "  Signature removed from debug Flutter.framework cache (if present)."
fi
if [ -d "$FLUTTER_ROOT/bin/cache/artifacts/engine/ios-debug/Flutter.framework" ]; then
  codesign --remove-signature "$FLUTTER_ROOT/bin/cache/artifacts/engine/ios-debug/Flutter.framework" || true
  echo "  Signature removed from release Flutter.framework cache (if present)."
fi
echo "✅ Flutter engine artifact caches cleared."

# --- 4. Deep clean Xcode caches and DerivedData ---
echo "--- Cleaning Xcode DerivedData, Archives, and other caches ---"
rm -rf ~/Library/Developer/Xcode/DerivedData/* || true
rm -rf ~/Library/Developer/Xcode/Archives/* || true
rm -rf ~/Library/Caches/com.apple.dt.Xcode/* || true          # Xcode's internal caches
rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/* || true # Device Support files, can get corrupted
rm -rf ~/Library/Developer/Xcode/UserData/IB\ Support/* || true # Autosave information
echo "✅ User-specific Xcode caches cleaned."

# --- 5. Clean old provisioning profiles and keychain cache ---
echo "--- Cleaning provisioning profiles and keychain cache ---"
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/* || true
security delete-generic-password -s "XcodeDevTools" 2>/dev/null || true # Clears Xcode login credentials
echo "✅ Provisioning profiles and keychain cache cleared."

# --- 6. Remove Xcode's authentication session and preference files ---
echo "--- Clearing Xcode authentication session and preference files ---"
rm -rf ~/Library/Developer/Xcode/AuthSession || true
rm -f ~/Library/Preferences/com.apple.dt.Xcode.plist || true
rm -f ~/Library/Preferences/com.apple.dt.Xcode.plist.lockfile || true # Remove lockfile as well
echo "✅ Xcode session and preferences cleared."

# --- 7. Clear deeper system-level Xcode caches (requires sudo) ---
# These paths often require elevated privileges.
echo "--- Clearing deeper system-level Xcode caches (requires sudo) ---"
sudo rm -rf /var/folders/*/*/*/com.apple.DeveloperTools/*/Xcode/* || true
sudo rm -rf /Library/Caches/com.apple.DeveloperTools/ || true # Global developer tools cache
echo "✅ Deeper system-level Xcode caches cleared."

# --- 8. Re-precaching Flutter engine artifacts (forces re-download/rebuild) ---
echo "--- Re-precaching Flutter engine artifacts ---"
flutter precache --ios --force
echo "✅ Flutter engine artifacts re-precached."

echo "🎉 Comprehensive cleanup complete. A system restart is highly recommended now."

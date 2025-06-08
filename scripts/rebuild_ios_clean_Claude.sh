#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Define variables
SRC_DIR=~/Desktop/tbp
BUNDLE_ID="com.scott.teambuildApp"
IOS_DIR="$SRC_DIR/ios"
BUILD_MODE="development"  # Set to 'production' for release builds
DEVELOPMENT_TEAM_ID="YXV25WMDS8" # Your Apple Development Team ID

echo "📁 Starting clean iOS rebuild in: $SRC_DIR"

# --- ENHANCED: Check for iCloud sync issues ---
# One of the most common causes of Flutter.framework codesigning failures
echo "🔍 Checking for iCloud sync issues that can cause codesigning failures..."
if [ -d "$SRC_DIR/.git" ]; then
  # Check if any .icloud files exist in the project
  ICLOUD_FILES=$(find "$SRC_DIR" -name "*.icloud" 2>/dev/null | wc -l)
  if [ "$ICLOUD_FILES" -gt 0 ]; then
    echo "⚠️ WARNING: Found $ICLOUD_FILES iCloud placeholder files in project."
    echo "   This is a common cause of Flutter.framework codesigning failures."
    echo "   Consider disabling iCloud sync for this directory or ensure all files are downloaded."
    read -p "   Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "❌ Exiting due to iCloud sync concerns. Please resolve and retry."
      exit 1
    fi
  else
    echo "✅ No iCloud placeholder files detected."
  fi
else
  echo "⚠️ No git repository detected. Consider initializing git to track changes."
fi
# --- END iCloud check ---

# --- Pre-requisite Checks ---
# Ensure necessary tools are installed before proceeding.
echo "⚙️ Performing pre-requisite checks..."

# Check for Xcode Command Line Tools
if ! xcode-select -p &> /dev/null; then
    echo "❌ ERROR: Xcode Command Line Tools are not installed. Please install them by running: xcode-select --install"
    exit 1
fi
echo "✅ Xcode Command Line Tools are installed."

# Check for CocoaPods
if ! command -v pod &> /dev/null; then
    echo "❌ ERROR: CocoaPods is not installed. Please install it by running: sudo gem install cocoapods"
    exit 1
fi
echo "✅ CocoaPods is installed."

# Check for flutterfire_cli and install if missing
if ! dart pub global list | grep -q 'flutterfire_cli'; then
  echo "⚠️ flutterfire_cli not found. Installing it now..."
  dart pub global activate flutterfire_cli
  # Verify installation after attempting it
  if ! dart pub global list | grep -q 'flutterfire_cli'; then
    echo "❌ ERROR: Failed to install flutterfire_cli. Please check your Dart/Flutter setup."
    exit 1
  fi
  echo "✅ flutterfire_cli installed."
else
  echo "✅ flutterfire_cli is installed."
fi

# Check for xcodeproj gem (needed for Ruby script)
if ! gem list xcodeproj -i &> /dev/null; then
  echo "⚠️ xcodeproj Ruby gem not found. Installing it now..."
  sudo gem install xcodeproj
  if ! gem list xcodeproj -i &> /dev/null; then
    echo "❌ ERROR: Failed to install xcodeproj gem. Please check your Ruby setup."
    exit 1
  fi
  echo "✅ xcodeproj gem installed."
else
  echo "✅ xcodeproj gem is installed."
fi

# Check if the 'scripts' directory exists and contains necessary files
if [ ! -d "$SRC_DIR/scripts" ]; then
  echo "❌ ERROR: 'scripts' directory not found at $SRC_DIR/scripts. Please ensure it exists and contains necessary config files."
  exit 1
fi
echo "✅ 'scripts' directory found."
# --- END Pre-requisite Checks ---

# --- ENHANCED: Keychain and Certificate Verification ---
echo "🔐 Verifying Apple Development certificates in keychain..."
CERT_COUNT=$(security find-identity -v -p codesigning | grep "Apple Development" | wc -l)
if [ "$CERT_COUNT" -eq 0 ]; then
  echo "❌ ERROR: No 'Apple Development' certificates found in keychain."
  echo "   Please ensure you have a valid development certificate installed."
  echo "   You can download one from https://developer.apple.com/account/resources/certificates/"
  exit 1
elif [ "$CERT_COUNT" -gt 1 ]; then
  echo "⚠️ WARNING: Multiple Apple Development certificates found ($CERT_COUNT)."
  echo "   This can sometimes cause signing conflicts. Consider cleaning up old certificates."
  security find-identity -v -p codesigning | grep "Apple Development"
else
  echo "✅ Single Apple Development certificate found in keychain."
fi
# --- END Keychain verification ---

# Step 1: Quit Xcode and back up current ios/ directory
# 'killall -9 Xcode || true' attempts to kill Xcode, and '|| true' prevents script from exiting if Xcode isn't running.
killall -9 Xcode || true
# --- ENHANCED: Also kill Simulator which can lock files ---
killall -9 Simulator || true
echo "✅ Xcode and Simulator processes terminated."

BACKUP_NAME="ios_backup_$(date +%s)"
echo "🧼 Backing up ios/ → $BACKUP_NAME"
# Check if ios/ directory exists before attempting to move it
if [ -d "$IOS_DIR" ]; then
  mv "$IOS_DIR" "$SRC_DIR/$BACKUP_NAME"
else
  echo "No existing ios/ directory to back up."
fi

# Step 2: Clean Flutter project and Xcode DerivedData
cd "$SRC_DIR"
echo "🧹 Running flutter clean..."
flutter clean

# --- ENHANCED: More aggressive Xcode cleanup ---
echo "🧹 Performing comprehensive Xcode cleanup..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/Library/Developer/Xcode/Archives/* || true
# Clear iOS DeviceSupport which can have stale data
rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/* || true
# Clear Xcode user data that might have cached signing info
rm -rf ~/Library/Developer/Xcode/UserData/IB\ Support/* || true
echo "✅ Comprehensive Xcode cleanup completed."

# --- ENHANCED: Clean provisioning profiles more thoroughly ---
echo "🧹 Cleaning provisioning profiles and keychain cache..."
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/* || true
# Clear keychain cache for code signing
security delete-generic-password -s "XcodeDevTools" 2>/dev/null || true
echo "✅ Provisioning profiles and keychain cache cleared."
# --- END enhanced cleanup ---

# Step 3: Recreate ios/ project structure and restore essential files
# 'flutter create .' recreates the basic iOS project structure in the current directory.
echo "✨ Recreating Flutter iOS project structure..."
flutter create --org com.scott --platforms=ios .

# Robustly copy custom AppDelegate.swift
echo "🔄 Copying custom AppDelegate.swift..."
if [ ! -f scripts/AppDelegate.swift ]; then
  echo "❌ ERROR: scripts/AppDelegate.swift not found. Cannot proceed without it."
  exit 1
fi
cp scripts/AppDelegate.swift ios/Runner/AppDelegate.swift
echo "✅ AppDelegate.swift copied."

# Step 4: Set Bundle Identifier and Enable Automatic Codesigning in project.pbxproj
echo "✏️ Setting Bundle ID and enabling Automatic Codesigning in project.pbxproj..."

# --- ENHANCED: More precise project configuration ---
# Remove any existing problematic settings before applying new ones
for CONFIG_NAME in "Debug" "Release" "Profile"; do
  echo "🔧 Configuring $CONFIG_NAME build settings..."
  
  # First, remove any potentially conflicting manual signing settings
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGN_STYLE = Manual;//g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/PROVISIONING_PROFILE_SPECIFIER = \".*\";//g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/PROVISIONING_PROFILE = \".*\";//g" ios/Runner.xcodeproj/project.pbxproj
  
  # Now apply the correct automatic signing settings
  # Using a more targeted approach to ensure settings are properly applied
  
  # Set Bundle ID
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/PRODUCT_BUNDLE_IDENTIFIER = .*/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;/g" ios/Runner.xcodeproj/project.pbxproj
  
  # Enable automatic signing
  if ! grep -q "CODE_SIGN_STYLE.*${CONFIG_NAME}" ios/Runner.xcodeproj/project.pbxproj; then
    # Add CODE_SIGN_STYLE if it doesn't exist
    sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/a\\
				CODE_SIGN_STYLE = Automatic;" ios/Runner.xcodeproj/project.pbxproj
  else
    # Update existing CODE_SIGN_STYLE
    sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGN_STYLE = .*/CODE_SIGN_STYLE = Automatic;/g" ios/Runner.xcodeproj/project.pbxproj
  fi
  
  # Set development team
  if ! grep -q "DEVELOPMENT_TEAM.*${CONFIG_NAME}" ios/Runner.xcodeproj/project.pbxproj; then
    sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/a\\
				DEVELOPMENT_TEAM = $DEVELOPMENT_TEAM_ID;" ios/Runner.xcodeproj/project.pbxproj
  else
    sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/DEVELOPMENT_TEAM = .*/DEVELOPMENT_TEAM = $DEVELOPMENT_TEAM_ID;/g" ios/Runner.xcodeproj/project.pbxproj
  fi
  
  # --- CRITICAL: Add specific Flutter.framework signing fixes ---
  # These settings help prevent Flutter.framework signing issues
  if ! grep -q "CODE_SIGNING_ALLOWED.*${CONFIG_NAME}" ios/Runner.xcodeproj/project.pbxproj; then
    sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/a\\
				CODE_SIGNING_ALLOWED = YES;" ios/Runner.xcodeproj/project.pbxproj
  fi
  
  if ! grep -q "CODE_SIGNING_REQUIRED.*${CONFIG_NAME}" ios/Runner.xcodeproj/project.pbxproj; then
    sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/a\\
				CODE_SIGNING_REQUIRED = YES;" ios/Runner.xcodeproj/project.pbxproj
  fi
  
  # Ensure proper identity settings
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGN_IDENTITY = .*/CODE_SIGN_IDENTITY = \"Apple Development\";/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGN_IDENTITY\[sdk=iphoneos\*\] = .*/CODE_SIGN_IDENTITY\[sdk=iphoneos\*\] = \"Apple Development\";/g" ios/Runner.xcodeproj/project.pbxproj

done

# Also set DEVELOPMENT_TEAM at project level to ensure consistency
sed -i '' "s/DEVELOPMENT_TEAM = .*/DEVELOPMENT_TEAM = $DEVELOPMENT_TEAM_ID;/g" ios/Runner.xcodeproj/project.pbxproj

# Confirm Bundle ID patch success
if grep -q "$BUNDLE_ID" ios/Runner.xcodeproj/project.pbxproj; then
  echo "✅ Bundle ID successfully set in project.pbxproj"
else
  echo "❌ Bundle ID patch may have failed in project.pbxproj. Exiting."
  exit 1
fi
echo "✅ Enhanced Automatic Codesigning settings updated in project.pbxproj."

# Step 5: Restore custom Info.plist and Podfile from 'scripts' directory
echo "🔄 Copying custom Info.plist and Podfile..."
# Robustly copy Info.plist
if [ ! -f scripts/Info.plist ]; then
  echo "❌ ERROR: scripts/Info.plist not found. Cannot proceed without it."
  exit 1
fi
cp scripts/Info.plist ios/Runner/Info.plist

# Robustly copy Podfile
if [ ! -f scripts/Podfile ]; then
  echo "❌ ERROR: scripts/Podfile not found. Cannot proceed without it."
  exit 1
fi
cp scripts/Podfile ios/Podfile

echo "✅ Info.plist and Podfile copied."

# Step 5.1: Patch Info.plist with correct Bundle ID and Display Names
echo "✏️ Setting Bundle ID, Display Name, and Bundle Name in Info.plist using PlistBuddy..."
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" ios/Runner/Info.plist
if [ $? -ne 0 ]; then echo "❌ ERROR: Failed to set Bundle ID in Info.plist." && exit 1; fi

/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName TeamBuild Pro" ios/Runner/Info.plist
if [ $? -ne 0 ]; then echo "❌ ERROR: Failed to set CFBundleDisplayName in Info.plist." && exit 1; fi

/usr/libexec/PlistBuddy -c "Set :CFBundleName teambuildApp" ios/Runner/Info.plist
if [ $? -ne 0 ]; then echo "❌ ERROR: Failed to set CFBundleName in Info.plist." && exit 1; fi
echo "✅ Bundle ID, Display Name, and Bundle Name set in Info.plist."

# Step 5.2: Dynamically create Runner.entitlements for capabilities
echo "📝 Writing Runner.entitlements with Push Notifications and Background Modes capabilities..."
cat <<EOF > ios/Runner/Runner.entitlements
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>aps-environment</key>
  <string>$BUILD_MODE</string>
  <key>UIBackgroundModes</key>
  <array>
    <string>remote-notification</string>
  </array>
</dict>
</plist>
EOF
echo "✅ Runner.entitlements written with aps-environment = $BUILD_MODE and remote-notification."

# --- Step to set Base Configurations in project.pbxproj using Ruby script ---
echo "⚙️ Setting Base Configurations for Runner target in project.pbxproj using Ruby script..."
if [ ! -f scripts/set_xcconfig_base_configs.rb ]; then
  echo "❌ ERROR: scripts/set_xcconfig_base_configs.rb not found. Cannot proceed."
  exit 1
fi
ruby scripts/set_xcconfig_base_configs.rb ios/Runner.xcodeproj Runner
echo "✅ Base Configurations updated in project.pbxproj."

# Step 6: Restore Dart dependencies and CocoaPods
echo "📦 Running flutter pub get to fetch Dart packages..."
flutter pub get

# --- ENHANCED: Pod installation with better error handling ---
echo "📦 Running pod install with enhanced configuration..."
cd ios
# Clear pod cache first to prevent issues
pod cache clean --all || true
# Install with more specific flags to prevent issues
CI=true COCOAPODS_DISABLE_STATS=1 pod install --repo-update --clean-install
cd "$SRC_DIR"

# --- Append custom build settings to Debug.xcconfig and Release.xcconfig ---
echo "✏️ Appending custom build settings to Debug.xcconfig and Release.xcconfig..."

# --- ENHANCED: Add Flutter.framework specific settings ---
# Append to Debug.xcconfig
cat <<EOF >> ios/Flutter/Debug.xcconfig

// Custom settings appended by rebuild_ios_clean.sh for Debug
PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID
DEVELOPMENT_TEAM = $DEVELOPMENT_TEAM_ID
CODE_SIGN_IDENTITY = Apple Development
PROVISIONING_PROFILE_SPECIFIER =
IPHONEOS_DEPLOYMENT_TARGET = 13.0
SDKROOT = iphoneos
ARCHS = arm64
SWIFT_VERSION = 5.0
ENABLE_BITCODE = NO

// Enhanced settings to prevent Flutter.framework signing issues
CODE_SIGNING_ALLOWED = YES
CODE_SIGNING_REQUIRED = YES
STRIP_INSTALLED_PRODUCT = NO
SKIP_INSTALL = NO

// Debug-specific flags
DEBUG_INFORMATION_FORMAT = dwarf
VALID_ARCHS = arm64
ONLY_ACTIVE_ARCH = YES
ENABLE_TESTABILITY = YES
EOF
echo "✅ Enhanced settings appended to Debug.xcconfig."

# Append to Release.xcconfig
cat <<EOF >> ios/Flutter/Release.xcconfig

// Custom settings appended by rebuild_ios_clean.sh for Release
PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID
DEVELOPMENT_TEAM = $DEVELOPMENT_TEAM_ID
CODE_SIGN_IDENTITY = Apple Development
PROVISIONING_PROFILE_SPECIFIER =
IPHONEOS_DEPLOYMENT_TARGET = 13.0
SDKROOT = iphoneos
ARCHS = arm64
SWIFT_VERSION = 5.0
ENABLE_BITCODE = NO

// Enhanced settings to prevent Flutter.framework signing issues
CODE_SIGNING_ALLOWED = YES
CODE_SIGNING_REQUIRED = YES
STRIP_INSTALLED_PRODUCT = NO
SKIP_INSTALL = NO

// Release-specific settings
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
VALID_ARCHS = arm64
ONLY_ACTIVE_ARCH = NO
EOF
echo "✅ Enhanced settings appended to Release.xcconfig."

# Step 7: Configure Firebase using flutterfire_cli
echo "🔥 Configuring Firebase for iOS project 'teambuilder-plus-fe74d'..."
if [ ! -f scripts/GoogleService-Info.plist ]; then
  echo "⚠️ Warning: scripts/GoogleService-Info.plist not found. Firebase configuration might be incomplete."
  echo "   If you intend to use Firebase, please download it from Firebase console and place it in 'scripts/'."
else
  flutterfire configure \
    --project=teambuilder-plus-fe74d \
    --platforms=ios \
    --ios-out=ios/Runner/GoogleService-Info.plist \
    --yes
  echo "✅ Firebase configured. GoogleService-Info.plist should now be referenced in Xcode."

  # Validate GoogleService-Info.plist syntax
  echo "🔍 Validating GoogleService-Info.plist syntax..."
  plutil -lint ios/Runner/GoogleService-Info.plist || {
    echo "❌ ERROR: GoogleService-Info.plist is invalid or not found. Check Firebase configuration."
    exit 1
  }
  echo "✅ GoogleService-Info.plist syntax is valid."

  # Run pod install again after Firebase configuration
  echo "📦 Running pod install again after Firebase configuration..."
  cd ios
  CI=true COCOAPODS_DISABLE_STATS=1 pod install --repo-update
  cd "$SRC_DIR"
fi

# Step 8: Optional - Sync Manifest.lock
if [ -f ios/Podfile.lock ]; then
  mkdir -p ios/Pods
  cp ios/Podfile.lock ios/Pods/Manifest.lock
  echo "📦 Synced Podfile.lock → ios/Pods/Manifest.lock"
fi

# --- ENHANCED: Pre-build validation and codesigning preparation ---
echo "🔍 Performing pre-build validation..."

# Verify that automatic signing is properly configured
if grep -q "CODE_SIGN_STYLE = Automatic" ios/Runner.xcodeproj/project.pbxproj; then
  echo "✅ Automatic code signing is enabled in project."
else
  echo "❌ WARNING: Automatic code signing may not be properly enabled."
fi

# Check that development team is set
if grep -q "DEVELOPMENT_TEAM = $DEVELOPMENT_TEAM_ID" ios/Runner.xcodeproj/project.pbxproj; then
  echo "✅ Development team is set in project."
else
  echo "❌ WARNING: Development team may not be properly set."
fi

# --- CRITICAL: Alternative build approach to handle Flutter.framework issues ---
echo "🚀 Attempting build with enhanced error handling..."

# First, try a simulator build which is less likely to have signing issues
echo "📱 Attempting iOS Simulator build first (to validate project setup)..."
if flutter build ios --simulator; then
  echo "✅ iOS Simulator build successful - project configuration is valid."
else
  echo "⚠️ iOS Simulator build failed - there may be project configuration issues."
fi

# Now attempt the device build with better error reporting
echo "📱 Attempting iOS device build..."
if flutter build ios --verbose 2>&1 | tee build_output.log; then
  echo "✅ iOS device build successful!"
else
  echo "❌ iOS device build failed. Analyzing error..."
  
  # Check for specific Flutter.framework signing errors
  if grep -q "Failed to codesign.*Flutter\.framework" build_output.log; then
    echo "🔧 Detected Flutter.framework codesigning issue. Attempting fix..."
    
    # Try to manually fix Flutter.framework signing
    FLUTTER_FRAMEWORK_PATH="ios/.symlinks/flutter/ios/Flutter.framework"
    if [ -d "$FLUTTER_FRAMEWORK_PATH" ]; then
      echo "🔧 Attempting to manually sign Flutter.framework..."
      codesign --force --sign "Apple Development" --timestamp "$FLUTTER_FRAMEWORK_PATH" || true
      
      # Retry the build
      echo "🔄 Retrying iOS build after manual Flutter.framework signing..."
      flutter build ios --verbose
    fi
  fi
fi

# Clean up build log
rm -f build_output.log

# --- Final Verification Step ---
echo "🩺 Running flutter doctor to verify overall setup..."
flutter doctor

echo "✅ Enhanced rebuild process complete."

# Step 9: Open the project in Xcode
echo "🚀 Opening project in Xcode for final review..."
cd "$SRC_DIR"
open ios/Runner.xcworkspace

echo "✅ Rebuild complete with enhanced codesigning fixes. Bundle ID: $BUNDLE_ID"
echo ""
echo "🔍 If you still encounter Flutter.framework signing issues, try these manual steps in Xcode:"
echo "   1. Open ios/Runner.xcworkspace"
echo "   2. Select the Runner project → Runner target → Signing & Capabilities"
echo "   3. Verify 'Automatically manage signing' is checked"
echo "   4. Verify your Team is selected: $DEVELOPMENT_TEAM_ID"
echo "   5. Clean build folder (Product → Clean Build Folder)"
echo "   6. Try building again"
echo ""
echo "💡 Common causes of remaining issues:"
echo "   - iCloud sync conflicts (move project outside iCloud)"
echo "   - Multiple/expired certificates in keychain"
echo "   - Network issues preventing certificate/profile downloads"
echo "   - Xcode license agreement not accepted"

#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Define variables
SRC_DIR=~/tbpapp
BUNDLE_ID="com.scott.ultimatefix"
IOS_DIR="$SRC_DIR/ios"
BUILD_MODE="development"  # Set to 'production' for release builds
DEVELOPMENT_TEAM_ID="YXV25WMDS8" # Your Apple Development Team ID

# Log file for verbose output
LOG_FILE="$SRC_DIR/rebuild_log_$(date +%s).txt"
exec > >(tee "$LOG_FILE") 2>&1 # Redirect stdout and stderr to both console and log file

echo "📝 Detailed logging enabled. See $LOG_FILE for full output."

echo "📁 Starting clean iOS rebuild in: $SRC_DIR"

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


# Step 1: Quit Xcode and back up current ios/ directory
# 'killall -9 Xcode || true' attempts to kill Xcode, and '|| true' prevents script from exiting if Xcode isn't running.
killall -9 Xcode || true
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
echo "🧹 Cleaning Xcode DerivedData and Archives..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/Library/Developer/Xcode/Archives/* || true # Clear archives, allow failure if none exist
echo "✅ Xcode DerivedData and Archives cleared."

# --- NEW: Clean old provisioning profiles ---
echo "🧹 Cleaning old provisioning profiles..."
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/* || true # Use || true to prevent exit if directory doesn't exist
echo "✅ Old provisioning profiles cleared."
# --- END NEW ---

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
# 'sed -i ''' is used for in-place editing. The empty string after -i is required for macOS.
sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = .*/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;/g" ios/Runner.xcodeproj/project.pbxproj

# Explicitly enable Automatic Codesigning and set required signing properties
# This targets all build configurations (Debug, Release, Profile).
# Using separate sed commands for robustness.
for CONFIG_NAME in "Debug" "Release" "Profile"; do
  # Set CODE_SIGN_STYLE to Automatic (replace existing line if found)
  # This pattern correctly targets the line within the specific build configuration block.
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGN_STYLE = Manual;/CODE_SIGN_STYLE = Automatic;/g" ios/Runner.xcodeproj/project.pbxproj
  # Ensure CODE_SIGNING_REQUIRED is YES
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGNING_REQUIRED = NO;/CODE_SIGNING_REQUIRED = YES;/g" ios/Runner.xcodeproj/project.pbxproj
  # Set CODE_SIGN_IDENTITY to "Apple Development" (generic)
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGN_IDENTITY = \".*\";/CODE_SIGN_IDENTITY = \"Apple Development\";/g" ios/Runner.xcodeproj/project.pbxproj
  # Set CODE_SIGN_IDENTITY[sdk=iphoneos*] to "Apple Development" (SDK-specific)
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGN_IDENTITY\[sdk=iphoneos\*\] = \".*\";/CODE_SIGN_IDENTITY\[sdk=iphoneos\*\] = \"Apple Development\";/g" ios/Runner.xcodeproj/project.pbxproj
  # Clear PROVISIONING_PROFILE_SPECIFIER
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/PROVISIONING_PROFILE_SPECIFIER = \".*\";/PROVISIONING_PROFILE_SPECIFIER = \"\";/g" ios/Runner.xcodeproj/project.pbxproj
  # Clear PROVISIONING_PROFILE
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/PROVISIONING_PROFILE = \".*\";/PROVISIONING_PROFILE = \"\";/g" ios/Runner.xcodeproj/project.pbxproj

  # Ensure AppIcon and LaunchImage are correctly referenced
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/ASSETCATALOG_COMPILER_APPICON_NAME = \".*\";/ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/ASSETCATALOG_COMPILER_LAUNCHIMAGE_NAME = \".*\";/ASSETCATALOG_COMPILER_LAUNCHIMAGE_NAME = LaunchImage;/g" ios/Runner.xcodeproj/project.pbxproj

done
# Ensure DEVELOPMENT_TEAM is set at the project level
sed -i '' "s/DEVELOPMENT_TEAM = .*/DEVELOPMENT_TEAM = $DEVELOPMENT_TEAM_ID;/g" ios/Runner.xcodeproj/project.pbxproj


# Confirm Bundle ID patch success (and implicitly other settings)
if grep -q "$BUNDLE_ID" ios/Runner.xcodeproj/project.pbxproj; then
  echo "✅ Bundle ID successfully set in project.pbxproj"
else
  echo "❌ Bundle ID patch may have failed in project.pbxproj. Exiting."
  exit 1 # Exit if bundle ID is not set, as it's critical
fi
echo "✅ Automatic Codesigning settings updated in project.pbxproj."


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

# Removed direct copying of Debug.xcconfig and Release.xcconfig from scripts/
# These will be the default ones created by 'flutter create' and modified later.
echo "✅ Info.plist and Podfile copied. xcconfig files will be generated and appended."


# Step 5.1: Patch Info.plist with correct Bundle ID and Display Names
# This step is placed AFTER copying scripts/Info.plist to ensure custom values overwrite defaults.
echo "✏️ Setting Bundle ID, Display Name, and Bundle Name in Info.plist using PlistBuddy..."
# Using PlistBuddy for precise XML manipulation.
# Check exit status of each PlistBuddy command for explicit error handling.
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
# This is crucial for resolving the CocoaPods base configuration warning.
echo "⚙️ Setting Base Configurations for Runner target in project.pbxproj using Ruby script..."
if [ ! -f scripts/set_xcconfig_base_configs.rb ]; then
  echo "❌ ERROR: scripts/set_xcconfig_base_configs.rb not found. Cannot proceed."
  exit 1
fi
ruby scripts/set_xcconfig_base_configs.rb ios/Runner.xcodeproj Runner
echo "✅ Base Configurations updated in project.pbxproj."
# --- END Base Config Fix ---


# Step 6: Restore Dart dependencies and CocoaPods
echo "📦 Running flutter pub get to fetch Dart packages..."
flutter pub get

echo "📦 Running pod install --repo-update (non-interactive mode for CocoaPods)..."
cd ios
# Set CI=true and COCOAPODS_DISABLE_STATS=1 to prevent interactive prompts from CocoaPods.
CI=true COCOAPODS_DISABLE_STATS=1 pod install --repo-update
cd "$SRC_DIR"

# --- Append custom build settings to Debug.xcconfig and Release.xcconfig ---
# This step is crucial for layering your custom settings on top of CocoaPods' base config.
echo "✏️ Appending custom build settings to Debug.xcconfig and Release.xcconfig..."

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

// Debug-specific flags
DEBUG_INFORMATION_FORMAT = dwarf
VALID_ARCHS = arm64
ONLY_ACTIVE_ARCH = YES
ENABLE_TESTABILITY = YES
EOF
echo "✅ Custom settings appended to Debug.xcconfig."

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

// Optional but useful
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
VALID_ARCHS = arm64
ONLY_ACTIVE_ARCH = NO
EOF
echo "✅ Custom settings appended to Release.xcconfig."
# --- END Appending custom build settings ---


# Step 7: Configure Firebase using flutterfire_cli
echo "🔥 Configuring Firebase for iOS project 'teambuilder-plus-fe74d'..."
# Check if GoogleService-Info.plist exists in the scripts directory before proceeding.
if [ ! -f scripts/GoogleService-Info.plist ]; then
  echo "⚠️ Warning: scripts/GoogleService-Info.plist not found. Firebase configuration might be incomplete."
  echo "   If you intend to use Firebase, please download it from Firebase console and place it in 'scripts/'."
else
  # Reverting to interactive prompts for flutterfire configure as requested.
  # User will manually select "Build configuration" and "Debug".
  flutterfire configure \
    --project=teambuilder-plus-fe74d \
    --platforms=ios \
    --ios-out=ios/Runner/GoogleService-Info.plist \
    --yes # --yes confirms other prompts automatically
  echo "✅ Firebase configured. GoogleService-Info.plist should now be referenced in Xcode."

  # Validate GoogleService-Info.plist syntax
  echo "🔍 Validating GoogleService-Info.plist syntax..."
  plutil -lint ios/Runner/GoogleService-Info.plist || {
    echo "❌ ERROR: GoogleService-Info.plist is invalid or not found. Check Firebase configuration."
    exit 1
  }
  echo "✅ GoogleService-Info.plist syntax is valid."

  # Run pod install again after Firebase configuration, as it might update Firebase-related pods.
  echo "📦 Running pod install again after Firebase configuration (non-interactive)..."
  cd ios
  CI=true COCOAPODS_DISABLE_STATS=1 pod install --repo-update
  cd "$SRC_DIR"
fi


# Step 8: Optional - Sync Manifest.lock
# This step ensures Pods/Manifest.lock matches Podfile.lock, often handled by pod install.
if [ -f ios/Podfile.lock ]; then
  mkdir -p ios/Pods # Ensure Pods directory exists
  cp ios/Podfile.lock ios/Pods/Manifest.lock
  echo "📦 Synced Podfile.lock → ios/Pods/Manifest.lock"
fi


# --- Final Verification Step ---
echo "🩺 Running flutter doctor to verify overall setup..."
flutter doctor
echo "Attempting a clean iOS build to confirm project integrity (with codesigning)..."

# --- Attempt a standard flutter build ios ---
# This relies on Xcode's automatic signing to work.
flutter build ios
# --- END NEW ---

echo "✅ Initial iOS build attempt complete. Please review the output above for any warnings or errors."
# --- END Final Verification Step ---


# Step 9: Open the project in Xcode
echo "🚀 Opening project in Xcode. Please review 'Runner.xcworkspace' for final configuration."
cd "$SRC_DIR"
open ios/Runner.xcworkspace

echo "✅ Rebuild complete. Bundle ID: $BUNDLE_ID"

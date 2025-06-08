#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Enable detailed logging
LOG_FILE="rebuild_log_$(date +%s).txt"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "📝 Detailed logging enabled. See $LOG_FILE for full output."

# Define variables
SRC_DIR=~/Desktop/tbp
BUNDLE_ID="com.scott.teambuildApp"
IOS_DIR="$SRC_DIR/ios"
BUILD_MODE="development"  # Set to 'production' for release builds
DEVELOPMENT_TEAM_ID="YXV25WMDS8" # Your Apple Development Team ID

echo "📁 Starting clean iOS rebuild in: $SRC_DIR"

# --- Pre-requisite Checks ---
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

# Check for flutterfire_cli
if ! dart pub global list | grep -q 'flutterfire_cli'; then
  echo "⚠️ flutterfire_cli not found. Installing it now..."
  dart pub global activate flutterfire_cli
  if ! dart pub global list | grep -q 'flutterfire_cli'; then
    echo "❌ ERROR: Failed to install flutterfire_cli. Please check your Dart/Flutter setup."
    exit 1
  fi
  echo "✅ flutterfire_cli installed."
else
  echo "✅ flutterfire_cli is installed."
fi

# Check for xcodeproj gem
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

# Check if the 'scripts' directory exists
if [ ! -d "$SRC_DIR/scripts" ]; then
  echo "❌ ERROR: 'scripts' directory not found at $SRC_DIR/scripts."
  exit 1
fi
echo "✅ 'scripts' directory found."
# --- END Pre-requisite Checks ---


# --- Cleanup Phase ---
function unsign_frameworks() {
  local dir=$1
  find "$dir" -type d -name "*.framework" | while read -r framework; do
    if ! codesign --remove-signature "$framework"; then
      echo "❌ Failed to unsign $framework"
      return 1
    fi
    echo "✅ Unsigned $framework"
  done
}

echo "🧹 Starting aggressive cleanup..."
killall -9 Xcode || true

# Back up existing ios directory
BACKUP_NAME="ios_backup_$(date +%s)"
if [ -d "$IOS_DIR" ]; then
  echo "🧼 Backing up ios/ → $BACKUP_NAME"
  mv "$IOS_DIR" "$SRC_DIR/$BACKUP_NAME"
else
  echo "No existing ios/ directory to back up."
fi

# Deep clean Flutter and Xcode artifacts
echo "🧹 Running deep clean..."
flutter clean
rm -rf ios/Pods
rm -rf ios/.symlinks
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/Flutter.podspec
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/Library/Developer/Xcode/Archives/*
rm -rf ~/Library/Caches/CocoaPods

# Clean provisioning profiles more aggressively
echo "🧹 Cleaning provisioning profiles..."
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/*
xcrun simctl shutdown all
xcrun simctl erase all
echo "✅ Cleanup complete."
# --- END Cleanup Phase ---


# --- Project Recreation ---
echo "✨ Recreating Flutter iOS project structure..."
flutter create --org com.scott --platforms=ios .

# Copy essential files
echo "🔄 Copying custom files from scripts directory..."
cp scripts/AppDelegate.swift ios/Runner/AppDelegate.swift
cp scripts/Info.plist ios/Runner/Info.plist
cp scripts/Podfile ios/Podfile

# Patch project settings
echo "✏️ Configuring project settings..."
for CONFIG_NAME in "Debug" "Release" "Profile"; do
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGN_STYLE = Manual;/CODE_SIGN_STYLE = Automatic;/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGNING_REQUIRED = NO;/CODE_SIGNING_REQUIRED = YES;/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGN_IDENTITY = \".*\";/CODE_SIGN_IDENTITY = \"Apple Development\";/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGN_IDENTITY\[sdk=iphoneos\*\] = \".*\";/CODE_SIGN_IDENTITY\[sdk=iphoneos\*\] = \"Apple Development\";/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/PROVISIONING_PROFILE_SPECIFIER = \".*\";/PROVISIONING_PROFILE_SPECIFIER = \"\";/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/PROVISIONING_PROFILE = \".*\";/PROVISIONING_PROFILE = \"\";/g" ios/Runner.xcodeproj/project.pbxproj
done

# Set bundle ID and team ID
sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = .*/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;/g" ios/Runner.xcodeproj/project.pbxproj
sed -i '' "s/DEVELOPMENT_TEAM = .*/DEVELOPMENT_TEAM = $DEVELOPMENT_TEAM_ID;/g" ios/Runner.xcodeproj/project.pbxproj

# Update Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" ios/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName TeamBuild Pro" ios/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleName teambuildApp" ios/Runner/Info.plist

# Create entitlements file
echo "📝 Writing Runner.entitlements..."
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

# Set base configurations using Ruby script
if [ -f scripts/set_xcconfig_base_configs.rb ]; then
  echo "⚙️ Setting Base Configurations..."
  ruby scripts/set_xcconfig_base_configs.rb ios/Runner.xcodeproj Runner
fi
# --- END Project Recreation ---


# --- Dependency Installation ---
echo "📦 Installing dependencies..."
flutter pub get

echo "📦 Running pod install..."
cd ios
CI=true COCOAPODS_DISABLE_STATS=1 pod install --repo-update
cd "$SRC_DIR"

# Append custom build settings
echo "✏️ Appending custom build settings..."
for CONFIG in Debug Release; do
  cat <<EOF >> ios/Flutter/${CONFIG}.xcconfig

// Custom settings appended by rebuild_ios_clean.sh
PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID
DEVELOPMENT_TEAM = $DEVELOPMENT_TEAM_ID
CODE_SIGN_IDENTITY = Apple Development
PROVISIONING_PROFILE_SPECIFIER =
IPHONEOS_DEPLOYMENT_TARGET = 13.0
SDKROOT = iphoneos
ARCHS = arm64
SWIFT_VERSION = 5.0
ENABLE_BITCODE = NO
EOF
done
# --- END Dependency Installation ---


# --- Firebase Configuration ---
if [ -f scripts/GoogleService-Info.plist ]; then
  echo "🔥 Configuring Firebase..."
  flutterfire configure \
    --project=teambuilder-plus-fe74d \
    --platforms=ios \
    --ios-out=ios/Runner/GoogleService-Info.plist \
    --yes
  
  plutil -lint ios/Runner/GoogleService-Info.plist || {
    echo "❌ ERROR: GoogleService-Info.plist is invalid"
    exit 1
  }
  
  echo "📦 Running pod install again after Firebase..."
  cd ios
  CI=true COCOAPODS_DISABLE_STATS=1 pod install --repo-update
  cd "$SRC_DIR"
fi
# --- END Firebase Configuration ---


# --- Codesign Preparation ---
echo "🔐 Preparing for codesigning..."
unsign_frameworks ios/Flutter
unsign_frameworks ios/Pods

echo "🔑 Verifying keychain status..."
security list-keychains
security find-identity -p codesigning -v

echo "🔍 Verifying Flutter framework integrity..."
find ios/Flutter -name "Flutter.framework" -exec lipo -info {}/Flutter \;
# --- END Codesign Preparation ---


# --- Build Phase ---
echo "🏗 Attempting build with special codesign handling..."
flutter build ios --verbose --no-codesign

echo "🔐 Manually signing Flutter artifacts..."
find build/ios/iphoneos/Runner.app/Frameworks -type d -name "*.framework" -exec codesign --force --sign - --timestamp=none {} \;
codesign --force --sign - --timestamp=none --entitlements ios/Runner/Runner.entitlements build/ios/iphoneos/Runner.app

echo "✅ Build process completed. Verifying..."
flutter doctor
# --- END Build Phase ---


# --- Final Steps ---
echo "🚀 Opening project in Xcode..."
open ios/Runner.xcworkspace

echo "✅ Rebuild complete. Bundle ID: $BUNDLE_ID"
echo "📝 Full logs available at: $LOG_FILE"

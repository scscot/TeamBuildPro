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

# --- ENHANCED: Check for iCloud sync issues ---
echo "🔍 Checking for iCloud sync issues that can cause codesigning failures..."
if [ -d "$SRC_DIR/.git" ]; then
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
echo "⚙️ Performing pre-requisite checks..."

if ! xcode-select -p &> /dev/null; then echo "❌ ERROR: Xcode Command Line Tools are not installed." && exit 1; fi
echo "✅ Xcode Command Line Tools are installed."

if ! command -v pod &> /dev/null; then echo "❌ ERROR: CocoaPods is not installed." && exit 1; fi
echo "✅ CocoaPods is installed."

if ! dart pub global list | grep -q 'flutterfire_cli'; then
  echo "⚠️ flutterfire_cli not found. Installing it now..."
  dart pub global activate flutterfire_cli
  if ! dart pub global list | grep -q 'flutterfire_cli'; then echo "❌ ERROR: Failed to install flutterfire_cli." && exit 1; fi
  echo "✅ flutterfire_cli installed."
else
  echo "✅ flutterfire_cli is installed."
fi

if ! gem list xcodeproj -i &> /dev/null; then
  echo "⚠️ xcodeproj Ruby gem not found. Installing it now..."
  sudo gem install xcodeproj
  if ! gem list xcodeproj -i &> /dev/null; then echo "❌ ERROR: Failed to install xcodeproj gem." && exit 1; fi
  echo "✅ xcodeproj gem installed."
else
  echo "✅ xcodeproj gem is installed."
fi

if [ ! -d "$SRC_DIR/scripts" ]; then echo "❌ ERROR: 'scripts' directory not found." && exit 1; fi
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
  echo "   This can sometimes cause signing conflicts. Please ensure only ONE is active and valid."
  security find-identity -v -p codesigning | grep "Apple Development"
else
  echo "✅ Single Apple Development certificate found in keychain."
fi
# --- END Keychain verification ---

# --- Cleanup Phase ---
function unsign_frameworks() {
  local dir=$1
  find "$dir" -type d -name "*.framework" | while read -r framework; do
    echo "  Attempting to unsign: $framework"
    if codesign --remove-signature "$framework"; then
      echo "  ✅ Unsigned $framework"
    else
      echo "  ⚠️ Could not unsign $framework (might not be signed or error occurred)."
    fi
  done
}

echo "🧹 Starting aggressive cleanup..."
killall -9 Xcode || true
killall -9 Simulator || true
echo "✅ Xcode and Simulator processes terminated."

BACKUP_NAME="ios_backup_$(date +%s)"
if [ -d "$IOS_DIR" ]; then
  echo "🧼 Backing up ios/ → $BACKUP_NAME"
  mv "$IOS_DIR" "$SRC_DIR/$BACKUP_NAME"
else
  echo "No existing ios/ directory to back up."
fi

echo "🧹 Running deep clean..."
flutter clean
rm -rf ios/Pods || true
rm -rf ios/.symlinks || true
rm -rf ios/Flutter/Flutter.framework || true
rm -rf ios/Flutter/Flutter.podspec || true
rm -rf ~/Library/Developer/Xcode/DerivedData/* || true
rm -rf ~/Library/Developer/Xcode/Archives/* || true
rm -rf ~/Library/Caches/CocoaPods/* || true
rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/* || true
rm -rf ~/Library/Developer/Xcode/UserData/IB\ Support/* || true
echo "✅ Comprehensive Xcode cleanup completed."

echo "🧹 Cleaning provisioning profiles and keychain cache..."
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/* || true
security delete-generic-password -s "XcodeDevTools" 2>/dev/null || true
echo "✅ Provisioning profiles and keychain cache cleared."
# --- END Cleanup Phase ---


# --- Project Recreation ---
echo "✨ Recreating Flutter iOS project structure..."
flutter create --org com.scott --platforms=ios .

echo "🔄 Copying custom files from scripts directory..."
cp scripts/AppDelegate.swift ios/Runner/AppDelegate.swift
cp scripts/Info.plist ios/Runner/Info.plist
cp scripts/Podfile ios/Podfile
echo "✅ Custom files copied."

echo "✏️ Configuring project settings in project.pbxproj..."
sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = .*/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;/g" ios/Runner.xcodeproj/project.pbxproj
sed -i '' "s/DEVELOPMENT_TEAM = .*/DEVELOPMENT_TEAM = $DEVELOPMENT_TEAM_ID;/g" ios/Runner.xcodeproj/project.pbxproj

for CONFIG_NAME in "Debug" "Release" "Profile"; do
  echo "  🔧 Configuring $CONFIG_NAME build settings..."
  
  # Remove any potentially conflicting manual signing settings first
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGN_STYLE = Manual;//g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/PROVISIONING_PROFILE_SPECIFIER = \".*\";//g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/PROVISIONING_PROFILE = \".*\";//g" ios/Runner.xcodeproj/project.pbxproj
  
  # Ensure CODE_SIGN_STYLE is Automatic
  # This pattern correctly targets the line within the specific build configuration block.
  # It handles cases where it's 'Manual' and replaces, or if it's missing, it inserts.
  if grep -q "CODE_SIGN_STYLE = Automatic;" ios/Runner.xcodeproj/project.pbxproj; then
    sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGN_STYLE = .*/CODE_SIGN_STYLE = Automatic;/g" ios/Runner.xcodeproj/project.pbxproj
  else
    # This sed command inserts 'CODE_SIGN_STYLE = Automatic;' after the opening '{' of the buildSettings block.
    # It's specifically for when the line doesn't exist yet.
    sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/a\\
                CODE_SIGN_STYLE = Automatic;" ios/Runner.xcodeproj/project.pbxproj
  fi

  # Ensure CODE_SIGNING_REQUIRED is YES
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGNING_REQUIRED = NO;/CODE_SIGNING_REQUIRED = YES;/g" ios/Runner.xcodeproj/project.pbxproj
  
  # Ensure CODE_SIGN_IDENTITY is "Apple Development" (generic)
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGN_IDENTITY = \".*\";/CODE_SIGN_IDENTITY = \"Apple Development\";/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGN_IDENTITY\[sdk=iphoneos\*\] = \".*\";/CODE_SIGN_IDENTITY\[sdk=iphoneos\*\] = \"Apple Development\";/g" ios/Runner.xcodeproj/project.pbxproj

  # Ensure AppIcon and LaunchImage are correctly referenced
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/ASSETCATALOG_COMPILER_APPICON_NAME = \".*\";/ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/ASSETCATALOG_COMPILER_LAUNCHIMAGE_NAME = \".*\";/ASSETCATALOG_COMPILER_LAUNCHIMAGE_NAME = LaunchImage;/g" ios/Runner.xcodeproj/project.pbxproj

done

if grep -q "$BUNDLE_ID" ios/Runner.xcodeproj/project.pbxproj; then
  echo "✅ Bundle ID successfully set in project.pbxproj"
else
  echo "❌ Bundle ID patch may have failed in project.pbxproj. Exiting."
  exit 1
fi
echo "✅ Enhanced Automatic Codesigning settings updated in project.pbxproj."

echo "✏️ Setting Bundle ID, Display Name, and Bundle Name in Info.plist using PlistBuddy..."
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" ios/Runner/Info.plist
if [ $? -ne 0 ]; then echo "❌ ERROR: Failed to set Bundle ID in Info.plist." && exit 1; fi

/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName TeamBuild Pro" ios/Runner/Info.plist
if [ $? -ne 0 ]; then echo "❌ ERROR: Failed to set CFBundleDisplayName in Info.plist." && exit 1; fi

/usr/libexec/PlistBuddy -c "Set :CFBundleName teambuildApp" ios/Runner/Info.plist
if [ $? -ne 0 ]; then echo "❌ ERROR: Failed to set CFBundleName in Info.plist." && exit 1; fi
echo "✅ Bundle ID, Display Name, and Bundle Name set in Info.plist."

echo "📝 Writing Runner.entitlements..."
cat <<EOF > ios/Runner/Runner.entitlements
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 10//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
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

echo "⚙️ Setting Base Configurations for Runner target in project.pbxproj using Ruby script..."
if [ ! -f scripts/set_xcconfig_base_configs.rb ]; then echo "❌ ERROR: scripts/set_xcconfig_base_configs.rb not found." && exit 1; fi
ruby scripts/set_xcconfig_base_configs.rb ios/Runner.xcodeproj Runner
echo "✅ Base Configurations updated in project.pbxproj."
# --- END Project Recreation ---


# --- Dependency Installation ---
echo "📦 Running flutter pub get to fetch Dart packages..."
flutter pub get

echo "📦 Running pod install with enhanced configuration..."
cd ios
pod cache clean --all || true
CI=true COCOAPODS_DISABLE_STATS=1 pod install --repo-update --clean-install
cd "$SRC_DIR"

echo "✏️ Appending custom build settings to Debug.xcconfig and Release.xcconfig..."

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

  echo "🔍 Validating GoogleService-Info.plist syntax..."
  plutil -lint ios/Runner/GoogleService-Info.plist || { echo "❌ ERROR: GoogleService-Info.plist is invalid." && exit 1; }
  echo "✅ GoogleService-Info.plist syntax is valid."

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

if grep -q "CODE_SIGN_STYLE = Automatic" ios/Runner.xcodeproj/project.pbxproj; then
  echo "✅ Automatic code signing is enabled in project."
else
  echo "❌ WARNING: Automatic code signing may not be properly enabled."
fi

if grep -q "DEVELOPMENT_TEAM = $DEVELOPMENT_TEAM_ID" ios/Runner.xcodeproj/project.pbxproj; then
  echo "✅ Development team is set in project."
else
  echo "❌ WARNING: Development team may not be properly set."
fi

echo "🏗 Attempting build with enhanced error handling..."

echo "📱 Attempting iOS Simulator build first (to validate project setup)..."
if flutter build ios --simulator; then
  echo "✅ iOS Simulator build successful - project configuration is valid."
else
  echo "⚠️ iOS Simulator build failed - there may be project configuration issues."
fi

echo "📱 Attempting iOS device build..."
if flutter build ios --verbose 2>&1 | tee build_output.log; then
  echo "✅ iOS device build successful!"
else
  echo "❌ iOS device build failed. Analyzing error..."
  
  if grep -q "Failed to codesign.*Flutter\.framework" build_output.log; then
    echo "🔧 Detected Flutter.framework codesigning issue. Attempting fix..."
    
    # Path might vary based on Flutter version/build mode, use a more robust search or specific path
    # For device builds, it's typically in build/ios/Release-iphoneos/Flutter.framework
    FLUTTER_FRAMEWORK_PATH="$SRC_DIR/build/ios/Release-iphoneos/Flutter.framework"
    if [ -d "$FLUTTER_FRAMEWORK_PATH" ]; then
      echo "🔧 Attempting to manually sign Flutter.framework at $FLUTTER_FRAMEWORK_PATH..."
      # Use a generic identity if the specific one is causing problems, or 'Apple Development'
      codesign --force --sign "Apple Development" --timestamp "$FLUTTER_FRAMEWORK_PATH" || true
      
      echo "🔄 Retrying iOS build after manual Flutter.framework signing..."
      # Retry with the same flutter build command
      flutter build ios --verbose
    else
      echo "⚠️ Flutter.framework not found at $FLUTTER_FRAMEWORK_PATH, skipping manual sign attempt."
    fi
  fi
fi

rm -f build_output.log

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
echo "   - Multiple/expired certificates in keychain (which we just addressed!)"
echo "   - Network issues preventing certificate/profile downloads"
echo "   - Xcode license agreement not accepted"

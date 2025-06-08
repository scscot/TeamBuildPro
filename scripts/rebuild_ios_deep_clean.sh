#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Define variables
SRC_DIR=~/tbpapp # Updated path
BUNDLE_ID="com.scott.ultimatefix"
IOS_DIR="$SRC_DIR/ios"
BUILD_MODE="development"  # Set to 'production' for release builds
DEVELOPMENT_TEAM_ID="YXV25WMDS8" # Your Apple Development Team ID
TARGET_IOS_VERSION="13.0" # Desired minimum iOS deployment target

# --- IMPORTANT: CLOUD SYNC WARNING ---
echo ""
echo "#########################################################################"
echo "### CRITICAL WARNING: PROJECT LOCATION AND EXTENDED ATTRIBUTES      ###"
echo "#########################################################################"
echo "If your project directory ($SRC_DIR) was located in a cloud-synced folder "
echo "(e.g., iCloud Drive's Desktop/Documents, Google Drive, Dropbox), "
echo "this is often the root cause of 'resource fork' and codesigning issues."
echo ""
echo "ACTION REQUIRED BEFORE PROCEEDING:"
echo "1.   Ensure this script's SRC_DIR variable points to a LOCAL, NON-SYNCED folder."
echo "     (It is currently set to: $SRC_DIR)"
echo "2.   Open Terminal and run: sudo xattr -cr \"$SRC_DIR\""
echo "     (Enter your password when prompted. Ensure no 'Permission denied' errors appear.)"
echo "3.   THEN, run this script again."
echo "#########################################################################"
echo ""
sleep 2 # Pause briefly

# Determine FLUTTER_ROOT dynamically if not already set
# This ensures the script itself knows the correct path for setup.
# The user's flutter installation is typically in ~/flutter
if [ -z "$FLUTTER_ROOT" ]; then
  FLUTTER_ROOT=$(dirname $(dirname $(command -v flutter)))
  if [ ! -d "$FLUTTER_ROOT/packages/flutter_tools/bin" ]; then
    echo "❌ ERROR: Could not automatically determine FLUTTER_ROOT."
    echo "         Please set FLUTTER_ROOT environment variable to your Flutter SDK path (e.g., /Users/sscott/flutter)."
    exit 1
  fi
fi

# Log file for verbose output
LOG_FILE="$SRC_DIR/rebuild_log_$(date +%s).txt"
exec > >(tee "$LOG_FILE") 2>&1 # Redirect stdout and stderr to both console and log file

echo "📝 Detailed logging enabled. See $LOG_FILE for full output."
echo "📁 Starting clean iOS rebuild in: $SRC_DIR"

# --- Pre-requisite Checks ---
echo "⚙️ Performing pre-requisite checks..."

if ! xcode-select -p &> /dev/null; then
    echo "❌ ERROR: Xcode Command Line Tools are not installed. Please install them by running: xcode-select --install"
    exit 1
fi
echo "✅ Xcode Command Line Tools are installed."

if ! command -v pod &> /dev/null; then
    echo "❌ ERROR: CocoaPods is not installed. Please install it by running: sudo gem install cocoapods"
    exit 1
fi
echo "✅ CocoaPods is installed."

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

if [ ! -d "$SRC_DIR/scripts" ]; then
  echo "❌ ERROR: 'scripts' directory not found at $SRC_DIR/scripts. Please ensure it exists and contains necessary config files."
  exit 1
fi
echo "✅ 'scripts' directory found."
# --- END Pre-requisite Checks ---


# Step 1: Aggressive Cleanup
echo "🧹 Starting aggressive cleanup..."

# Terminate Xcode and Simulator processes
echo "🧹 Terminating Xcode and Simulator processes..."
killall -9 Xcode || true
killall -9 "Simulator" || true
echo "✅ Xcode and Simulator processes terminated."

# Back up current ios/ directory
BACKUP_NAME="ios_backup_$(date +%s)"
echo "🧼 Backing up ios/ → $BACKUP_NAME"
if [ -d "$IOS_DIR" ]; then
  mv "$IOS_DIR" "$SRC_DIR/$BACKUP_NAME"
else
  echo "No existing ios/ directory to back up."
fi

# Clean Flutter project
cd "$SRC_DIR"
echo "🧹 Running flutter clean..."
flutter clean

# Deep clean Xcode caches and DerivedData
echo "🧹 Cleaning Xcode DerivedData, Archives, and ModuleCache..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/Library/Developer/Xcode/Archives/* || true
rm -rf ~/Library/Caches/com.apple.dt.Xcode/* || true # Xcode's internal caches
rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/* || true # Device Support files, can get corrupted
rm -rf ~/Library/Developer/Xcode/UserData/IB\ Support/* || true # Autosave information
echo "✅ Comprehensive Xcode cleanup completed."

# Clean old provisioning profiles
echo "🧹 Cleaning provisioning profiles and keychain cache..."
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/* || true
security delete-generic-password -s "XcodeDevTools" 2>/dev/null || true
echo "✅ Provisioning profiles and keychain cache cleared."

# Clean Flutter's cached engine artifacts
echo "🧹 Cleaning Flutter's cached engine artifacts..."
flutter precache --ios --force
echo "✅ Flutter engine artifacts precached/cleaned."

# Step 2: Recreate ios/ project structure and restore essential files
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


# Step 3: Set Bundle Identifier and Enable Automatic Codesigning in project.pbxproj
echo "✏️ Configuring project settings in project.pbxproj..."
sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = .*/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;/g" ios/Runner.xcodeproj/project.pbxproj

for CONFIG_NAME in "Debug" "Release" "Profile"; do
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGN_STYLE = Manual;/CODE_SIGN_STYLE = Automatic;/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGNING_REQUIRED = NO;/CODE_SIGNING_REQUIRED = YES;/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGN_IDENTITY = \".*\";/CODE_SIGN_IDENTITY = \"Apple Development\";/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGN_IDENTITY\[sdk=iphoneos\*\] = \".*\";/CODE_SIGN_IDENTITY\[sdk=iphoneos\*\] = \"Apple Development\";/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/PROVISIONING_PROFILE_SPECIFIER = \".*\";/PROVISIONING_PROFILE_SPECIFIER = \"\";/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/PROVISIONING_PROFILE = \".*\";/PROVISIONING_PROFILE = \"\";/g" ios/Runner.xcodeproj/project.pbxproj

  # Set specific build settings for frameworks (important for codesigning)
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/ENABLE_BITCODE = YES;/ENABLE_BITCODE = NO;/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/VALID_ARCHS = .*/VALID_ARCHS = arm64 arm64e x86_64;/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/SKIP_INSTALL = YES;/SKIP_INSTALL = NO;/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/STRIP_INSTALLED_PRODUCT = YES;/STRIP_INSTALLED_PRODUCT = NO;/g" ios/Runner.xcodeproj/project.pbxproj
done

# NEW: Ruby script to set IPHONEOS_DEPLOYMENT_TARGET for Runner target in project.pbxproj
echo "⚙️ Setting IPHONEOS_DEPLOYMENT_TARGET for Runner target in project.pbxproj to $TARGET_IOS_VERSION using Ruby script..."
ruby -e "
  require 'xcodeproj'
  require 'rubygems'

  project_path = 'ios/Runner.xcodeproj'
  target_deployment_target = ARGV[0] # Get target version from argument

  unless File.exist?(project_path)
    puts 'Error: Runner.xcodeproj not found. Skipping deployment target update for Runner.'
    exit
  end

  project = Xcodeproj::Project.open(project_path)
  project.targets.each do |target|
    if target.name == 'Runner'
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = target_deployment_target
        puts \"  Set Runner [\#{config.name}] IPHONEOS_DEPLOYMENT_TARGET to \#{target_deployment_target}\"
      end
    end
  end
  project.save
  puts \"✅ Runner.xcodeproj deployment targets updated.\"
" "$TARGET_IOS_VERSION" # Pass TARGET_IOS_VERSION as argument
echo "✅ IPHONEOS_DEPLOYMENT_TARGET for Runner target updated in project.pbxproj. Verified."


# Ensure DEVELOPMENT_TEAM is set at the project level
sed -i '' "s/DEVELOPMENT_TEAM = .*/DEVELOPMENT_TEAM = $DEVELOPMENT_TEAM_ID;/g" ios/Runner.xcodeproj/project.pbxproj

# Explicitly set FLUTTER_ROOT in project.pbxproj build settings
echo "  Setting FLUTTER_ROOT in project.pbxproj build settings..."
for CONFIG_NAME in "Debug" "Release" "Profile"; do
  if ! grep -q "FLUTTER_ROOT = \"$FLUTTER_ROOT\";" ios/Runner.xcodeproj/project.pbxproj; then
    # Insert FLUTTER_ROOT if it's not already present in the build settings block
    sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/a\\
                FLUTTER_ROOT = \"$FLUTTER_ROOT\";" ios/Runner.xcodeproj/project.pbxproj
  else
    # Update FLUTTER_ROOT if it's already there but potentially incorrect
    sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s|FLUTTER_ROOT = .*|FLUTTER_ROOT = \"$FLUTTER_ROOT\";|g" ios/Runner.xcodeproj/project.pbxproj
  fi
done

if grep -q "$BUNDLE_ID" ios/Runner.xcodeproj/project.pbxproj; then
  echo "✅ Bundle ID successfully set in project.pbxproj"
else
  echo "❌ Bundle ID patch may have failed in project.pbxproj. Exiting."
  exit 1
fi
echo "✅ Automatic Codesigning settings updated in project.pbxproj."


# Step 4: Restore custom Info.plist and Podfile from 'scripts' directory
echo "🔄 Copying custom Info.plist and Podfile..."
if [ ! -f scripts/Info.plist ]; then
  echo "❌ ERROR: scripts/Info.plist not found. Cannot proceed without it."
  exit 1
fi
cp scripts/Info.plist ios/Runner/Info.plist

if [ ! -f scripts/Podfile ]; then
  echo "❌ ERROR: scripts/Podfile not found. Cannot proceed without it."
  exit 1
fi
cp scripts/Podfile ios/Podfile

echo "✅ Info.plist and Podfile copied. xcconfig files will be generated and appended."


# Step 4.1: Patch Info.plist with correct Bundle ID and Display Names
echo "✏️ Setting Bundle ID, Display Name, and Bundle Name in Info.plist using PlistBuddy..."
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" ios/Runner/Info.plist
if [ $? -ne 0 ]; then echo "❌ ERROR: Failed to set Bundle ID in Info.plist." && exit 1; fi

/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName TeamBuild Pro" ios/Runner/Info.plist
if [ $? -ne 0 ]; then echo "❌ ERROR: Failed to set CFBundleDisplayName in Info.plist." && exit 1; fi

/usr/libexec/PlistBuddy -c "Set :CFBundleName teambuildApp" ios/Runner/Info.plist
if [ $? -ne 0 ]; then echo "❌ ERROR: Failed to set CFBundleName in Info.plist." && exit 1; fi
echo "✅ Bundle ID, Display Name, and Bundle Name set in Info.plist. Verified."


# Step 4.2: Dynamically create Runner.entitlements for capabilities
echo "📝 Writing Runner.entitlements with Push Notifications and Background Modes capabilities..."
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
 echo "✅ Runner.entitlements written with aps-environment = $BUILD_MODE and remote-notification. Verified."


# Step to set Base Configurations in project.pbxproj using Ruby script
echo "⚙️ Setting Base Configurations for Runner target in project.pbxproj using Ruby script..."
if [ ! -f scripts/set_xcconfig_base_configs.rb ]; then
  echo "❌ ERROR: scripts/set_xcconfig_base_configs.rb not found. Cannot proceed."
  exit 1
fi
# Pass FLUTTER_ROOT as an argument to the Ruby script
ruby scripts/set_xcconfig_base_configs.rb ios/Runner.xcodeproj Runner "$FLUTTER_ROOT"
echo "✅ Base Configurations updated in project.pbxproj. Verified."


# Step 5: Restore Dart dependencies and CocoaPods
echo "📦 Running flutter pub get to fetch Dart packages..."
flutter pub get

echo "📦 Running pod install --repo-update (non-interactive mode for CocoaPods)..."
cd ios
CI=true COCOAPODS_DISABLE_STATS=1 pod install --repo-update
cd "$SRC_DIR"

# NEW: Ruby script to set iOS deployment target for all Pods to 13.0
echo "⚙️ Setting iOS deployment target for all Pods to 13.0..."
ruby -e "
  require 'xcodeproj'
  require 'rubygems' # Ensure rubygems is loaded for Gem::Version

  project_path = 'ios/Pods/Pods.xcodeproj'
  target_deployment_target = '$TARGET_IOS_VERSION' # Use variable from shell script

  unless File.exist?(project_path)
    puts 'Error: Pods.xcodeproj not found. Skipping deployment target update for Pods.'
    exit
  end

  project = Xcodeproj::Project.open(project_path)
  project.targets.each do |target|
    target.build_configurations.each do |config|
      current_deployment_target = config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
      # Check if current_deployment_target is nil or less than the target_deployment_target
      if current_deployment_target.nil? || Gem::Version.new(current_deployment_target) < Gem::Version.new(target_deployment_target)
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = target_deployment_target
        puts \"  Set \#{target.name} [\#{config.name}] IPHONEOS_DEPLOYMENT_TARGET to \#{target_deployment_target}\"
      else
        puts \"  Skipping \#{target.name} [\#{config.name}]: IPHONEOS_DEPLOYMENT_TARGET is already \#{current_deployment_target} (>= \#{target_deployment_target})\"
      end
    end
  end
  project.save
  puts \"✅ Pods.xcodeproj deployment targets updated.\"
"
echo "✅ iOS deployment target for Pods updated. Verified."


# Append custom build settings to Debug.xcconfig and Release.xcconfig
echo "✏️ Appending custom build settings to Debug.xcconfig and Release.xcconfig..."

cat <<EOF >> ios/Flutter/Debug.xcconfig

// Custom settings appended by rebuild_ios_clean.sh for Debug
PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID
DEVELOPMENT_TEAM = $DEVELOPMENT_TEAM_ID
CODE_SIGN_IDENTITY = Apple Development
PROVISIONING_PROFILE_SPECIFIER =
IPHONEOS_DEPLOYMENT_TARGET = $TARGET_IOS_VERSION
SDKROOT = iphoneos
ARCHS = arm64 arm64e x86_64 # Ensure universal binaries for simulator/device
SWIFT_VERSION = 5.0
ENABLE_BITCODE = NO
DEBUG_INFORMATION_FORMAT = dwarf
VALID_ARCHS = arm64 arm64e x86_64
ONLY_ACTIVE_ARCH = NO # Build for all architectures for simulator/device
ENABLE_TESTABILITY = YES
STRIP_INSTALLED_PRODUCT = NO
SKIP_INSTALL = NO
FLUTTER_ROOT = $FLUTTER_ROOT # Explicitly set FLUTTER_ROOT in xcconfig
EOF
echo "✅ Custom settings appended to Debug.xcconfig. Verified."

cat <<EOF >> ios/Flutter/Release.xcconfig

// Custom settings appended by rebuild_ios_clean.sh for Release
PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID
DEVELOPMENT_TEAM = $DEVELOPMENT_TEAM_ID
CODE_SIGN_IDENTITY = Apple Development
PROVISIONING_PROFILE_SPECIFIER =
IPHONEOS_DEPLOYMENT_TARGET = $TARGET_IOS_VERSION
SDKROOT = iphoneos
ARCHS = arm64 arm64e x86_64 # Ensure universal binaries for simulator/device
SWIFT_VERSION = 5.0
ENABLE_BITCODE = NO
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
VALID_ARCHS = arm64 arm64e x86_64
ONLY_ACTIVE_ARCH = NO # Build for all architectures for simulator/device
STRIP_INSTALLED_PRODUCT = NO
SKIP_INSTALL = NO
FLUTTER_ROOT = $FLUTTER_ROOT # Explicitly set FLUTTER_ROOT in xcconfig
EOF
echo "✅ Custom settings appended to Release.xcconfig. Verified."

# Update the Shell Script Build Phase to use FLUTTER_ROOT using Ruby
echo "⚙️ Updating Flutter's Run Script build phase in project.pbxproj..."
# Ruby script needs to be very robust in how it finds and modifies the shell script.
# It should target the 'Runner' target's 'Run Script' phase that contains 'xcode_backend.sh'.
ruby -e "
require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
flutter_root_from_arg = ARGV[0] # Get FLUTTER_ROOT from command line argument

project.targets.each do |target|
  if target.name == 'Runner'
    target.shell_script_build_phases.each do |phase|
      if phase.shell_script.include?('xcode_backend.sh')
        puts '  Found xcode_backend.sh script phase.'
        
        # Construct the correct script content as a clean string
        # Using %Q{} for multi-line string literal to avoid issues with EOF markers
        # and ensure correct variable interpolation.
        correct_script_content = %Q(
          export FLUTTER_ROOT=\"#{flutter_root_from_arg}\"
          \"\$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh\" build
        ).strip # .strip to remove leading/trailing whitespace from the multiline string

        # Update the phase's shell script content
        phase.shell_script = correct_script_content
        
        puts '  Run Script phase content explicitly set with correct FLUTTER_ROOT and xcode_backend.sh path.'
      end
    end
  end
end
project.save" "$FLUTTER_ROOT" # Pass FLUTTER_ROOT as an argument
echo "✅ Flutter's Run Script build phase updated in project.pbxproj. Verified."


# Step 6: Configure Firebase using flutterfire_cli
echo "🔥 Configuring Firebase for iOS project 'teambuilder-plus-fe74d'..."
if [ ! -f scripts/GoogleService-Info.plist ]; then
  echo "⚠️ Warning: scripts/GoogleService-Info.plist not found. Firebase configuration might be incomplete."
  echo "   If you intend to use Firebase, please download it from Firebase console and place it in 'scripts/'."
else
  flutterfire configure \
    --project=teambuilder-plus-fe74d \
    --platforms=ios \
    --ios-out=ios/Runner/GoogleService-Info.plist \
    --yes # --yes confirms other prompts automatically
  echo "✅ Firebase configured. GoogleService-Info.plist should now be referenced in Xcode."

  echo "🔍 Validating GoogleService-Info.plist syntax..."
  plutil -lint ios/Runner/GoogleService-Info.plist || { echo "❌ ERROR: GoogleService-Info.plist is invalid." && exit 1; }
  echo "✅ GoogleService-Info.plist syntax is valid. Verified."

  echo "📦 Running pod install again after Firebase configuration (non-interactive)..."
  cd ios
  CI=true COCOAPODS_DISABLE_STATS=1 pod install --repo-update
  cd "$SRC_DIR"
fi


# Step 7: Sync Manifest.lock
if [ -f ios/Podfile.lock ]; then
  mkdir -p ios/Pods
  cp ios/Podfile.lock ios/Pods/Manifest.lock
  echo "📦 Synced Podfile.lock → ios/Pods/Manifest.lock. Verified."
fi


# Step 8: Additional Cleanup and Framework Preparation (based on user's suggestion)
echo "--- Starting additional cleanup and framework preparation ---"

# This is placed here to target any DerivedData created during initial flutter create/pub get/pod install
echo "🧹 Deleting Derived Data to force a clean signing context (pre-final build)..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# NEW: Broad xattr -cr on the entire project directory
echo "🔐 Running xattr -cr on the entire project directory ($SRC_DIR)..."
xattr -cr "$SRC_DIR" || true
echo "✅ Extended attributes removed from project directory (if any)."


echo "🔐 Attempting to remove any residual signature from source Flutter.framework..."
# This targets the Flutter.framework that gets created/managed in the 'ios/Flutter' directory.
# The primary issue is typically with the one in the build/ output directory.
# This step is an extra safeguard.
if [ -d "$IOS_DIR/Flutter/Flutter.framework" ]; then
  codesign --remove-signature "$IOS_DIR/Flutter/Flutter.framework" || true
  echo "✅ Signature removed from $IOS_DIR/Flutter/Flutter.framework (if present)."
else
  echo "ℹ️ $IOS_DIR/Flutter/Flutter.framework not found, skipping signature removal."
fi

echo "🛠️ Building Flutter.framework specifically to ensure fresh contents for embedding..."
# This command builds the standalone framework and places it in the 'ios/Flutter' directory.
# The main 'flutter build ios' command will then use this prepared framework.
# If 'flutter build ios-framework' fails, it means there's an issue with the Flutter SDK's ability
# to codesign its own output, likely due to persistent 'resource fork' issues on the system.
flutter build ios-framework --no-universal --output="$IOS_DIR/Flutter"
echo "✅ Flutter.framework rebuilt in $IOS_DIR/Flutter."

echo "--- Completed additional cleanup and framework preparation ---"


# Step 9: Final build attempt with corrected paths and signing setup
echo "🏗 Attempting final build with corrected paths and signing setup..."

# Try building for simulator first
echo "📱 Attempting iOS Simulator build..."
if flutter build ios --simulator; then
  echo "✅ iOS Simulator build successful. Verified."
else
  echo "⚠️ iOS Simulator build failed. This could indicate a deeper Xcode issue."
fi

# Attempt device build
echo "📱 Attempting iOS device build..."
if flutter build ios; then
  echo "✅ iOS device build successful! Verified."
  BUILD_SUCCESS=true
else
  echo "❌ iOS device build failed. Please check the log file for details."
  BUILD_SUCCESS=false
fi

if [ "$BUILD_SUCCESS" = true ]; then
  echo "✅ Enhanced rebuild process complete. Verified."
else
  echo "❌ Enhanced rebuild process failed. Please check the log file for details."
fi

# Step 10: Open the project in Xcode for final review
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
echo "   - **Your iOS device is passcode protected (unlock it!)**" # Added this specific reminder
echo "   - Xcode license agreement not accepted"

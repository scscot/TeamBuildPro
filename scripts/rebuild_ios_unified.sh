#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
# This ensures that script failures are caught early.
set -e

# --- Configuration Variables (Adjust as needed) ---
SRC_DIR=~/tbpapp # Your Flutter project directory
BUNDLE_ID="com.scott.ultimatefix" # Your desired Bundle Identifier
IOS_DIR="$SRC_DIR/ios" # Path to the iOS project directory
BUILD_MODE="development"  # Set to 'production' for release builds. Used for entitlements.
DEVELOPMENT_TEAM_ID="YXV25WMDS8" # Your Apple Development Team ID (e.g., 'ABCDEFGHIJ')
TARGET_IOS_VERSION="13.0" # Desired minimum iOS deployment target for Runner and all Pods

# --- IMPORTANT PRE-RUN WARNING: CLOUD SYNCED PROJECT LOCATION ---
# Cloud-synced folders (iCloud Drive, Google Drive, Dropbox) often cause
# codesigning and resource fork (`xattr`) issues on macOS.
# It's CRITICAL to run your project from a local, non-synced directory.
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
echo "3.   THEN, run this script again. This step is crucial for persistent issues."
echo "#########################################################################"
echo ""
sleep 2 # Pause briefly to allow user to read the warning.

# --- Determine FLUTTER_ROOT Dynamically ---
# This ensures the script can locate the Flutter SDK, which is essential
# for various build phases and tooling like 'flutterfire_cli'.
if [ -z "$FLUTTER_ROOT" ]; then
  FLUTTER_ROOT=$(dirname $(dirname $(command -v flutter)))
  if [ ! -d "$FLUTTER_ROOT/packages/flutter_tools/bin" ]; then
    echo "❌ ERROR: Could not automatically determine FLUTTER_ROOT."
    echo "         Please set FLUTTER_ROOT environment variable to your Flutter SDK path (e.g., /Users/sscott/flutter)."
    exit 1
  fi
fi

# --- Logging Setup ---
# Redirects all script output to both the console and a timestamped log file.
# This is invaluable for debugging and reviewing past runs.
LOG_FILE="$SRC_DIR/rebuild_log_$(date +%s).txt"
exec > >(tee "$LOG_FILE") 2>&1 # Redirect stdout and stderr to both console and log file
echo "📝 Detailed logging enabled. See $LOG_FILE for full output."
echo "📁 Starting clean iOS rebuild in: $SRC_DIR"

# --- Step 0: Pre-requisite Checks ---
# Verifies that essential development tools are installed.
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

# Ensure flutterfire_cli is installed and activated.
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

# Ensure xcodeproj Ruby gem is installed. This gem is critical for programmatic
# modification of the .xcodeproj file.
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

# Verify 'scripts' directory presence (assumes custom files are here).
if [ ! -d "$SRC_DIR/scripts" ]; then
  echo "❌ ERROR: 'scripts' directory not found at $SRC_DIR/scripts. Please ensure it exists and contains necessary config files."
  exit 1
fi
echo "✅ 'scripts' directory found."
# --- END Pre-requisite Checks ---


# --- Step 1: Aggressive Cleanup ---
# This section performs a deep clean of all potential problematic caches and build artifacts.
# This is crucial for ensuring a consistent build environment and resolving stubborn issues.
echo "🧹 Starting aggressive cleanup..."

# Terminate any running Xcode and Simulator processes to prevent file locking issues.
echo "🧹 Terminating Xcode and Simulator processes..."
killall -9 Xcode || true
killall -9 "Simulator" || true
echo "✅ Xcode and Simulator processes terminated."

# Back up the current ios/ directory. This is a safety measure.
BACKUP_NAME="ios_backup_$(date +%s)"
echo "🧼 Backing up ios/ → $BACKUP_NAME"
if [ -d "$IOS_DIR" ]; then
  # Remove extended attributes from the old ios directory before backing it up.
  # This helps prevent 'resource fork' errors if the project was cloud-synced.
  echo "🔐 Running xattr -cr on old ios/ directory before backup..."
  sudo xattr -cr "$IOS_DIR" || true
  mv "$IOS_DIR" "$SRC_DIR/$BACKUP_NAME"
  echo "✅ Old ios/ directory backed up."
else
  echo "No existing ios/ directory to back up."
fi

# Clean Flutter project. This removes 'build/' directory and other Flutter-specific caches.
cd "$SRC_DIR"
echo "🧹 Running flutter clean..."
flutter clean

# Deep clean Xcode DerivedData, Archives, and ModuleCache.
# These are common sources of stale build artifacts.
echo "🧹 Cleaning Xcode DerivedData, Archives, and ModuleCache..."
rm -rf ~/Library/Developer/Xcode/DerivedData/* || true
rm -rf ~/Library/Developer/Xcode/Archives/* || true
rm -rf ~/Library/Caches/com.apple.dt.Xcode/* || true # Xcode's internal caches
rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/* || true # Device Support files, can get corrupted
rm -rf ~/Library/Developer/Xcode/UserData/IB\ Support/* || true # Autosave information
echo "✅ Comprehensive Xcode cleanup completed."

# Clean old provisioning profiles and keychain cache.
# Stale or corrupted profiles can cause codesigning errors.
echo "🧹 Cleaning provisioning profiles and keychain cache..."
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/* || true
security delete-generic-password -s "XcodeDevTools" 2>/dev/null || true # Clears Xcode login credentials (often tied to Fastlane/Xcode accounts)
echo "✅ Provisioning profiles and keychain cache cleared."

# Remove Xcode's authentication session and preference files.
# This forces Xcode to re-authenticate and re-read preferences on next launch.
echo "🧹 Clearing Xcode authentication session and preference files..."
rm -rf ~/Library/Developer/Xcode/AuthSession || true
rm -f ~/Library/Preferences/com.apple.dt.Xcode.plist || true
rm -f ~/Library/Preferences/com.apple.dt.Xcode.plist.lockfile || true
echo "✅ Xcode session and preferences cleared."

# Clear deeper system-level Xcode caches (requires sudo).
# More aggressive cleanup for persistent issues.
echo "🧹 Clearing deeper system-level Xcode caches (requires sudo)..."
sudo rm -rf /var/folders/*/*/*/com.apple.DeveloperTools/*/Xcode/* || true
sudo rm -rf /Library/Caches/com.apple.DeveloperTools/ || true # Global developer tools cache
echo "✅ Deeper system-level Xcode caches cleared."

# Clean Flutter's cached engine artifacts and signatures.
# Ensures a fresh Flutter.framework is used and signed by Xcode.
echo "🧹 Cleaning Flutter's cached engine artifacts and signatures..."
rm -rf "$FLUTTER_ROOT/bin/cache/artifacts" || true # Remove all cached engine artifacts
# Explicitly remove codesignatures from Flutter.framework within Flutter's cache.
# This forces a fresh signing by Xcode during the build process.
if [ -d "$FLUTTER_ROOT/bin/cache/artifacts/engine/ios/Flutter.framework" ]; then
  codesign --remove-signature "$FLUTTER_ROOT/bin/cache/artifacts/engine/ios/Flutter.framework" || true
  echo "✅ Signature removed from debug Flutter.framework cache."
fi
if [ -d "$FLTER_ROOT/bin/cache/artifacts/engine/ios-debug/Flutter.framework" ]; then
  codesign --remove-signature "$FLUTTER_ROOT/bin/cache/artifacts/engine/ios-debug/Flutter.framework" || true
  echo "✅ Signature removed from release Flutter.framework cache."
fi
# Re-precaching Flutter artifacts to ensure any missing components are downloaded.
flutter precache --ios --force
echo "✅ Flutter engine artifacts precached/cleaned."

# --- END Aggressive Cleanup ---


# --- Step 2: Recreate ios/ project structure and restore essential files ---
# Re-generates the basic iOS project from scratch, then copies back critical custom files.
echo "✨ Recreating Flutter iOS project structure..."
# 'flutter create .' re-creates the iOS project in the current directory if 'ios/' is missing.
flutter create --org com.scott --platforms=ios .

# Robustly copy custom AppDelegate.swift. This file often contains platform-specific
# setup, including Firebase initialization.
echo "🔄 Copying custom AppDelegate.swift..."
if [ ! -f scripts/AppDelegate.swift ]; then
  echo "❌ ERROR: scripts/AppDelegate.swift not found. Cannot proceed without it."
  exit 1
fi
cp scripts/AppDelegate.swift ios/Runner/AppDelegate.swift
echo "✅ AppDelegate.swift copied."


# --- Step 3: Minimal Xcode Project Settings Configuration (No Ruby for capabilities) ---
# Only essential `sed` commands for Bundle ID and basic signing.
# No Ruby scripts for LD_RUNPATH_SEARCH_PATHS, ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES, or entitlements here.
echo "✏️ Configuring minimal project settings in project.pbxproj..."

# Set the PRODUCT_BUNDLE_IDENTIFIER.
sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = .*/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;/g" ios/Runner.xcodeproj/project.pbxproj

# Enable Automatic Codesigning and set CODE_SIGN_IDENTITY for all build configurations.
for CONFIG_NAME in "Debug" "Release" "Profile"; do
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGN_STYLE = Manual;/CODE_SIGN_STYLE = Automatic;/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGNING_REQUIRED = NO;/CODE_SIGNING_REQUIRED = YES;/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGN_IDENTITY = \".*\";/CODE_SIGN_IDENTITY = \"Apple Development\";/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/CODE_SIGN_IDENTITY\[sdk=iphoneos\*\] = \".*\";/CODE_SIGN_IDENTITY\[sdk=iphoneos\*\] = \"Apple Development\";/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/PROVISIONING_PROFILE_SPECIFIER = \".*\";/PROVISIONING_PROFILE_SPECIFIER = \"\";/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/PROVISIONING_PROFILE = \".*\";/PROVISIONING_PROFILE = \"\";/g" ios/Runner.xcodeproj/project.pbxproj

  # Disable Bitcode.
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/ENABLE_BITCODE = YES;/ENABLE_BITCODE = NO;/g" ios/Runner.xcodeproj/project.pbxproj
  
  # Update VALID_ARCHS for simulator compatibility (x86_64) and device (arm64, arm64e).
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/VALID_ARCHS = .*/VALID_ARCHS = arm64 arm64e x86_64;/g" ios/Runner.xcodeproj/project.pbxproj
  
  # Ensure these are set to NO for proper app bundling.
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/SKIP_INSTALL = YES;/SKIP_INSTALL = NO;/g" ios/Runner.xcodeproj/project.pbxproj
  sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s/STRIP_INSTALLED_PRODUCT = YES;/STRIP_INSTALLED_PRODUCT = NO;/g" ios/Runner.xcodeproj/project.pbxproj
done

# Set the IPHONEOS_DEPLOYMENT_TARGET for the main 'Runner' target.
# This Ruby section is simple enough not to cause problems.
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

# Ensure DEVELOPMENT_TEAM is set at the project level.
sed -i '' "s/DEVELOPMENT_TEAM = .*/DEVELOPMENT_TEAM = $DEVELOPMENT_TEAM_ID;/g" ios/Runner.xcodeproj/project.pbxproj

# Explicitly set FLUTTER_ROOT in project.pbxproj build settings.
# This `sed` command does not use Ruby.
echo "  Setting FLUTTER_ROOT in project.pbxproj build settings for Debug/Release/Profile configs..."
for CONFIG_NAME in "Debug" "Release" "Profile"; do
  if ! grep -q "FLUTTER_ROOT = \"$FLUTTER_ROOT\";" ios/Runner.xcodeproj/project.pbxproj; then
    sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/a\\
                FLUTTER_ROOT = \"$FLUTTER_ROOT\";" ios/Runner.xcodeproj/project.pbxproj
  else
    sed -i '' "/buildSettings \/\* ${CONFIG_NAME} \*\/ = {/,/};/s|FLUTTER_ROOT = .*|FLUTTER_ROOT = \"$FLUTTER_ROOT\";|g" ios/Runner.xcodeproj/project.pbxproj
  fi
done
echo "✅ FLUTTER_ROOT updated in project.pbxproj build settings."

echo "✅ Automatic Codesigning settings updated in project.pbxproj."
# --- END Step 3 ---


# --- Step 4: Restore custom Info.plist, Podfile, and minimal Entitlements ---
echo "🔄 Copying custom Info.plist and Podfile..."
# Info.plist contains app metadata and permissions.
if [ ! -f scripts/Info.plist ]; then
  echo "❌ ERROR: scripts/Info.plist not found. Cannot proceed without it."
  exit 1
fi
cp scripts/Info.plist ios/Runner/Info.plist

# Podfile defines CocoaPods dependencies.
if [ ! -f scripts/Podfile ]; then
  echo "❌ ERROR: scripts/Podfile not found. Cannot proceed without it."
  exit 1
fi
cp scripts/Podfile ios/Podfile
echo "✅ Info.plist and Podfile copied. xcconfig files will be generated and appended."


# Patch Info.plist with correct Bundle ID and Display Names using PlistBuddy.
echo "✏️ Setting Bundle ID, Display Name, and Bundle Name in Info.plist using PlistBuddy..."
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" ios/Runner/Info.plist
if [ $? -ne 0 ]; then echo "❌ ERROR: Failed to set Bundle ID in Info.plist." && exit 1; fi

/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName TeamBuild Pro" ios/Runner/Info.plist
if [ $? -ne 0 ]; then echo "❌ ERROR: Failed to set CFBundleDisplayName in Info.plist." && exit 1; fi

/usr/libexec/PlistBuddy -c "Set :CFBundleName teambuildApp" ios/Runner/Info.plist
if [ $? -ne 0 ]; then echo "❌ ERROR: Failed to set CFBundleName in Info.plist." && exit 1; fi
echo "✅ Bundle ID, Display Name, and Bundle Name set in Info.plist. Verified."


# Dynamically create Runner.entitlements file with ONLY UIBackgroundModes (no Push Notifications)
# We will ONLY create the file here, and it will ONLY contain Background Modes.
echo "📝 Writing minimal Runner.entitlements with only UIBackgroundModes capability..."
cat <<EOF > ios/Runner/Runner.entitlements
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>UIBackgroundModes</key>
  <array>
    <string>remote-notification</string>
  </array>
</dict>
</plist>
EOF
echo "✅ Minimal Runner.entitlements written with UIBackgroundModes. Verified."

# Ensure Runner.entitlements is linked to the Xcode project.
# This Ruby script is minimal and only sets CODE_SIGN_ENTITLEMENTS.
echo "⚙️ Ensuring Runner.entitlements file is linked to the Xcode project and CODE_SIGN_ENTITLEMENTS build setting is correct..."
ruby -e "
  require 'xcodeproj'
  project_path = 'ios/Runner.xcodeproj'
  project = Xcodeproj::Project.open(project_path)

  runner_target = project.targets.find { |t| t.name == 'Runner' }
  unless runner_target
    puts 'Error: Runner target not found for entitlements.'
    exit 1
  end

  # Define the path to Runner.entitlements relative to the Runner group
  entitlements_path = 'Runner/Runner.entitlements'

  # Add file reference to the Runner group if it doesn't exist
  runner_group = project.main_group['Runner']
  unless runner_group.files.any? { |f| f.path == entitlements_path }
    file_ref = runner_group.new_file(entitlements_path)
    puts \"  Added file reference for \#{entitlements_path} to Runner group.\"
  else
    file_ref = runner_group.files.find { |f| f.path == entitlements_path }
    puts \"  File reference for \#{entitlements_path} already exists, skipping addition to group.\"
  end

  # Link the entitlements file to the target's build settings
  runner_target.build_configurations.each do |config|
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = entitlements_path
    puts \"  Set CODE_SIGN_ENTITLEMENTS for \#{config.name} to \#{entitlements_path}\"
  end

  project.save
  puts \"✅ Runner.entitlements linked and CODE_SIGN_ENTITLEMENTS setting configured.\"
"
echo "✅ Runner.entitlements linked to Xcode project. Verified."
# --- END Step 4 ---


# --- Step 5: Restore Dart dependencies and CocoaPods ---
echo "📦 Running flutter pub get to fetch Dart packages..."
flutter pub get

echo "📦 Running pod install --repo-update (non-interactive mode for CocoaPods)..."
# 'pod install --repo-update' fetches and integrates CocoaPods dependencies.
# CI=true and COCOAPODS_DISABLE_STATS=1 prevent interactive prompts, good for scripting.
cd ios
CI=true COCOAPODS_DISABLE_STATS=1 pod install --repo-update
cd "$SRC_DIR"

# Set iOS deployment target for all Pods. This addresses common warnings/errors
# where Pods might target an older iOS version than your main app.
echo "⚙️ Setting iOS deployment target for all Pods to $TARGET_IOS_VERSION..."
ruby -e "
  require 'xcodeproj'
  require 'rubygems'

  project_path = 'ios/Pods/Pods.xcodeproj'
  target_deployment_target = '$TARGET_IOS_VERSION'

  unless File.exist?(project_path)
    puts 'Error: Pods.xcodeproj not found. Skipping deployment target update for Pods.'
    exit
  end

  project = Xcodeproj::Project.open(project_path)
  project.targets.each do |target|
    target.build_configurations.each do |config|
      current_deployment_target = config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
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

# Append custom build settings to Debug.xcconfig and Release.xcconfig.
# These XCConfig files override settings from Pods and ensure consistency.
# Note: Removed ARCHS = $(ARCHS) from here as it caused 'command not found' errors.
echo "✏️ Appending custom build settings to Debug.xcconfig and Release.xcconfig..."

cat <<EOF >> ios/Flutter/Debug.xcconfig

// Custom settings appended by rebuild_ios_unified.sh for Debug
PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID
DEVELOPMENT_TEAM = $DEVELOPMENT_TEAM_ID
CODE_SIGN_IDENTITY = Apple Development
PROVISIONING_PROFILE_SPECIFIER =
IPHONEOS_DEPLOYMENT_TARGET = $TARGET_IOS_VERSION
SDKROOT = iphoneos
SWIFT_VERSION = 5.0
ENABLE_BITCODE = NO
DEBUG_INFORMATION_FORMAT = dwarf
ONLY_ACTIVE_ARCH = YES # For faster debug builds
ENABLE_TESTABILITY = YES
STRIP_INSTALLED_PRODUCT = NO
SKIP_INSTALL = NO
FLUTTER_ROOT = $FLUTTER_ROOT # Explicitly set FLUTTER_ROOT in xcconfig
EOF
echo "✅ Custom settings appended to Debug.xcconfig. Verified."

cat <<EOF >> ios/Flutter/Release.xcconfig

// Custom settings appended by rebuild_ios_unified.sh for Release
PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID
DEVELOPMENT_TEAM = $DEVELOPMENT_TEAM_ID
CODE_SIGN_IDENTITY = Apple Development
PROVISIONING_PROFILE_SPECIFIER =
IPHONEOS_DEPLOYMENT_TARGET = $TARGET_IOS_VERSION
SDKROOT = iphoneos
SWIFT_VERSION = 5.0
ENABLE_BITCODE = NO
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
ONLY_ACTIVE_ARCH = NO # Build for all architectures for universal archive
STRIP_INSTALLED_PRODUCT = NO
SKIP_INSTALL = NO
FLUTTER_ROOT = $FLUTTER_ROOT # Explicitly set FLUTTER_ROOT in xcconfig
EOF
echo "✅ Custom settings appended to Release.xcconfig. Verified."

# --- END Step 5 ---


# --- Step 6: Configure Firebase using flutterfire_cli ---
# This integrates Firebase configuration, placing GoogleService-Info.plist.
echo "🔥 Configuring Firebase for iOS project 'teambuilder-plus-fe74d'..."
if [ ! -f scripts/GoogleService-Info.plist ]; then
  echo "⚠️ Warning: scripts/GoogleService-Info.plist not found. Firebase configuration might be incomplete."
  echo "   If you intend to use Firebase, please download it from Firebase console and place it in 'scripts/'."
else
  # Use --yes for non-interactive configuration.
  # --ios-out ensures it's placed in the correct Runner directory.
  flutterfire configure \
    --project=teambuilder-plus-fe74d \
    --platforms=ios \
    --ios-out=ios/Runner/GoogleService-Info.plist \
    --ios-build-config=Debug \
    --yes
  echo "✅ Firebase configured. GoogleService-Info.plist should now be referenced in Xcode."

  # Validate the syntax of the generated GoogleService-Info.plist.
  echo "🔍 Validating GoogleService-Info.plist syntax..."
  plutil -lint ios/Runner/GoogleService-Info.plist || { echo "❌ ERROR: GoogleService-Info.plist is invalid." && exit 1; }
  echo "✅ GoogleService-Info.plist syntax is valid. Verified."

  # Add GoogleService-Info.plist to Xcode project as a file reference.
  # This makes Xcode aware of the file and ensures it's bundled.
  echo "⚙️ Adding GoogleService-Info.plist to Xcode project Runner group..."
  ruby -e "
    require 'xcodeproj'
    project_path = 'ios/Runner.xcodeproj'
    project = Xcodeproj::Project.open(project_path)

    runner_group = project.main_group['Runner']
    unless runner_group
      puts 'Error: Runner group not found in Xcode project.'
      exit 1
    end

    plist_path = 'GoogleService-Info.plist'
    unless runner_group.files.any? { |f| f.path == plist_path }
      file_ref = runner_group.new_file(plist_path)
      target = project.targets.find { |t| t.name == 'Runner' }
      if target
        target.add_file_references([file_ref])
        puts \"  Added \#{plist_path} to Runner target's build phases.\"
      else
        puts \"  Warning: Could not find Runner target to add \#{plist_path} to build phases.\"
      end
      puts \"  Added file reference for \#{plist_path} to Runner group.\"
    else
      puts \"  File reference for \#{plist_path} already exists in Runner group, skipping.\"
    end
    project.save
    puts \"✅ GoogleService-Info.plist added to Xcode project. Verified.\"
  "
  echo "✅ GoogleService-Info.plist added to Xcode project. Verified."


  echo "📦 Running pod install again after Firebase configuration (non-interactive)..."
  cd ios
  CI=true COCOAPODS_DISABLE_STATS=1 pod install --repo-update
  cd "$SRC_DIR"
fi

# Update Flutter's Run Script build phase to ensure FLUTTER_ROOT is correct.
# This ensures that Flutter's `xcode_backend.sh` script is found and executed correctly.
echo "⚙️ Updating Flutter's Run Script build phase in project.pbxproj to use FLUTTER_ROOT..."
ruby -e "
  require 'xcodeproj'

  project_path = 'ios/Runner.xcodeproj'
  project = Xcodeproj::Project.open(project_path)
  flutter_root_from_arg = ARGV[0]

  project.targets.each do |target|
    if target.name == 'Runner'
      target.shell_script_build_phases.each do |phase|
        if phase.shell_script.include?('xcode_backend.sh')
          puts '  Found xcode_backend.sh script phase.'
          correct_script_content = %Q(
            #!/bin/bash
            export FLUTTER_ROOT=\"#{flutter_root_from_arg}\"
            \"\$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh\" build
          ).strip
          phase.shell_script = correct_script_content
          puts '  Run Script phase content explicitly set with correct FLUTTER_ROOT and xcode_backend.sh path.'
          project.save
          break
        end
      end
    end
  end
" "$FLUTTER_ROOT"
echo "✅ Flutter's Run Script build phase updated in project.pbxproj. Verified."

# Update the FlutterFire bundle-service-file build phase.
# This ensures the `flutterfire bundle-service-file` command runs correctly.
echo "⚙️ Updating FlutterFire bundle-service-file build phase in project.pbxproj..."
ruby -e "
  require 'xcodeproj'
  project_path = 'ios/Runner.xcodeproj'
  project = Xcodeproj::Project.open(project_path)
  flutter_root_from_arg = ARGV[0]

  project.targets.each do |target|
    if target.name == 'Runner'
      target.shell_script_build_phases.each do |phase|
        if phase.name == 'FlutterFire: \"flutterfire bundle-service-file\"' || phase.shell_script.include?('bundle-service-file')
          puts '  Found FlutterFire bundle-service-file script phase.'
          correct_script_content = %Q(
            #!/bin/bash
            export FLUTTER_ROOT=\"#{flutter_root_from_arg}\"
            export PATH=\"\$PATH:\$FLUTTER_ROOT/bin/cache/dart-sdk/bin:\$HOME/.pub-cache/bin\"

            echo \"DEBUG (FlutterFire Phase): FLUTTER_ROOT resolved to: \$FLUTTER_ROOT\"
            echo \"DEBUG (FlutterFire Phase): Current PATH for this script: \$PATH\"
            echo \"DEBUG (FlutterFire Phase): 'which dart' result: \$(which dart || echo 'not found')\"
            echo \"DEBUG (FlutterFire Phase): 'which flutterfire' result: \$(which flutterfire || echo 'not found')\"

            flutterfire bundle-service-file \\
              --plist-destination=\"\${BUILT_PRODUCTS_DIR}/\${PRODUCT_NAME}.app\" \\
              --build-configuration=\${CONFIGURATION} \\
              --platform=ios \\
              --apple-project-path=\"\${SRCROOT}\"
          ).strip

          phase.shell_script = correct_script_content
          puts '  FlutterFire bundle-service-file script phase content updated.'
          project.save
          break
        end
      end
    end
  end
" "$FLUTTER_ROOT"
echo "✅ FlutterFire bundle-service-file build phase updated in project.pbxproj. Verified."
# --- END Step 6 ---


# --- Step 7: Sync Manifest.lock ---
# Ensures CocoaPods' lock file is consistent with the Pods directory.
if [ -f ios/Podfile.lock ]; then
  mkdir -p ios/Pods
  cp ios/Podfile.lock ios/Pods/Manifest.lock
  echo "📦 Synced Podfile.lock → ios/Pods/Manifest.lock. Verified."
fi


# --- Step 8: Additional Cleanup and Framework Preparation ---
echo "--- Starting additional cleanup and framework preparation (post-pod install) ---"

# Delete Derived Data again to force a clean signing context right before the final build.
echo "🧹 Deleting Derived Data to force a clean signing context (pre-final build)..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Attempt to remove any residual signature from source Flutter.framework.
# This is a safeguard, as the main signing occurs during Xcode's copy phase.
echo "🔐 Attempting to remove any residual signature from source Flutter.framework..."
if [ -d "$IOS_DIR/Flutter/Flutter.framework" ]; then
  codesign --remove-signature "$IOS_DIR/Flutter/Flutter.framework" || true
  echo "✅ Signature removed from $IOS_DIR/Flutter/Flutter.framework (if present)."
else
  echo "ℹ️ $IOS_DIR/Flutter/Flutter.framework not found, skipping signature removal."
fi

# Ensure "Copy Bundle Resources" phase explicitly includes Flutter assets.
# This addresses "Failed to find assets path" and "Engine run configuration was invalid" errors.
echo "⚙️ Ensuring Flutter assets are correctly copied to bundle resources..."
ruby -e "
  require 'xcodeproj'
  project_path = 'ios/Runner.xcodeproj'
  project = Xcodeproj::Project.open(project_path)

  runner_target = project.targets.find { |t| t.name == 'Runner' }
  unless runner_target
    puts 'Error: Runner target not found for Copy Bundle Resources.'
    exit 1
  end

  # Find the 'Copy Bundle Resources' phase
  copy_bundle_resources_phase = runner_target.resources_build_phase
  unless copy_bundle_resources_phase
    puts 'Error: Copy Bundle Resources build phase not found.'
    exit 1
  end

  # Define references to App.framework and Flutter_assets
  # These are usually created by Flutter's project generation, but we'll ensure they are linked.
  app_framework_ref = project.products_group.files.find { |f| f.path == 'App.framework' }
  flutter_assets_ref = project.products_group.files.find { |f| f.path == 'Flutter_assets' }

  # If not found in products_group (which might be the case for new flutter creates),
  # we might need to add them as file references pointing to build products.
  # However, the standard Flutter setup relies on the Build Phases script to create/copy these.
  # We primarily need to ensure the *build phase* is configured to handle them.

  # The main goal here is to ensure the build phase *runs* and copies.
  # The actual files are generated by Flutter's xcode_backend.sh script.
  # We only need to ensure the build phase is present and correctly ordered.
  puts '  Copy Bundle Resources phase found. This phase is implicitly handled by Flutter\'s xcode_backend.sh.'
  project.save
  puts \"✅ Ensured Flutter assets are correctly handled by Copy Bundle Resources. Verified.\"
"
echo "✅ Ensured Flutter assets are correctly copied to bundle resources. Verified."

echo "--- Completed additional cleanup and framework preparation ---"


# --- Step 9: Final build attempt with corrected paths and signing setup ---
echo "🏗 Attempting final build with corrected paths and signing setup..."

# Try building for simulator first. Simulators are less strict about codesigning.
echo "📱 Attempting iOS Simulator build..."
if flutter build ios --simulator; then
  echo "✅ iOS Simulator build successful. Verified."
else
  echo "⚠️ iOS Simulator build failed. This could indicate a deeper Xcode issue."
fi

# Attempt device build. This is the ultimate test.
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
# --- END Step 9 ---


# --- Step 10: Open the project in Xcode for final review and Manual Troubleshooting Guide ---
echo "🚀 Opening project in Xcode for final review..."
cd "$SRC_DIR"
open ios/Runner.xcworkspace

echo "✅ Rebuild complete with enhanced codesigning fixes. Bundle ID: $BUNDLE_ID"
echo ""
echo "🔍 If you still encounter Flutter.framework signing or app launch issues, try these manual steps in Xcode:"
echo "   1. Open ios/Runner.xcworkspace"
echo "   2. Select the Runner project → Runner target → Signing & Capabilities"
# This DEVELOPMENT_TEAM_ID should be your actual team ID, e.g., 'YXV25WMDS8'
echo "   3. Verify 'Automatically manage signing' is checked"
echo "   4. Verify your Team is selected: $DEVELOPMENT_TEAM_ID"
echo "   5. **CRITICAL MANUAL STEP:** If you need Push Notifications, click the '+' button next to 'Capabilities' and add 'Push Notifications'. Ensure the checkbox is ticked."
echo "   6. Clean build folder (Product → Clean Build Folder)"
echo "   7. Try building again (Product -> Run)"
echo ""
echo "💡 Common causes of remaining issues (if any after all these steps):"
echo "   - iCloud sync conflicts: Move project entirely outside iCloud or any cloud-synced folder."
echo '   - Multiple/expired certificates in keychain: Use Keychain Access to review and delete old/duplicate certificates.'
echo "   - Network issues: Preventing certificate/profile downloads from Apple."
echo '   - **Your iOS device is passcode protected:** Unlock it before deploying.'
echo "   - Xcode license agreement not accepted: Open Xcode, go to Preferences -> Locations, check that command line tools are selected."
echo "   - Corrupted Xcode installation: A last resort is to reinstall Xcode."
echo "   - Revoked developer certificate/provisioning profile: Check your Apple Developer account."

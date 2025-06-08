#!/bin/bash

# Navigate to project directory
cd ~/Desktop/tbp || exit 1

# Remove existing DartFiles.zip if it exists
rm -f DartFiles.zip

# Zip specified Dart files into DartFiles.zip
zip DartFiles.zip \
  lib/main.dart \
  lib/services/auth_service.dart \
  lib/services/session_manager.dart \
  lib/services/firestore_service.dart \
  lib/services/biometric_auth_service.dart \
  lib/screens/login_screen.dart \
  lib/screens/new_registration_screen.dart \
  lib/screens/dashboard_screen.dart \
  lib/screens/profile_screen.dart \
  lib/screens/edit_profile_screen.dart \
  lib/screens/downline_team_screen.dart \
  lib/models/user_model.dart \
  lib/data/states_by_country.dart \
  pubspec.yaml \
  ios/Podfile

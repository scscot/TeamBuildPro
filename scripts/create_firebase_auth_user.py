import firebase_admin
from firebase_admin import credentials, auth
import sys

# Load service account credentials
cred = credentials.Certificate("../secrets/serviceAccountKey.json")
firebase_admin.initialize_app(cred)

# Prompt for user input
email = input("Enter user email: ").strip()
password = input("Enter user password: ").strip()
uid = input("Enter custom UID (leave blank to auto-generate): ").strip()

try:
    # Create user with or without a specified UID
    if uid:
        user = auth.create_user(
            uid=uid,
            email=email,
            password=password
        )
    else:
        user = auth.create_user(
            email=email,
            password=password
        )

    print(f"✅ Successfully created user:")
    print(f"    UID: {user.uid}")
    print(f"    Email: {user.email}")
except Exception as e:
    print(f"❌ Error creating user: {e}")
    sys.exit(1)

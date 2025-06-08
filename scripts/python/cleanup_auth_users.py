import firebase_admin
from firebase_admin import credentials, auth

# Initialize Firebase Admin SDK
# Replace with the actual path to your service account key
try:
    cred = credentials.Certificate("/Users/sscott/Desktop/tbp/secrets/serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
except Exception as e:
    print(f"❌ Error initializing Firebase Admin SDK: {e}")
    print("Please ensure 'serviceAccountKey.json' is correctly configured and accessible.")
    exit()

# Reserved admin UIDs to preserve
ADMIN_UIDS_TO_PRESERVE = [
    "KJ8uFnlhKhWgBa4NVcwT",
    "537feec3",
    # Add any other admin UIDs you want to preserve here
]

print("\n🧹 Starting Firebase Auth user cleanup (excluding specified admins)...\n")
deleted_count = 0
error_count = 0

# List all users in batches
try:
    page = auth.list_users()
    while page:
        for user in page.users:
            if user.uid not in ADMIN_UIDS_TO_PRESERVE:
                try:
                    auth.delete_user(user.uid)
                    print(f"🧹 Deleted Auth user: {user.uid}")
                    deleted_count += 1
                except Exception as e:
                    print(f"❌ Error deleting Auth user {user.uid}: {e}")
                    error_count += 1
        page = page.get_next_page()
except Exception as e:
    print(f"❌ Error listing Firebase Auth users: {e}")
    error_count += 1

print(f"\n✅ Auth cleanup complete.")
print(f"Total users deleted: {deleted_count}")
if error_count > 0:
    print(f"Total errors encountered: {error_count}")
print("\n")

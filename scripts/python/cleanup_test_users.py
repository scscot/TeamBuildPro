# FINAL PATCHED — cleanup_test_users.py (Flexible Role Filter, Admin UID Exclusion)

import firebase_admin
from firebase_admin import credentials, firestore, auth

# Initialize Firebase Admin SDK
cred = credentials.Certificate("/Users/sscott/Desktop/tbp/secrets/serviceAccountKey.json")
firebase_admin.initialize_app(cred)

db = firestore.client()
users_ref = db.collection("users")

# Reserved admin UID (never delete)
ADMIN_UID = "KJ8uFnlhKhWgBa4NVcwT"

# Start cleanup
print("\n🧹 Starting test user cleanup...\n")
count = 0

for doc in users_ref.stream():
    user = doc.to_dict()
    uid = doc.id

    # Skip if UID is reserved admin
    if uid == ADMIN_UID:
        continue

    # Delete if role is not explicitly "admin"
    if user.get("role") != "admin":
        try:
            # Delete from Firestore
            users_ref.document(uid).delete()
            print(f"🗑️  Deleted Firestore doc for UID: {uid}")

            # Delete from Firebase Auth
            try:
                auth.delete_user(uid)
                print(f"🧹 Deleted Auth user: {uid}")
            except auth.UserNotFoundError:
                print(f"⚠️  Auth user not found: {uid} (skipped)")

            count += 1
        except Exception as e:
            print(f"❌ Error deleting user {uid}: {e}")

print(f"\n✅ Cleanup complete. Total users deleted: {count}\n")

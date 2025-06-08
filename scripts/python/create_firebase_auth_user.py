import sys
import firebase_admin
from firebase_admin import credentials, auth

if len(sys.argv) != 4:
    print("❌ Usage: python create_firebase_auth_user.py <UID> <EMAIL> <PASSWORD>")
    sys.exit(1)

uid, email, password = sys.argv[1], sys.argv[2], sys.argv[3]

cred = credentials.Certificate("/Users/sscott/Desktop/tbp/secrets/serviceAccountKey.json")

firebase_admin.initialize_app(cred)

try:
    user = auth.create_user(uid=uid, email=email, password=password)
    print(f"✅ Auth user created: {user.uid}")
except Exception as e:
    print(f"❌ Error: {e}")

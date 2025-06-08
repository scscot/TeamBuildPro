import firebase_admin
from firebase_admin import auth, credentials

# Initialize the Firebase Admin SDK
cred = credentials.Certificate("/Users/sscott/Desktop/tbp/secrets/serviceAccountKey.json")

firebase_admin.initialize_app(cred)

def create_admin_user(uid, email, password):
    try:
        user = auth.create_user(
            uid=uid,
            email=email,
            password=password,
            email_verified=True,
        )
        # Optionally set admin privileges
        auth.set_custom_user_claims(user.uid, {'admin': True})
        print(f"✅ Successfully created admin user: {user.uid}")
    except Exception as e:
        print(f"❌ Error creating admin user: {e}")

# Example usage (you can replace this with argparse to pass dynamically)
if __name__ == "__main__":
    create_admin_user(
        uid="568640ad-01f2-4048-8e72-4939df3ce013",
        email="scscot1@aol.com",
        password="11111111"
    )

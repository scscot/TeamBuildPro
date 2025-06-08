# generate_test_users.py

import random
import string
import uuid
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
cred = credentials.Certificate("/Users/sscott/Desktop/tbp/secrets/serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# Config
NUM_USERS = 100
LEVEL_0_ADMIN = {
    "uid": "KJ8uFnlhKhWgBa4NVcwT",
    "referralCode": "KJ8uFnlhKhWgBa4NVcwT",
    "level": 0
}
COUNTRIES = {
    "United States": ["California", "Texas", "New York"],
    "Canada": ["Ontario", "Quebec", "British Columbia"],
    "Australia": ["New South Wales", "Victoria", "Queensland"]
}

# Util
def random_name():
    return ''.join(random.choices(string.ascii_letters, k=random.randint(5, 8)))

def random_email(name):
    domains = ["test.org"]
    return f"{name.lower()}@{random.choice(domains)}"

def create_uid():
    return str(uuid.uuid4())[:8]

# Build users
users = [LEVEL_0_ADMIN]
for i in range(NUM_USERS):
    sponsor = random.choice(users)
    uid = create_uid()
    country = random.choice(list(COUNTRIES.keys()))
    state = random.choice(COUNTRIES[country])
    user = {
        "uid": uid,
        "email": random_email(uid),
        "firstName": random_name().capitalize(),
        "lastName": random_name().capitalize(),
        "referralCode": uid,
        "referredBy": sponsor["uid"],
        "country": country,
        "state": state,
        "city": random_name().capitalize(),
        "createdAt": datetime.utcnow().isoformat(),
        "biz_join_date": None,
        "level": sponsor["level"] + 1,
        "direct_sponsor_count": None,
        "total_team_count": None,
        "role": "user",
        "photoUrl": ""
    }
    users.append(user)

# Upload users
for user in users[1:]:
    db.collection("users").document(user["uid"]).set(user)
print("✅ Test users uploaded.")

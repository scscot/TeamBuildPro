# FINAL SCRIPT — calculate_team_counts.py (direct + recursive team count)

import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict

# Initialize Firebase Admin SDK
cred = credentials.Certificate("/Users/sscott/Desktop/tbp/secrets/serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

print("\n⚖️ Calculating team counts...\n")

# Fetch all users
docs = db.collection("users").stream()
all_users = {}
referral_map = defaultdict(list)

for doc in docs:
    data = doc.to_dict()
    uid = doc.id
    all_users[uid] = data
    sponsor = data.get("referredBy")
    if sponsor:
        referral_map[sponsor].append(uid)

# Recursive function to count all downline members
def count_team(uid):
    total = 0
    for child_uid in referral_map.get(uid, []):
        total += 1  # direct
        total += count_team(child_uid)  # indirect
    return total

# Update each user's counts
for uid, user in all_users.items():
    direct = len(referral_map.get(uid, []))
    total = count_team(uid)

    try:
        db.collection("users").document(uid).update({
            "direct_sponsor_count": direct,
            "total_team_count": total
        })
        print(f"🌍 Updated {uid} => Direct: {direct}, Total: {total}")
    except Exception as e:
        print(f"❌ Failed to update {uid}: {e}")

print("\n✅ Team count calculations complete.\n")

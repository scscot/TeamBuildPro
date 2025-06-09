// 🔥 Firestore Cleanup Script — Delete All Users and Invites
// Run this with: node cleanup_firestore_test_data.js

const admin = require("firebase-admin");
const serviceAccount = require("../secrets/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const EXCLUDED_UIDS = ["KJ8uFnlhKhWgBa4NVcwT"]; // Preserve your real Admin

async function deleteCollection(collectionName) {
  const snapshot = await db.collection(collectionName).get();
  const batch = db.batch();

  snapshot.docs.forEach((doc) => {
    if (!EXCLUDED_UIDS.includes(doc.id)) {
      batch.delete(doc.ref);
    }
  });

  await batch.commit();
  console.log(`🧹 Deleted documents from ${collectionName} (excluding protected UIDs)`);
}

async function deleteAllUsers() {
  const snapshot = await db.collection("users").get();
  const batch = db.batch();

  for (const doc of snapshot.docs) {
    const uid = doc.id;
    if (EXCLUDED_UIDS.includes(uid)) {
      console.log(`⛔ Skipping protected user: ${uid}`);
      continue;
    }

    batch.delete(doc.ref);

    const notifs = await doc.ref.collection("notifications").get();
    notifs.forEach((notif) => batch.delete(notif.ref));
  }

  await batch.commit();
  console.log(`🧹 Deleted users and their notifications (excluding protected UIDs).`);
}

async function runCleanup() {
  await deleteAllUsers();
  await deleteCollection("invites");
}

runCleanup();

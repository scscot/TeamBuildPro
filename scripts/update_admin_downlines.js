// 🔄 Update Admin Firestore Document with Flattened Downline IDs
// Run with: node update_admin_downlines.js

const admin = require("firebase-admin");

const serviceAccount = require("../secrets/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const adminUid = "KJ8uFnlhKhWgBa4NVcwT";
const downlineIds = [
  "1053d962-28e2-43a7-8170-019be2eb9887",
  "ce440c3e-1bc3-412d-aad2-d327e3dd1d5f",
  "add9b2cf-f4b9-4a5c-927d-b2454db6c73a",
  "cc2190a2-3df9-4fc8-ba9f-13c80ca5fb6d",
  "9a00e089-219a-4308-860d-fa67e6eff2e1",
  "ad717d01-7dc3-4373-8709-8e071d60c105",
  "be1d009e-619b-4812-8bfa-61ba6fb3f8c9",
  "03d03e51-fef0-40ce-90c1-0b7bba5f629b",
  "8e22a971-3329-4e0c-b6b9-15596c1306b2",
  "279e7f27-13c6-42c2-8cb5-1772a888b32c",
  "cf4f41fd-1a51-4d1f-972c-21aee9cd9e7f",
  "f708750a-2f52-4f9c-818d-d1c7b3c825f5",
  "00d086c1-7c53-4509-9ec6-9c579d6737d1",
  "83d70339-713d-4d61-a63c-80430b01b86b",
  "cd067508-4cd1-4790-98a5-5642d2b73d21"
];

async function updateAdminDownline() {
  try {
    const ref = db.collection("users").doc(adminUid);
    await ref.update({ downlineIds });
    console.log("✅ Admin document updated with downlineIds.");
  } catch (error) {
    console.error("❌ Failed to update admin document:", error);
  }
}

updateAdminDownline();
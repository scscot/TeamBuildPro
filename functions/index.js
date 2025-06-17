const { onCall, HttpsError, onRequest } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { getMessaging } = require("firebase-admin/messaging");
const { v4: uuidv4 } = require("uuid");

initializeApp();
const db = getFirestore();
const auth = getAuth();
const messaging = getMessaging();

// =============================================================================
// CORRECTED DOWMLINE FUNCTIONS
// =============================================================================

exports.getDownline = onCall({ region: "us-central1" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
  }
  const currentUserId = request.auth.uid;

  try {
    const userDoc = await db.collection("users").doc(currentUserId).get();
    if (!userDoc.exists) {
      throw new HttpsError("not-found", "Current user not found in Firestore.");
    }

    const uplineAdmin = userDoc.data().upline_admin;
    if (!uplineAdmin) {
      return { downline: [] };
    }

    const downlineSnapshot = await db.collection("users")
      .where("upline_admin", "==", uplineAdmin)
      .get();

    // Return all users in the team, including the current user (will be filtered on client)
    const downlineUsers = downlineSnapshot.docs.map(doc => doc.data());

    return { downline: downlineUsers };

  } catch (error) {
    console.error("Error in getDownline function:", error);
    throw new HttpsError("internal", "An unexpected error occurred while fetching the downline.");
  }
});

exports.getDownlineCounts = onCall({ region: "us-central1" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
  }
  const currentUserId = request.auth.uid;

  try {
    const userDoc = await db.collection("users").doc(currentUserId).get();
    if (!userDoc.exists) {
      throw new HttpsError("not-found", "Current user not found in Firestore.");
    }

    const uplineAdmin = userDoc.data().upline_admin;
    if (!uplineAdmin) {
      return { counts: { all: 0, last24: 0, last7: 0, last30: 0, newQualified: 0 } };
    }

    const now = new Date();
    const twentyFourHoursAgo = new Date(now.getTime() - (24 * 60 * 60 * 1000));
    const sevenDaysAgo = new Date(now.getTime() - (7 * 24 * 60 * 60 * 1000));
    const thirtyDaysAgo = new Date(now.getTime() - (30 * 24 * 60 * 60 * 1000));

    const teamQuery = db.collection("users").where("upline_admin", "==", uplineAdmin);

    const [
      allSnapshot,
      last24Snapshot,
      last7Snapshot,
      last30Snapshot,
      newQualifiedSnapshot
    ] = await Promise.all([
      teamQuery.count().get(),
      teamQuery.where("createdAt", ">=", twentyFourHoursAgo).count().get(),
      teamQuery.where("createdAt", ">=", sevenDaysAgo).count().get(),
      teamQuery.where("createdAt", ">=", thirtyDaysAgo).count().get(),
      teamQuery.where("isQualified", "==", true).count().get()
    ]);

    const totalTeamCount = allSnapshot.data().count > 0 ? allSnapshot.data().count - 1 : 0;

    const counts = {
      all: totalTeamCount,
      last24: last24Snapshot.data().count,
      last7: last7Snapshot.data().count,
      last30: last30Snapshot.data().count,
      newQualified: newQualifiedSnapshot.data().count,
    };

    return { counts: counts };

  } catch (error) {
    console.error("Error in getDownlineCounts function:", error);
    throw new HttpsError("internal", "An unexpected error occurred while fetching downline counts.");
  }
});

// =============================================================================
// OTHER FUNCTIONS
// =============================================================================

exports.getUserByReferralCode = onRequest({ cors: true }, async (req, res) => {
  const { code } = req.query;
  if (!code) {
    return res.status(400).send("Referral code is required");
  }
  try {
    const snapshot = await db.collection("users").where("referralCode", "==", code).limit(1).get();
    if (snapshot.empty) {
      return res.status(404).send("User not found");
    }
    const user = snapshot.docs[0].data();
    return res.status(200).json(user);
  } catch (error) {
    console.error("Error fetching user by referral code:", error);
    return res.status(500).send("Internal server error");
  }
});

exports.registerUser = onCall(async (request) => {
  // ... (logging and logic from before)
});


exports.checkAdminSubscriptionStatus = onCall(async (request) => {
  // ... (existing logic)
});

exports.sendPushNotification = onCall(async (request) => {
  // ... (existing logic)
});

exports.onNewChatMessage = onDocumentCreated("chats/{chatId}/messages/{messageId}", async (event) => {
  // ... (existing logic)
});

exports.notifyOnQualification = onDocumentUpdated("users/{userId}", async (event) => {
  // ... (existing logic)
});

exports.notifyOnNewSponsorship = onDocumentCreated("users/{userId}", async (event) => {
  // ... (existing logic)
});
const { onCall, HttpsError, onRequest } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { getMessaging } = require("firebase-admin/messaging");
const { v4: uuidv4 } = require("uuid");

// Initialize Firebase Admin SDK once
initializeApp();
const db = getFirestore();
const auth = getAuth();
const messaging = getMessaging();

// =============================================================================
//  HTTP Functions (onRequest)
// =============================================================================

exports.getUserByReferralCode = onRequest(
  { cors: true }, // This handles CORS permissions automatically
  async (req, res) => {
    const { code } = req.query;
    if (!code) {
      return res.status(400).send("Referral code is required");
    }
    try {
      const snapshot = await db
        .collection("users")
        .where("referralCode", "==", code)
        .limit(1)
        .get();
      if (snapshot.empty) {
        return res.status(404).send("User not found");
      }
      const user = snapshot.docs[0].data();
      return res.status(200).json(user);
    } catch (error) {
      console.error("Error fetching user by referral code:", error);
      return res.status(500).send("Internal server error");
    }
  }
);

// =============================================================================
//  Callable Functions (onCall)
// =============================================================================

exports.registerUser = onCall(async (request) => {
  console.log("🚀 registerUser function triggered with data:", request.data);

  const data = request.data;
  if (!data.email || !data.password || !data.firstName) {
    console.error("❌ Missing required user information.");
    throw new HttpsError("invalid-argument", "Missing required user information.");
  }
  const { email, password, firstName, lastName, country, state, city, referralCode: sponsorReferralCode } = data;

  let sponsor = null;
  let sponsorId = null;
  let uplineAdmin = null;
  let level = 1;
  const uplineRefs = [];

  try {
    if (sponsorReferralCode) {
      console.log(`🔍 Searching for sponsor with referral code: ${sponsorReferralCode}`);
      const sponsorQuery = await db.collection("users").where("referralCode", "==", sponsorReferralCode).limit(1).get();
      if (sponsorQuery.empty) {
        console.error(`❌ Sponsor with referral code ${sponsorReferralCode} not found.`);
        throw new HttpsError("not-found", "The provided referral code is not valid.");
      }
      const sponsorDoc = sponsorQuery.docs[0];
      sponsor = sponsorDoc.data();
      sponsorId = sponsorDoc.id;
      console.log(`✅ Found sponsor: ${sponsor.firstName}, ID: ${sponsorId}`);

      uplineAdmin = sponsor.upline_admin;
      level = (sponsor.level || 0) + 1; // Default level to 0 if not present
      console.log(`Sponsor level: ${sponsor.level}, New user level: ${level}, Upline Admin: ${uplineAdmin}`);

      if (Array.isArray(sponsor.upline_refs)) {
        uplineRefs.push(...sponsor.upline_refs);
      }
      uplineRefs.push(sponsorId);
      console.log("⛓️ New upline chain:", uplineRefs);
    }

    console.log(`🔒 Creating Auth user for: ${email}`);
    const userRecord = await auth.createUser({ email, password, displayName: `${firstName} ${lastName}` });
    const newUserId = userRecord.uid;
    console.log(`✅ Auth user created with UID: ${newUserId}`);

    if (!sponsor) {
      uplineAdmin = newUserId;
      console.log(`🚩 This is an Admin registration. Setting upline_admin to self: ${uplineAdmin}`);
    }

    const referralCode = uuidv4().substring(0, 8).toUpperCase();
    console.log(`🔑 Generated new referral code: ${referralCode}`);

    const newUserDoc = {
      firstName,
      lastName,
      email,
      country,
      state,
      city,
      referralCode,
      referredBy: sponsorReferralCode || null,
      sponsor_id: sponsorId,
      upline_admin: uplineAdmin,
      level,
      upline_refs: uplineRefs,
      createdAt: FieldValue.serverTimestamp(),
    };

    console.log(`✍️ Creating Firestore document for user: ${newUserId}`);
    console.log("Firestore document data:", JSON.stringify(newUserDoc, null, 2));
    await db.collection("users").doc(newUserId).set(newUserDoc);
    console.log("✅ Firestore document created successfully.");

    return { success: true, userId: newUserId };

  } catch (error) {
    console.error("🔥 CRITICAL ERROR in registerUser function:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", "An unexpected internal error occurred. Please check the function logs.");
  }
});


exports.checkAdminSubscriptionStatus = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in to check subscription status.");
  }
  const adminId = request.auth.uid;
  try {
    const subscriptionDoc = await db.collection("subscriptions").doc(adminId).get();
    if (subscriptionDoc.exists && subscriptionDoc.data().status === "active") {
      return { isActive: true };
    }
    return { isActive: false };
  } catch (error) {
    console.error("Error checking subscription status:", error);
    throw new HttpsError("internal", "Could not check subscription status.");
  }
});

exports.sendPushNotification = onCall(async (request) => {
  const { recipientId, title, body } = request.data;
  if (!recipientId || !title || !body) {
    throw new HttpsError("invalid-argument", "Missing required notification data.");
  }
  try {
    const userDoc = await db.collection("users").doc(recipientId).get();
    const fcmToken = userDoc.data()?.fcmToken;
    if (fcmToken) {
      const message = {
        notification: { title, body },
        token: fcmToken,
      };
      await messaging.send(message);
      return { success: true };
    }
    return { success: false, reason: "FCM token not found for user." };
  } catch (error) {
    console.error("Error sending push notification:", error);
    throw new HttpsError("internal", "Failed to send notification.");
  }
});

// =============================================================================
//  Firestore Trigger Functions (onDocument...)
// =============================================================================

exports.onNewChatMessage = onDocumentCreated("chats/{chatId}/messages/{messageId}", async (event) => {
  const messageData = event.data.data();
  const chatId = event.params.chatId;

  try {
    const chatDoc = await db.collection("chats").doc(chatId).get();
    const chatMembers = chatDoc.data().members;

    const senderId = messageData.senderId;
    const senderName = messageData.senderName;
    const messageText = messageData.text;

    const recipientIds = chatMembers.filter((id) => id !== senderId);

    for (const recipientId of recipientIds) {
      const userDoc = await db.collection("users").doc(recipientId).get();
      const fcmToken = userDoc.data()?.fcmToken;

      if (fcmToken) {
        const message = {
          notification: {
            title: `New message from ${senderName}`,
            body: messageText,
          },
          token: fcmToken,
          data: { chatId },
        };
        await messaging.send(message);
      }
    }
  } catch (error) {
    console.error(`❌ Error in onNewChatMessage for chat ${chatId}:`, error);
  }
});

exports.notifyOnQualification = onDocumentUpdated("users/{userId}", async (event) => {
  const beforeData = event.data.before.data();
  const afterData = event.data.after.data();
  const userId = event.params.userId;

  const wasQualified = beforeData.isQualified || false;
  const isQualified = afterData.isQualified || false;

  if (!wasQualified && isQualified) {
    try {
      const adminId = afterData.upline_admin;
      const adminSettingsDoc = await db.collection("admin_settings").doc(adminId).get();
      const bizName = adminSettingsDoc.data()?.bizName || "the new opportunity";

      const notificationContent = {
        title: `Congratulations, ${afterData.firstName}!`,
        message: `You are now qualified to join ${bizName}.`,
        createdAt: FieldValue.serverTimestamp(), read: false,
      };
      await db.collection("users").doc(userId).collection("notifications").add(notificationContent);
    } catch (error) {
      console.error(`❌ Error creating qualification notification for ${userId}:`, error);
    }
  }
});

exports.notifyOnNewSponsorship = onDocumentCreated("users/{userId}", async (event) => {
  const snap = event.data;
  if (!snap) return;

  const newUser = snap.data();
  if (!newUser.referredBy) return;

  try {
    const sponsorQuery = await db.collection("users").where("referralCode", "==", newUser.referredBy).limit(1).get();
    if (sponsorQuery.empty) return;

    const sponsorDoc = sponsorQuery.docs[0];
    const sponsor = sponsorDoc.data();
    const sponsorId = sponsorDoc.id;

    const newUserLocation = `${newUser.city || ""}, ${newUser.state || ""}${newUser.country ? ` - ${newUser.country}` : ""}`;
    const notificationContent = {
      title: "🎉 You have a new Team Member!",
      message: `Congratulations, ${sponsor.firstName}! You sponsored ${newUser.firstName} ${newUser.lastName} from ${newUserLocation}.`,
      createdAt: FieldValue.serverTimestamp(), read: false,
    };
    await db.collection("users").doc(sponsorId).collection("notifications").add(notificationContent);
  } catch (error) {
    console.error(`❌ Error creating sponsorship notification for user ${snap.id}:`, error);
  }
});
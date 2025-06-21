const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { getMessaging } = require("firebase-admin/messaging");

// Initialize Firebase Admin SDK
initializeApp();
const db = getFirestore();
const auth = getAuth();
const messaging = getMessaging();

/**
 * Recursively converts Firestore Timestamp objects in a data structure to ISO strings.
 * This is crucial for sending data to a client that expects JSON.
 * @param {any} data The data to serialize.
 * @returns {any} The serialized data.
 */
const serializeTimestamps = (data) => {
  if (data === null || data === undefined) {
    return data;
  }
  if (data.toDate && typeof data.toDate === "function") {
    return data.toDate().toISOString();
  }
  if (Array.isArray(data)) {
    return data.map(serializeTimestamps);
  }
  if (typeof data === "object") {
    const newData = {};
    for (const key in data) {
      if (Object.prototype.hasOwnProperty.call(data, key)) {
        newData[key] = serializeTimestamps(data[key]);
      }
    }
    return newData;
  }
  return data;
};


/**
 * Registers a new user, creating both a Firebase Auth user and a Firestore user document.
 * This function correctly builds the `upline_refs` array for the new user.
 */
exports.registerUser = onCall({ region: "us-central1" }, async (request) => {
  const {
    email,
    password,
    firstName,
    lastName,
    sponsorReferralCode
  } = request.data;

  if (!email || !password || !firstName || !lastName) {
    throw new HttpsError("invalid-argument", "Missing required user information.");
  }

  let sponsorId = null;
  let sponsorRefs = [];
  let level = 1;

  // 1. Find the sponsor if a referral code is provided
  if (sponsorReferralCode) {
    const sponsorQuery = await db.collection("users").where("referralCode", "==", sponsorReferralCode).limit(1).get();
    if (!sponsorQuery.empty) {
      const sponsorDoc = sponsorQuery.docs[0];
      sponsorId = sponsorDoc.id;
      const sponsorData = sponsorDoc.data();
      sponsorRefs = sponsorData.upline_refs || [];
      level = sponsorData.level ? sponsorData.level + 1 : 2;
    } else {
      console.warn(`Sponsor with referral code '${sponsorReferralCode}' not found.`);
    }
  }

  try {
    // 2. Create the Firebase Auth user
    const userRecord = await auth.createUser({
      email: email,
      password: password,
      displayName: `${firstName} ${lastName}`,
    });
    const uid = userRecord.uid;

    // 3. Prepare the new user's data for Firestore
    const newUser = {
      uid: uid,
      email: email,
      firstName: firstName,
      lastName: lastName,
      createdAt: FieldValue.serverTimestamp(),
      role: "user", // Assign a default role
      referralCode: `${firstName.toLowerCase()}${Math.floor(1000 + Math.random() * 9000)}`, // Generate a simple referral code
      referredBy: sponsorId,
      level: level,
      // Ancestor Array: Copy sponsor's refs and add sponsor's ID
      upline_refs: sponsorId ? [...sponsorRefs, sponsorId] : [],
      // Initialize other fields with default values
      directSponsorCount: 0,
      totalTeamCount: 0,
    };

    // 4. Create the user document in Firestore
    await db.collection("users").doc(uid).set(newUser);

    // 5. [Optional] Update sponsor's direct sponsor count
    if (sponsorId) {
      await db.collection("users").doc(sponsorId).update({
        directSponsorCount: FieldValue.increment(1)
      });
    }

    return {
      success: true,
      uid: uid
    };
  } catch (error) {
    console.error("Error registering user:", error);
    // If Firestore write fails after Auth user is created, you might want to delete the Auth user.
    if (error.code.startsWith("auth/")) {
      throw new HttpsError("aborted", `Auth error: ${error.message}`);
    }
    throw new HttpsError("internal", "An error occurred while creating the user.");
  }
});

/**
 * Fetches all users in the authenticated user's downline.
 * Uses the `upline_refs` field for efficient querying.
 */
exports.getDownline = onCall({ region: "us-central1" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
  }
  const currentUserId = request.auth.uid;

  try {
    // Query for all users who have the current user in their `upline_refs` array.
    const downlineSnapshot = await db.collection("users")
      .where("upline_refs", "array-contains", currentUserId)
      .get();

    if (downlineSnapshot.empty) {
      return { downline: [] };
    }

    const downlineUsers = downlineSnapshot.docs.map(doc => doc.data());

    // Serialize data to ensure Timestamps are handled correctly.
    const serializedDownline = serializeTimestamps(downlineUsers);

    return { downline: serializedDownline };

  } catch (error) {
    console.error("Error in getDownline function:", error);
    throw new HttpsError("internal", "An unexpected error occurred while fetching the downline.");
  }
});


/**
 * THE FIX: This is the complete and correct version of the function.
 * It now includes proper error handling and logging.
 * This function REQUIRES the composite indexes defined in Step 2 to work.
 */
exports.getDownlineCounts = onCall({ region: "us-central1" }, async (request) => {
  if (!request.auth) {
    console.error("Authentication check failed. No user is authenticated.");
    throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
  }
  const currentUserId = request.auth.uid;
  console.log(`Fetching downline counts for user: ${currentUserId}`);

  try {
    const now = new Date();
    const twentyFourHoursAgo = new Date(now.getTime() - (24 * 60 * 60 * 1000));
    const sevenDaysAgo = new Date(now.getTime() - (7 * 24 * 60 * 60 * 1000));
    const thirtyDaysAgo = new Date(now.getTime() - (30 * 24 * 60 * 60 * 1000));

    // Base query for the user's downline
    const teamQuery = db.collection("users").where("upline_refs", "array-contains", currentUserId);

    // Perform all count queries in parallel.
    // These queries will fail without the correct composite indexes.
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
      teamQuery.where("qualifiedDate", "!=", null).count().get()
    ]);

    const counts = {
      all: allSnapshot.data().count,
      last24: last24Snapshot.data().count,
      last7: last7Snapshot.data().count,
      last30: last30Snapshot.data().count,
      newQualified: newQualifiedSnapshot.data().count,
    };

    // Log the successful result before sending it.
    console.log(`Successfully calculated counts for ${currentUserId}:`, counts);
    return { counts };

  } catch (error) {
    // Log the detailed error to Firebase Functions logs for debugging.
    console.error(`CRITICAL ERROR in getDownlineCounts for user ${currentUserId}:`, error);
    // Re-throw the error so the client knows the operation failed.
    throw new HttpsError("internal", `An unexpected error occurred while fetching downline counts. Details: ${error.message}`);
  }
});


// --- Other functions (unchanged) ---

exports.checkAdminSubscriptionStatus = onCall(async (request) => {
  const db = getFirestore();
  const { uid } = request.data;
  const adminRef = db.collection("admins").doc(uid);
  try {
    const doc = await adminRef.get();
    if (doc.exists && doc.data().isSubscribed) {
      return { isSubscribed: true };
    }
    return { isSubscribed: false };
  } catch (error) {
    console.error("Error checking subscription status:", error);
    throw new HttpsError("internal", "Could not check subscription status.");
  }
});

exports.sendPushNotification = onDocumentCreated("users/{userId}/notifications/{notificationId}", async (event) => {
  const messaging = getMessaging();
  const db = getFirestore();
  const snap = event.data;
  if (!snap) {
    console.log("No data associated with the event");
    return;
  }
  const userId = event.params.userId;
  const notificationData = snap.data();
  const userDoc = await db.collection("users").doc(userId).get();
  if (!userDoc.exists) {
    console.error(`❌ User document for ${userId} does not exist.`);
    return;
  }
  const fcmToken = userDoc.data()?.fcm_token;
  if (!fcmToken) {
    console.log(`❌ Missing FCM token for user ${userId}. Skipping push.`);
    return;
  }
  const message = {
    token: fcmToken,
    notification: {
      title: notificationData?.title || "New Notification",
      body: notificationData?.message || "You have a new message.",
    },
    android: { notification: { sound: "default" } },
    apns: { payload: { aps: { sound: "default" } } },
  };
  try {
    const response = await messaging.send(message);
    console.log(`✅ FCM push sent to user ${userId}:`, response);
  } catch (error) {
    console.error(`❌ Failed to send FCM push to user ${userId}:`, error);
  }
});

exports.onNewChatMessage = onDocumentCreated("messages/{threadId}/chat/{messageId}", async (event) => {
  const db = getFirestore();
  const snap = event.data;
  if (!snap) return;
  const message = snap.data();
  const threadId = event.params.threadId;
  const senderId = message.senderId;
  const threadRef = db.collection("messages").doc(threadId);
  try {
    const threadDoc = await threadRef.get();
    if (!threadDoc.exists) return;
    const threadData = threadDoc.data();
    const recipients = (threadData.allowedUsers || []).filter((uid) => uid !== senderId);
    if (recipients.length === 0) return;
    await threadRef.update({
      usersWithUnread: FieldValue.arrayUnion(...recipients),
      lastMessage: message.text || "",
      lastMessageSenderId: senderId,
      lastUpdatedAt: message.timestamp || FieldValue.serverTimestamp(),
    });
    const senderDoc = await db.collection("users").doc(senderId).get();
    if (!senderDoc.exists) return;
    const senderName = `${senderDoc.data().firstName} ${senderDoc.data().lastName}`;
    const notificationContent = {
      title: `💬 You have a new message!`,
      message: `From: ${senderName}`,
      createdAt: FieldValue.serverTimestamp(), read: false,
    };
    await db.collection("users").doc(recipients[0]).collection("notifications").add(notificationContent);
  } catch (error) {
    console.error(`❌ Error in onNewChatMessage for thread ${threadId}:`, error);
  }
});

exports.notifyOnQualification = onDocumentUpdated("users/{userId}", async (event) => {
  const db = getFirestore();
  const beforeData = event.data?.before.data();
  const afterData = event.data?.after.data();
  if (!beforeData || !afterData) return;
  const userId = event.params.userId;
  const DIRECT_SPONSOR_MIN = 4;
  const TOTAL_TEAM_MIN = 20;

  const wasQualified = !!beforeData.qualifiedDate;
  const isNowQualified = (afterData.directSponsorCount >= DIRECT_SPONSOR_MIN) && (afterData.totalTeamCount >= TOTAL_TEAM_MIN);

  if (!wasQualified && isNowQualified) {
    try {
      await event.data.after.ref.update({
        qualifiedDate: FieldValue.serverTimestamp(),
      });

      let bizName = "the business opportunity";
      if (afterData.uplineAdmin) {
        const adminSettingsDoc = await db.collection("admin_settings").doc(afterData.uplineAdmin).get();
        if (adminSettingsDoc.exists && adminSettingsDoc.data().biz_opp) {
          bizName = adminSettingsDoc.data().biz_opp;
        }
      }
      const notificationContent = {
        title: `🏆 Congratulations, ${afterData.firstName}!`,
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
  const db = getFirestore();
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
    console.error(`❌ Error creating sponsorship notification:`, error);
  }
});
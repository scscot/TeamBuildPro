const { onCall, HttpsError, onRequest } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { getMessaging } = require("firebase-admin/messaging");
const { v4: uuidv4 } = require("uuid");

// Initialize Firebase Admin SDK once
initializeApp();

// =============================================================================
// NEW DOWMLINE FUNCTIONS (Ancestor Array Model)
// =============================================================================

exports.getDownline = onCall({ region: "us-central1" }, async (request) => {
  const db = getFirestore();
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
  }
  const userId = request.auth.uid;
  try {
    const downlineSnapshot = await db.collection("users")
      .where("upline_refs", "array-contains", userId)
      .get();

    const downlineUsers = downlineSnapshot.docs.map(doc => {
      const userData = doc.data();
      const userWithUid = { uid: doc.id, ...userData };
      // Securely serialize data, converting Timestamps to strings for client compatibility
      return {
        ...userWithUid,
        createdAt: userWithUid.createdAt?.toDate().toISOString(),
        joined: userWithUid.joined?.toDate().toISOString(),
        qualifiedDate: userWithUid.qualifiedDate?.toDate().toISOString(),
        bizVisitDate: userWithUid.bizVisitDate?.toDate().toISOString(),
      };
    });

    return { downline: downlineUsers };

  } catch (error) {
    console.error("Error in getDownline function:", error);
    throw new HttpsError("internal", "An unexpected error occurred while fetching the downline. Ensure Firestore indexes are built.");
  }
});

exports.getDownlineCounts = onCall({ region: "us-central1" }, async (request) => {
  const db = getFirestore();
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
  }
  const userId = request.auth.uid;
  try {
    const now = new Date();
    const twentyFourHoursAgo = new Date(now.getTime() - (24 * 60 * 60 * 1000));
    const sevenDaysAgo = new Date(now.getTime() - (7 * 24 * 60 * 60 * 1000));
    const thirtyDaysAgo = new Date(now.getTime() - (30 * 24 * 60 * 60 * 1000));

    // CORRECTED: Each query is now built from the base collection reference.
    const baseQuery = db.collection("users").where("upline_refs", "array-contains", userId);

    const [
      allSnapshot,
      last24Snapshot,
      last7Snapshot,
      last30Snapshot,
      newQualifiedSnapshot
    ] = await Promise.all([
      baseQuery.count().get(),
      baseQuery.where("createdAt", ">=", twentyFourHoursAgo).count().get(),
      baseQuery.where("createdAt", ">=", sevenDaysAgo).count().get(),
      baseQuery.where("createdAt", ">=", thirtyDaysAgo).count().get(),
      baseQuery.where("isQualified", "==", true).count().get()
    ]);

    const counts = {
      all: allSnapshot.data().count,
      last24: last24Snapshot.data().count,
      last7: last7Snapshot.data().count,
      last30: last30Snapshot.data().count,
      newQualified: newQualifiedSnapshot.data().count,
    };

    return { counts: counts };

  } catch (error) {
    console.error("Error in getDownlineCounts function:", error);
    throw new HttpsError("internal", "An unexpected error occurred while fetching downline counts. Ensure Firestore indexes are built.");
  }
});


// =============================================================================
// All OTHER FUNCTIONS from your original file
// =============================================================================

exports.registerUser = onCall(async (request) => {
  // This is the version from your uploaded file, revised for the new model
  const db = getFirestore();
  const auth = getAuth();
  const data = request.data;
  if (!data.email || !data.password || !data.firstName) {
    throw new HttpsError("invalid-argument", "Missing required user information.");
  }
  const { email, password, firstName, lastName, country, state, city, referralCode: sponsorReferralCode } = data;
  let sponsorData = null, sponsorId = null, uplineAdmin = null, level = 1;
  const uplineRefs = [];

  if (sponsorReferralCode) {
    const sponsorQuery = await db.collection("users").where("referralCode", "==", sponsorReferralCode).limit(1).get();
    if (sponsorQuery.empty) {
      throw new HttpsError("not-found", "The provided referral code is not valid.");
    }
    const sponsorDoc = sponsorQuery.docs[0];
    sponsorData = sponsorDoc.data();
    sponsorId = sponsorDoc.id;
    level = (sponsorData.level || 0) + 1;
    uplineAdmin = sponsorData.uplineAdmin;

    if (Array.isArray(sponsorData.upline_refs)) {
      uplineRefs.push(...sponsorData.upline_refs);
    }
    uplineRefs.push(sponsorId);
  }

  let userRecord;
  try {
    userRecord = await auth.createUser({ email, password, displayName: `${firstName} ${lastName}` });
  } catch (error) {
    if (error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "This email address is already in use.");
    }
    console.error("Error creating auth user:", error);
    throw new HttpsError("internal", "Error creating account.");
  }

  const newUserUid = userRecord.uid;
  if (!uplineAdmin) {
    uplineAdmin = newUserUid;
  }
  const newReferralCode = uuidv4().substring(0, 6).toUpperCase();
  const newUserDocData = {
    uid: newUserUid, firstName, lastName, email, country, state, city,
    referralCode: newReferralCode,
    referredBy: sponsorReferralCode || null,
    level,
    directSponsorCount: 0,
    totalTeamCount: 0,
    role: sponsorData ? "user" : "admin",
    uplineAdmin,
    createdAt: FieldValue.serverTimestamp(),
    isUpgraded: false,
    photoUrl: "",
    downlineIds: [],
    upline_refs: uplineRefs
  };
  try {
    await db.collection("users").doc(newUserUid).set(newUserDocData);
  } catch (error) {
    await auth.deleteUser(newUserUid);
    console.error("🔥 User registration transaction failed, rolling back auth user:", error);
    throw new HttpsError("internal", "Error saving user data.");
  }
  return { status: "success", uid: newUserUid };
});

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
      createdAt: FieldValue.serverTimestamp(),
      read: false,
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
  const DIRECT_SPONSOR_MIN = 5;
  const TOTAL_TEAM_MIN = 20;
  const wasQualified = (beforeData.directSponsorCount >= DIRECT_SPONSOR_MIN) && (beforeData.totalTeamCount >= TOTAL_TEAM_MIN);
  const isNowQualified = (afterData.directSponsorCount >= DIRECT_SPONSOR_MIN) && (afterData.totalTeamCount >= TOTAL_TEAM_MIN);
  if (!wasQualified && isNowQualified) {
    try {
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
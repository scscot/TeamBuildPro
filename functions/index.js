const { onCall, HttpsError } = require("firebase-functions/v2/https");
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
//  Callable Functions (onCall)
// =============================================================================

exports.registerUser = onCall(async (request) => {
  const data = request.data;
  if (!data.email || !data.password || !data.firstName) {
    throw new HttpsError("invalid-argument", "Missing required user information.");
  }
  const { email, password, firstName, lastName, country, state, city, referralCode: sponsorReferralCode } = data;

  let sponsor = null;
  let sponsorId = null;
  let uplineAdmin = null;
  let level = 1;
  const uplineRefs = [];

  if (sponsorReferralCode) {
    const sponsorQuery = await db.collection("users").where("referralCode", "==", sponsorReferralCode).limit(1).get();
    if (sponsorQuery.empty) {
      throw new HttpsError("not-found", "The provided referral code is not valid.");
    }
    const sponsorDoc = sponsorQuery.docs[0];
    sponsor = sponsorDoc.data();
    sponsorId = sponsorDoc.id;
    level = (sponsor.level || 0) + 1;
    uplineAdmin = sponsor.role === "admin" ? sponsor.uid : sponsor.uplineAdmin;
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
    referralCode: newReferralCode, referredBy: sponsorReferralCode || null,
    level, directSponsorCount: 0, totalTeamCount: 0,
    role: sponsor ? "user" : "admin", uplineAdmin,
    createdAt: FieldValue.serverTimestamp(),
    isUpgraded: false, photoUrl: "", downlineIds: [],
  };

  try {
    await db.runTransaction(async (transaction) => {
      const newUserRef = db.collection("users").doc(newUserUid);
      transaction.set(newUserRef, newUserDocData);
      if (sponsorId) {
        let currentSponsorId = sponsorId;
        while (currentSponsorId) {
          const sponsorRef = db.collection("users").doc(currentSponsorId);
          uplineRefs.push(sponsorRef);
          const parentDoc = await transaction.get(sponsorRef);
          if (!parentDoc.exists) break;
          const parentData = parentDoc.data();
          if (parentData.referredBy) {
            const nextSponsorQuery = await db.collection("users").where("referralCode", "==", parentData.referredBy).limit(1).get();
            currentSponsorId = nextSponsorQuery.empty ? null : nextSponsorQuery.docs[0].id;
          } else {
            currentSponsorId = null;
          }
        }
      }
      if (uplineRefs.length > 0) {
        transaction.update(uplineRefs[0], { directSponsorCount: FieldValue.increment(1) });
        for (const uplineRef of uplineRefs) {
          transaction.update(uplineRef, {
            totalTeamCount: FieldValue.increment(1),
            downlineIds: FieldValue.arrayUnion(newUserUid),
          });
        }
      }
    });
  } catch (error) {
    await auth.deleteUser(newUserUid);
    console.error("🔥 User registration transaction failed, rolling back auth user:", error);
    throw new HttpsError("internal", "Error saving user data.");
  }

  return { status: "success", uid: newUserUid };
});

exports.checkAdminSubscriptionStatus = onCall(async (request) => {
  const { uid } = request.data;
  // ... (rest of the function logic remains the same)
});

// HTTP-triggered functions are not included in this boilerplate
// as they are defined differently in v2. We can add them back if needed.

// =============================================================================
//  Firestore-Triggered Functions
// =============================================================================

exports.sendPushNotification = onDocumentCreated("users/{userId}/notifications/{notificationId}", async (event) => {
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
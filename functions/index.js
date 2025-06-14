const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { v4: uuidv4 } = require("uuid"); // Import the uuid package

// Initialize Firebase Admin SDK once for all functions
admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();
const { getFirestore, FieldValue } = require("firebase-admin/firestore");


// =============================================================================
//  Callable Functions (onCall) - Recommended for Client-Side Calls
// =============================================================================

/**
 * @description Securely registers a new user, creates their auth & DB records,
 * generates a referral code, and atomically updates the entire upline.
 * @param {object} data - The user's registration details from the client.
 * @param {object} context - Authentication context.
 * @returns {object} The status of the operation and new user's UID.
 */
exports.registerUser = functions.https.onCall(async (data, context) => {
  // --- Data Validation ---
  if (!data.email || !data.password || !data.firstName) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing required user information (email, password, firstName).",
    );
  }

  const {
    email, password, firstName, lastName, country, state, city,
    referralCode: sponsorReferralCode,
  } = data;

  let sponsor = null;
  let sponsorId = null;
  let uplineAdmin = null;
  let level = 1;
  const uplineRefs = [];

  // --- 1. Get Sponsor Information (if a referral code was provided) ---
  if (sponsorReferralCode) {
    const sponsorQuery = await db.collection("users")
      .where("referralCode", "==", sponsorReferralCode).limit(1).get();
    if (sponsorQuery.empty) {
      throw new functions.https.HttpsError("not-found", "The provided referral code is not valid.");
    }
    const sponsorDoc = sponsorQuery.docs[0];
    sponsor = sponsorDoc.data();
    sponsorId = sponsorDoc.id;
    level = (sponsor.level || 0) + 1;
    uplineAdmin = sponsor.role === "admin" ? sponsor.uid : sponsor.uplineAdmin;
  }

  // --- 2. Create the User in Firebase Authentication ---
  let userRecord;
  try {
    userRecord = await admin.auth().createUser({
      email, password, displayName: `${firstName} ${lastName}`,
    });
  } catch (error) {
    if (error.code === "auth/email-already-exists") {
      throw new functions.https.HttpsError("already-exists", "This email address is already in use by another account.");
    }
    console.error("Error creating auth user:", error);
    throw new functions.https.HttpsError("internal", "An error occurred while creating your account.");
  }

  const newUserUid = userRecord.uid;
  if (!uplineAdmin) {
    uplineAdmin = newUserUid;
  }

  // --- 3. Generate a Unique Referral Code for the New User ---
  const newReferralCode = uuidv4().substring(0, 6).toUpperCase();

  // --- 4. Prepare the New User's Firestore Document ---
  const newUserDocData = {
    uid: newUserUid, firstName, lastName, email, country, state, city,
    referralCode: newReferralCode,
    referredBy: sponsorReferralCode || null,
    level,
    directSponsorCount: 0,
    totalTeamCount: 0,
    role: sponsor ? "user" : "admin",
    uplineAdmin,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    isUpgraded: false,
    photoUrl: "",
    downlineIds: [],
  };

  // --- 5. Create User and Update Upline Atomically Using a Transaction ---
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
        transaction.update(uplineRefs[0], { directSponsorCount: admin.firestore.FieldValue.increment(1) });

        for (const uplineRef of uplineRefs) {
          transaction.update(uplineRef, {
            totalTeamCount: admin.firestore.FieldValue.increment(1),
            downlineIds: admin.firestore.FieldValue.arrayUnion(newUserUid),
          });
        }
      }
    });
  } catch (error) {
    await admin.auth().deleteUser(newUserUid);
    console.error("🔥 User registration transaction failed, rolling back auth user:", error);
    throw new functions.https.HttpsError("internal", "A server error occurred while saving user data. Your account was not created.");
  }

  return { status: "success", uid: newUserUid };
});


/**
 * @description Checks an admin user's subscription or trial status.
 * @param {object} request.data - Contains the UID of the admin to check.
 * @returns {object} The subscription status.
 */
exports.checkAdminSubscriptionStatus = functions.https.onCall(async (request) => {
  const { uid } = request.data;
  if (!uid) {
    throw new functions.https.HttpsError('invalid-argument', 'User ID is required.');
  }

  try {
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User not found.');
    }

    const userData = userDoc.data();
    const role = userData.role || 'user';
    if (role !== 'admin') {
      return { isActive: true, role: 'user', daysRemaining: 0, trialExpired: true, message: "User is not an admin, subscription status does not apply." };
    }

    const now = new Date();
    const trialStart = userData.trialStartAt?.toDate?.() ?? null;
    const subscriptionExpiresAt = userData.subscriptionExpiresAt?.toDate?.() ?? null;

    let isActive = false;
    let trialExpired = true;
    let daysRemaining = 0;
    let statusMessage = "Inactive";

    if (subscriptionExpiresAt && subscriptionExpiresAt > now) {
      isActive = true;
      daysRemaining = Math.ceil((subscriptionExpiresAt - now) / (1000 * 60 * 60 * 24));
      statusMessage = "Active Subscription";
    } else if (trialStart) {
      const trialEnd = new Date(trialStart);
      trialEnd.setDate(trialEnd.getDate() + 30);
      if (trialEnd > now) {
        isActive = true;
        daysRemaining = Math.ceil((trialEnd - now) / (1000 * 60 * 60 * 24));
        trialExpired = false;
        statusMessage = "Active Trial";
      } else {
        statusMessage = "Trial Expired";
      }
    } else {
      statusMessage = "No Subscription or Trial";
    }

    return {
      isActive,
      daysRemaining,
      trialExpired,
      role: 'admin',
      statusMessage,
    };
  } catch (error) {
    console.error('❌ Error in checkAdminSubscriptionStatus:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to verify subscription status.', error.message);
  }
});


// =============================================================================
//  HTTP-Triggered Functions (Public Endpoints)
// =============================================================================

/**
 * @description Gets public sponsor data by their referral code for pre-registration UI.
 * @param {string} req.query.code - The referral code of the sponsor.
 * @returns {object} Public user data or an error.
 */
exports.getUserByReferralCode = functions.https.onRequest(async (req, res) => {
  try {
    const { code } = req.query;
    if (!code) {
      return res.status(400).json({ error: 'Missing referral code' });
    }

    const snapshot = await db.collection('users')
      .where('referralCode', '==', code)
      .limit(1)
      .get();

    if (snapshot.empty) {
      return res.status(404).json({ error: 'User not found' });
    }

    const doc = snapshot.docs[0];
    const data = doc.data();

    return res.status(200).json({
      uid: doc.id,
      firstName: data.firstName || '',
      lastName: data.lastName || '',
      upline_admin: data.uplineAdmin || null,
    });
  } catch (err) {
    console.error('🔥 Error in getUserByReferralCode:', err);
    return res.status(500).json({ error: 'Internal server error', details: err.message });
  }
});


/**
 * @description Gets the list of allowed countries from an admin's settings for registration UI.
 * @param {string} req.query.uid - The UID of the admin.
 * @returns {object} An object containing the list of countries or an error.
 */
exports.getCountriesByAdminUid = functions.https.onRequest(async (req, res) => {
  try {
    const { uid } = req.query;
    if (!uid) {
      return res.status(400).json({ error: 'Missing admin UID' });
    }

    // UPDATED: This should fetch from admin_settings, not the user document
    const doc = await db.collection('admin_settings').doc(uid).get();
    if (!doc.exists) {
      return res.status(404).json({ error: 'Admin settings not found' });
    }
    const data = doc.data();

    if (!Array.isArray(data.countries)) {
      return res.status(404).json({ error: 'Countries array not found or invalid' });
    }

    return res.status(200).json({ countries: data.countries });
  } catch (err) {
    console.error('🔥 Error in getCountriesByAdminUid:', err);
    return res.status(500).json({ error: 'Internal server error', details: err.message });
  }
});


// =============================================================================
//  Firestore-Triggered Functions
// =============================================================================

/**
 * @description Sends a push notification when a new document is created
 * in any user's 'notifications' subcollection.
 */
exports.sendPushNotification = functions.firestore
  .document("users/{userId}/notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    const userId = context.params.userId;
    const notificationData = snap.data();

    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      console.error(`❌ User document for ${userId} does not exist.`);
      return null;
    }

    const fcmToken = userDoc.data()?.fcm_token;
    if (!fcmToken) {
      console.log(`❌ Missing FCM token for user ${userId}. Skipping push.`);
      return null;
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
    return null;
  });
// 🔐 Enhanced Cloud Function Logic for Secure Sponsor Updates & Auto-Invitations

const { onRequest } = require("firebase-functions/v2/https");
const { onCall } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp, applicationDefault } = require("firebase-admin/app"); // Import applicationDefault
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging"); // Import getMessaging
// No need for 'functions' and 'admin' imports if using v2 and specific service imports
// const functions = require("firebase-functions");
// const admin = require("firebase-admin");

// Initialize Firebase Admin SDK once for all functions
// Using applicationDefault() is best practice for automatic credential loading
initializeApp({
  credential: applicationDefault(),
});
const db = getFirestore();
const messaging = getMessaging(); // Use getMessaging() for v2 functions

// ---
// ## HTTP Functions (onRequest)
// ---

// 🔹 SAFE: Public sponsor data only
exports.getUserByReferralCode = onRequest(async (req, res) => {
  try {
    const { code } = req.query; // Destructure for cleaner access
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

    // Use a helper function for consistent response structure and default values
    return res.status(200).json({
      uid: doc.id,
      firstName: data.firstName || '',
      lastName: data.lastName || '',
      upline_admin: data.upline_admin || null,
    });
  } catch (err) {
    console.error('🔥 Error in getUserByReferralCode:', err);
    return res.status(500).json({ error: 'Internal server error', details: err.message }); // Include error message for debugging
  }
});

// 🔹 Get countries[] from upline admin UID
exports.getCountriesByAdminUid = onRequest(async (req, res) => {
  try {
    const { uid } = req.query;
    if (!uid) {
      return res.status(400).json({ error: 'Missing admin UID' });
    }

    const doc = await db.collection('users').doc(uid).get();
    if (!doc.exists) {
      return res.status(404).json({ error: 'Admin user not found' });
    }

    const data = doc.data();

    if (data.role !== 'admin') {
      return res.status(403).json({ error: 'User is not an Admin' });
    }

    // Check for 'countries' array existence directly
    if (!Array.isArray(data.countries)) {
      return res.status(404).json({ error: 'Countries array not found or invalid' }); // More specific error message
    }

    return res.status(200).json({ countries: data.countries });
  } catch (err) {
    console.error('🔥 Error in getCountriesByAdminUid:', err);
    return res.status(500).json({ error: 'Internal server error', details: err.message });
  }
});

// 🔐 Securely increment sponsor counts and auto-qualify upline
exports.incrementSponsorCounts = onRequest(async (req, res) => {
  if (req.method !== 'POST') { // Enforce POST method
    return res.status(405).json({ error: 'Method Not Allowed', message: 'Only POST requests are accepted.' });
  }

  try {
    const { referralCode } = req.body;
    if (!referralCode) {
      return res.status(400).json({ error: 'Missing referral code' });
    }

    const refSnapshot = await db.collection('users')
      .where('referralCode', '==', referralCode)
      .limit(1)
      .get();

    if (refSnapshot.empty) {
      return res.status(404).json({ error: 'Sponsor not found' });
    }

    const sponsorDoc = refSnapshot.docs[0];
    const sponsorId = sponsorDoc.id;
    let currentUid = sponsorId;
    let level = 0;

    // Use a batch write for more efficient updates to multiple documents
    const batch = db.batch();
    const usersToUpdate = []; // Store UIDs to update in batch

    while (currentUid) {
      const userRef = db.collection('users').doc(currentUid);
      const userDoc = await userRef.get();
      if (!userDoc.exists) {
        console.warn(`User ${currentUid} not found in chain, stopping.`);
        break;
      }

      const userData = userDoc.data();
      const updates = { total_team_count: FieldValue.increment(1) };

      if (level === 0) {
        updates.direct_sponsor_count = FieldValue.increment(1);
      }

      const direct = userData.direct_sponsor_count ?? 0;
      const total = userData.total_team_count ?? 0;
      const directMin = userData.direct_sponsor_min ?? 1;
      const totalMin = userData.total_team_min ?? 1;
      const alreadyQualified = userData.qualified_date != null;

      if (!alreadyQualified && direct >= directMin && total >= totalMin) {
        updates.qualified_date = FieldValue.serverTimestamp();
      }

      batch.update(userRef, updates);

      if (level === 0) {
        usersToUpdate.push(currentUid); // Only direct sponsor
      }

      if (userData.role === 'admin') {
        break; // Stop at the top admin
      }

      currentUid = userData.referred_by;
      level++;
    }


    await batch.commit(); // Commit all batched updates

    // After batch commit, handle eligibility and invites (can be done in parallel)
    await Promise.all(usersToUpdate.map(uid => checkEligibilityAndSendInvite(uid)));

    return res.status(200).json({ success: true, message: 'Sponsor counts updated and invites processed.' });
  } catch (err) {
    console.error('🔥 Error in incrementSponsorCounts:', err);
    return res.status(500).json({ error: 'Internal server error', details: err.message });
  }
});

// ---
// ## Callable Function (onCall)
// ---

// 🔐 Check Admin subscription or trial status
exports.checkAdminSubscriptionStatus = onCall(async (request) => {
  const { uid } = request.data; // Callable functions have data in request.data

  if (!uid) {
    throw new functions.https.HttpsError('invalid-argument', 'User ID is required.');
  }

  try {
    // Use the initialized 'db' object directly
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User not found.');
    }

    const userData = userDoc.data();
    const role = userData.role || 'user';
    if (role !== 'admin') {
      // If not an admin, they are implicitly "active" for general app access,
      // but their subscription status doesn't apply.
      return { isActive: true, role: 'user', daysRemaining: 0, trialExpired: true, message: "User is not an admin, subscription status does not apply." };
    }

    const now = new Date();
    // Use optional chaining (?.) and nullish coalescing (??) for robustness
    const trialStart = userData.trialStartAt?.toDate?.() ?? null;
    const subscriptionExpiresAt = userData.subscriptionExpiresAt?.toDate?.() ?? null;

    let isActive = false;
    let trialExpired = true; // Assume trial expired unless proven otherwise
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
        trialExpired = false; // Trial is still active
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
    // Re-throw HttpsError for client to catch
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to verify subscription status.', error.message);
  }
});

// ---
// ## Firestore Triggered Functions (onDocumentCreated)
// ---

// 🔔 Send FCM push notification on in-app notification creation
// Removed duplicate function definition.
exports.sendPushNotification = onDocumentCreated("users/{userId}/notifications/{notificationId}", async (event) => {
  const snap = event.data; // Data snapshot
  const userId = event.params.userId; // Path parameters from event

  // No need to check snap?.data() first, it's always available for onDocumentCreated
  const notificationData = snap.data();

  const userDoc = await db.collection("users").doc(userId).get();
  // Use optional chaining for safer access
  const fcmToken = userDoc.data()?.fcm_token;

  if (!fcmToken) {
    console.log(`❌ No FCM token for user ${userId}. Notification will not be sent.`);
    return null; // Return null if no token to avoid unnecessary processing
  }

  const message = {
    token: fcmToken,
    notification: {
      title: notificationData?.title || "New Alert",
      body: notificationData?.message || "You have a new notification in TeamBuild Pro",
    },
    // Consolidate platform-specific sound settings if they are identical
    android: { notification: { sound: "default" } },
    apns: { payload: { aps: { sound: "default" } } },
  };

  try {
    const response = await messaging.send(message);
    console.log(`✅ FCM push sent to user ${userId}: ${response}`);
  } catch (error) {
    console.error(`❌ Failed to send FCM push to user ${userId}:`, error);
    // Consider handling specific FCM errors (e.g., token invalid)
  }
});

// ---
// ## Helper Function
// ---

// 🔐 Auto-check eligibility and invite user
async function checkEligibilityAndSendInvite(uid) {
  try {
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      console.log(`User ${uid} not found for invite check.`);
      return;
    }

    const userData = userDoc.data();
    const adminId = userData.upline_admin;
    if (!adminId) {
      console.log(`User ${uid} has no upline_admin. Skipping invite check.`);
      return;
    }

    const settingsDoc = await db.collection('admin_settings').doc(adminId).get();
    if (!settingsDoc.exists) {
      console.log(`Admin settings for ${adminId} not found. Skipping invite for user ${uid}.`);
      return;
    }

    const settings = settingsDoc.data();
    // Destructure with default values for robustness
    const {
      direct_sponsor_min = 1,
      total_team_min = 1,
      countries = [],
      biz_opp = '', // Provide default for biz_opp
      biz_opp_ref_url = '' // Provide default for biz_opp_ref_url
    } = settings;

    // Use nullish coalescing for user data fields
    const direct = userData.direct_sponsor_count ?? 0;
    const total = userData.total_team_count ?? 0;
    const country = userData.country ?? '';
    const firstName = userData.firstName || ''; // Still using || for string defaults

    const isEligible =
      direct >= direct_sponsor_min &&
      total >= total_team_min &&
      countries.includes(country);

    if (!isEligible) {
      console.log(`User ${uid} is not eligible for invite based on criteria.`);
      return;
    }

    // Check for existing invite using a compound query for better index utilization
    // This is more robust than just by toUserId if there could be multiple admins
    const existing = await db.collection('invites')
      .where('toUserId', '==', uid)
      .where('fromAdminId', '==', adminId)
      .limit(1)
      .get();

    if (!existing.empty) {
      console.log(`Invite already exists for user ${uid} from admin ${adminId}. Skipping.`);
      return;
    }

    // Use a batch for adding invite and notification for atomicity
    const batch = db.batch();

    const inviteRef = db.collection('invites').doc(); // Create new doc ref first
    batch.set(inviteRef, {
      fromAdminId: adminId,
      toUserId: uid,
      bizOpp: biz_opp,
      refLink: biz_opp_ref_url,
      sentAt: Timestamp.now(),
      status: 'sent',
    });

    const notificationRef = db.collection('users')
      .doc(uid)
      .collection('notifications')
      .doc(); // Create new doc ref for notification
    batch.set(notificationRef, {
      type: 'invitation',
      title: `🎉 Congratulations!`,
      message: `Your hard work has paid off! You’re now qualified to join ${biz_opp || 'a business opportunity'}.

Visit your Dashboard and click ‘Join Opportunity’ to get started.`,
      timestamp: Timestamp.now(),
      read: false,
    });

    await batch.commit(); // Commit the batch operation

    console.log(`✅ Invite + notification sent to user ${uid} from admin ${adminId}`);
  } catch (error) {
    console.error(`❌ Error in checkEligibilityAndSendInvite for user ${uid}:`, error);
    // Don't re-throw, as this is a background helper function, just log the error.
  }
}

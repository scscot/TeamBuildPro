const admin = require("firebase-admin");

// Note: Ensure your service account key is located at this path
const serviceAccount = require("../secrets/serviceAccountKey.json");

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function backfillUplineRefs() {
    console.log("🚀 Starting data migration v3 to populate 'upline_refs'...");

    const usersRef = db.collection("users");
    const allUsersSnapshot = await usersRef.get();

    if (allUsersSnapshot.empty) {
        console.log("No users found. Exiting.");
        return;
    }

    const usersMap = new Map();
    allUsersSnapshot.forEach(doc => {
        usersMap.set(doc.id, doc.data());
    });

    console.log(`🗺️  Found ${usersMap.size} total users to process.`);

    let batch = db.batch();
    let updatedCount = 0;
    const BATCH_SIZE = 490; // Firestore batch limit is 500

    for (const [userId, userData] of usersMap.entries()) {
        // Skip if the user already has a correctly populated upline_refs array.
        if (Array.isArray(userData.upline_refs) && userData.upline_refs.length > 0) {
            continue;
        }
        // Also skip if the user is a top-level admin who has no sponsor
        if (!userData.referredBy && userData.upline_admin === userId) {
            if (!Array.isArray(userData.upline_refs) || userData.upline_refs.length !== 0) {
                const userRef = usersRef.doc(userId);
                batch.update(userRef, { upline_refs: [], level: 1 });
                updatedCount++;
                console.log(`  - Correcting admin ${userData.firstName} (${userId}) to have empty upline_refs and level 1.`);
            }
            continue;
        }

        const uplineRefs = [];
        // *** CORRECTED: Using 'referredBy' instead of 'sponsor_id' ***
        let currentSponsorId = userData.referredBy;
        const visited = new Set();

        console.log(`\nProcessing User: ${userId} (${userData.firstName})`);
        console.log(`  - Initial referredBy from data: '${currentSponsorId}'`);

        while (currentSponsorId && !visited.has(currentSponsorId)) {
            visited.add(currentSponsorId);
            const sponsorData = usersMap.get(currentSponsorId);

            if (sponsorData) {
                console.log(`    - Found sponsor in map: ${sponsorData.firstName} (UID: ${currentSponsorId})`);
                uplineRefs.unshift(currentSponsorId);
                // *** CORRECTED: Using 'referredBy' instead of 'sponsor_id' ***
                currentSponsorId = sponsorData.referredBy;
            } else {
                console.warn(`    - ⚠️  Could not find sponsor with ID: ${currentSponsorId} in the user map. Stopping traversal for this user.`);
                break;
            }
        }

        const userRef = usersRef.doc(userId);
        batch.update(userRef, {
            upline_refs: uplineRefs,
            level: uplineRefs.length + 1
        });

        console.log(`  - ✅  Prepared update for ${userId}. Upline Refs: [${uplineRefs.join(", ")}], New Level: ${uplineRefs.length + 1}`);
        updatedCount++;

        if (updatedCount > 0 && updatedCount % BATCH_SIZE === 0) {
            console.log(`\n✍️ Committing batch of ${BATCH_SIZE}...`);
            await batch.commit();
            batch = db.batch(); // Re-initialize for the next batch
        }
    }

    if (updatedCount > 0) {
        console.log(`\n✍️ Committing final batch to update remaining user documents...`);
        await batch.commit();
        console.log("✅ Batch commit successful!");
    } else {
        console.log("✅ All processable users already had the 'upline_refs' field. No updates needed.");
    }

    console.log("Data migration complete.");
}

backfillUplineRefs().catch(console.error);
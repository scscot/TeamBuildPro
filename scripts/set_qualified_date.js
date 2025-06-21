// scripts/set_qualified_date.js

const serviceAccount = require('../secrets/serviceAccountKey.json');
const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const args = process.argv.slice(2);
const isDryRun = args.includes('--dry-run');
const isUpdate = args.includes('--update');

if (!isDryRun && !isUpdate) {
    console.error("\n❌ Please provide either '--dry-run' or '--update' as an argument.\n");
    process.exit(1);
}

console.log(`\n🚀 Starting ${isDryRun ? 'DRY-RUN' : 'UPDATE'} mode...\n`);

(async () => {
    try {
        const usersRef = db.collection('users');
        const snapshot = await usersRef.get();
        let resetCount = 0;
        let qualifyCount = 0;

        for (const doc of snapshot.docs) {
            const data = doc.data();
            const uid = doc.id;

            const referredBy = data.referredBy || null;
            const totalTeam = data.totalTeam || 0;
            const directSponsorCount = data.directSponsorCount || 0;

            const shouldQualify = referredBy !== null && totalTeam >= 20 && directSponsorCount >= 4;

            if (isDryRun) {
                if (shouldQualify) {
                    console.log(`🏅 DRY-RUN QUALIFY: ${uid}`);
                    qualifyCount++;
                } else {
                    console.log(`🔁 DRY-RUN RESET: ${uid}`);
                    resetCount++;
                }
            } else if (isUpdate) {
                // Always reset first
                await usersRef.doc(uid).update({
                    qualifiedDate: null,
                    role: 'user'
                });

                // Then set qualification if user meets criteria
                if (shouldQualify) {
                    await usersRef.doc(uid).update({
                        qualifiedDate: FieldValue.serverTimestamp()
                    });
                    qualifyCount++;
                } else {
                    resetCount++;
                }
            }
        }

        console.log(`\n🧪 ${isDryRun ? 'Dry run' : 'Update'} complete. Would qualify: ${qualifyCount}, Would reset: ${resetCount}\n`);
    } catch (error) {
        console.error("❌ Error:", error);
    }
})();

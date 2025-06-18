const admin = require("firebase-admin");
const { v4: uuidv4 } = require("uuid");
const { faker } = require("@faker-js/faker");
const process = require("process");

// ======================= IMPORTANT =======================
// CONFIGURE YOUR EXISTING ADMIN USER'S DETAILS HERE
const ROOT_ADMIN_UID = "KJ8uFnlhKhWgBa4NVcwT";
const ROOT_ADMIN_REFERRAL_CODE = "88888888";
// =========================================================

const args = process.argv.slice(2);
const isDryRun = args.includes("--dry-run");
const isInsert = args.includes("--insert");

if (isInsert) {
  const serviceAccount = require("../secrets/serviceAccountKey.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  console.log("✅ Firebase Admin Initialized for Firestore Insert");
}

const statesByCountry = {
  'United States': ['California', 'New York', 'Texas', 'Florida', 'Illinois'],
  'Canada': ['Ontario', 'Quebec', 'British Columbia', 'Alberta'],
};

function getRandomLocation() {
  const country = faker.helpers.arrayElement(Object.keys(statesByCountry));
  const state = faker.helpers.arrayElement(statesByCountry[country]);
  const city = faker.location.city();
  return { country, state, city };
}

function createUser(sponsor, uplineAdminId) {
  const firstName = faker.person.firstName();
  const lastName = faker.person.lastName();
  const location = getRandomLocation();

  const uplineRefs = [];
  if (sponsor) {
    if (Array.isArray(sponsor.upline_refs)) {
      uplineRefs.push(...sponsor.upline_refs);
    }
    uplineRefs.push(sponsor.uid);
  }

  return {
    uid: uuidv4(),
    firstName,
    lastName,
    email: faker.internet.email({ firstName, lastName }),
    ...location,
    referralCode: uuidv4().substring(0, 8).toUpperCase(),
    referredBy: sponsor ? sponsor.referralCode : null,
    sponsor_id: sponsor ? sponsor.uid : null,
    upline_admin: uplineAdminId,
    level: uplineRefs.length + 1,
    upline_refs: uplineRefs,
    createdAt: new Date(),
    isQualified: faker.datatype.boolean(0.3),
  };
}

function buildHierarchy(rootAdmin, usersPerSponsor, maxLevels) {
  let queue = [rootAdmin];
  let allGeneratedUsers = [];

  for (let level = 2; level <= maxLevels; level++) {
    const nextQueue = [];
    for (const sponsor of queue) {
      const numToSponsor = Math.floor(Math.random() * (usersPerSponsor + 1)) + 1;
      for (let i = 0; i < numToSponsor; i++) {
        const newUser = createUser(sponsor, rootAdmin.uid);
        allGeneratedUsers.push(newUser);
        nextQueue.push(newUser);
      }
    }
    queue = nextQueue;
    if (queue.length === 0) break;
  }
  return allGeneratedUsers;
}

function displayDryRun(users) {
  console.log(`🌲 Dry Run: Will generate ${users.length} new users.`);
  console.log("----------------------------------------");
  users.forEach(user => {
    console.log(`UID: ${user.uid}`);
    console.log(` Name: ${user.firstName} ${user.lastName}`);
    console.log(` Level: ${user.level}`);
    console.log(` Sponsor UID: ${user.sponsor_id || 'N/A'}`);
    console.log(` Referred By (Code): ${user.referredBy}`);
    console.log(` Upline Refs: [${user.upline_refs.join(", ")}]`);
    console.log("----------------------------------------");
  });
}

async function insertUsers(users) {
  const db = admin.firestore();
  let batch = db.batch();
  let usersInBatch = 0;

  console.log(`✍️ Preparing to insert ${users.length} users into Firestore...`);

  for (const user of users) {
    const ref = db.collection("users").doc(user.uid);
    batch.set(ref, user, { merge: true });
    usersInBatch++;
    if (usersInBatch >= 490) {
      await batch.commit();
      console.log(`   ...committed batch of ${usersInBatch} users.`);
      batch = db.batch();
      usersInBatch = 0;
    }
  }

  if (usersInBatch > 0) {
    await batch.commit();
    console.log(`   ...committed final batch of ${usersInBatch} users.`);
  }
  console.log(`✅ Inserted/Updated ${users.length} total users into Firestore.`);
}

(async () => {
  if (isInsert && (ROOT_ADMIN_UID === "PASTE_YOUR_ADMIN_UID_HERE" || ROOT_ADMIN_REFERRAL_CODE === "PASTE_ADMIN_REFERRAL_CODE_HERE")) {
    console.error("❌ ERROR: Please edit the script to provide your actual ROOT_ADMIN_UID and ROOT_ADMIN_REFERRAL_CODE.");
    return;
  }

  // Configuration: Sponsoring up to 3 users each, down to 4 levels deep.
  const rootAdmin = {
    uid: ROOT_ADMIN_UID,
    referralCode: ROOT_ADMIN_REFERRAL_CODE,
    upline_refs: [] // The root admin has no upline
  };

  const usersToCreate = buildHierarchy(rootAdmin, 3, 4);

  if (isDryRun) {
    displayDryRun(usersToCreate);
  }

  if (isInsert) {
    await insertUsers(usersToCreate);
  }

  if (!isDryRun && !isInsert) {
    console.log("No action taken. Use --dry-run to display users or --insert to add to Firestore.");
  }
})();
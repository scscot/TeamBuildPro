const admin = require("firebase-admin");
const { v4: uuidv4 } = require("uuid");
const { faker } = require('@faker-js/faker');
const process = require("process");

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

function generateReferralCode() {
  return Math.random().toString(36).substring(2, 10).toUpperCase();
}

function createUser(level, referredBy, uplineAdminUid, adminProfile) {
  const uid = uuidv4();
  const firstName = faker.person.firstName();
  const lastName = faker.person.lastName();
  return {
    uid,
    email: faker.internet.email({ firstName, lastName }),
    firstName,
    lastName,
    country: faker.location.country(),
    state: faker.location.state(),
    createdAt: new Date().toISOString(),
    referralCode: generateReferralCode(),
    referredBy,
    role: "user",
    level,
    photoUrl: faker.image.avatar(),
    direct_sponsor_count: 0,
    total_team_count: 0,
    upline_admin: uplineAdminUid,
    downlineIds: [],
    biz_opp: adminProfile.biz_opp,
    biz_opp_ref_url: adminProfile.biz_opp_ref_url
  };
}

function buildHierarchy(maxLevels = 5, teamSize = 100) {
  const existingAdmin = {
    uid: "KJ8uFnlhKhWgBa4NVcwT",
    referralCode: "KJ8uFnlhKhWgBa4NVcwT",
    biz_opp: "Team Building Project",
    biz_opp_ref_url: "https://www.teambuildingproject.com/?ref=111"
  };

  const allUsers = [];
  const queue = [];

  const root = {
    uid: existingAdmin.uid,
    referralCode: existingAdmin.referralCode,
    direct_sponsor_count: 0,
    total_team_count: 0,
    downlineIds: []
  };

  queue.push({ user: root, level: 1 });

  while (queue.length > 0) {
    const { user, level } = queue.shift();
    if (level > maxLevels) continue;

    const numChildren = level === 1 ? 3 : faker.number.int({ min: level === 2 ? 3 : 1, max: level === 2 ? 5 : 3 });

    for (let i = 0; i < numChildren && allUsers.length < teamSize; i++) {
      const child = createUser(level, user.referralCode, existingAdmin.uid, existingAdmin);
      user.direct_sponsor_count += 1;
      user.total_team_count += 1;
      user.downlineIds.push(child.uid);
      allUsers.push(child);
      queue.push({ user: child, level: level + 1 });
    }
  }

  return allUsers;
}

function printDryRun(users) {
  console.log("🔍 Dry Run - User Hierarchy");
  users.forEach((user, index) => {
    console.log(`\n${index + 1}. ${user.firstName} ${user.lastName} (${user.role}) - Level ${user.level}`);
    console.log(`   Email: ${user.email}`);
    console.log(`   ReferralCode: ${user.referralCode}`);
    console.log(`   ReferredBy: ${user.referredBy}`);
    console.log(`   Country: ${user.country}, State: ${user.state}`);
    console.log(`   CreatedAt: ${user.createdAt}`);
    console.log(`   Downline IDs: ${user.downlineIds.length > 0 ? user.downlineIds.join(", ") : "None"}`);
  });
}

async function insertUsers(users) {
  const db = admin.firestore();
  const batch = db.batch();
  users.forEach(user => {
    const ref = db.collection("users").doc(user.uid);
    batch.set(ref, user);
  });
  await batch.commit();
  console.log(`✅ Inserted ${users.length} users into Firestore.`);
}

(async () => {
  const users = buildHierarchy(5, 100);
  if (isDryRun) {
    printDryRun(users);
  } else if (isInsert) {
    await insertUsers(users);
  } else {
    console.log("❗ Please specify --dry-run or --insert");
  }
})();

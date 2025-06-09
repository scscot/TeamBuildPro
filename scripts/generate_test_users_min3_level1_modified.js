const admin = require("firebase-admin");
const { v4: uuidv4 } = require("uuid");
const { faker } = require("@faker-js/faker");
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

function createUser(level, referredBy, uplineAdminUid) {
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
    city: faker.location.city(),
    createdAt: new Date().toISOString(),
    referralCode: generateReferralCode(),
    referredBy,
    role: level === 0 ? "admin" : "user",
    level,
    photoUrl: faker.image.avatar(),
    direct_sponsor_count: 0,
    total_team_count: 0,
    upline_admin: uplineAdminUid
  };
}

function buildHierarchy(maxLevels = 5, teamSize = 300) {
  const existingAdminUid = "KJ8uFnlhKhWgBa4NVcwT";
  const existingAdminReferralCode = "KJ8uFnlhKhWgBa4NVcwT";

  const allUsers = [];
  const queue = [];

  const root = {
    uid: existingAdminUid,
    referralCode: existingAdminReferralCode,
    direct_sponsor_count: 0,
    total_team_count: 0
  };

  queue.push({ user: root, level: 1 });

  let level1Count = 0;

  while (queue.length > 0) {
    const { user, level } = queue.shift();
    if (level > maxLevels) continue;

    const isLevel1 = level === 1;
    const numChildren = isLevel1
      ? Math.max(3, faker.number.int({ min: 3, max: 5 }))
      : faker.number.int({ min: 1, max: 3 });

    for (let i = 0; i < numChildren && allUsers.length < teamSize; i++) {
      const child = createUser(level, user.referralCode, existingAdminUid);
      user.direct_sponsor_count += 1;
      user.total_team_count += 1;
      allUsers.push(child);
      queue.push({ user: child, level: level + 1 });

      if (isLevel1) level1Count++;
    }
  }

  console.log(`✅ Level 1 Users Generated: ${level1Count}`);
  return allUsers;
}

function printDryRun(users) {
  console.log("🔍 Dry Run - User Hierarchy");
  users.forEach((user, index) => {
    console.log(`\n${index + 1}. ${user.firstName} ${user.lastName} (${user.role}) - Level ${user.level}`);
    console.log(`   Email: ${user.email}`);
    console.log(`   ReferralCode: ${user.referralCode}`);
    console.log(`   ReferredBy: ${user.referredBy}`);
    console.log(`   Country: ${user.country}, State: ${user.state}, City: ${user.city}`);
    console.log(`   CreatedAt: ${user.createdAt}`);
  });
}

async function insertUsers(users) {
  const db = admin.firestore();
  const batch = db.batch();
  users.forEach((user) => {
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
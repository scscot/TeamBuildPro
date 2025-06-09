const admin = require("firebase-admin");
const { v4: uuidv4 } = require("uuid");
const { faker } = require('@faker-js/faker');
const process = require("process");

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
    createdAt: new Date().toISOString(),
    referralCode: generateReferralCode(),
    referredBy,
    role: level === 0 ? "admin" : "user",
    level,
    photoUrl: faker.image.avatar(),
    direct_sponsor_count: 0,
    total_team_count: 0,
    upline_admin: uplineAdminUid,
    downlineIds: []
  };
}

function buildHierarchy(maxLevels = 5, teamSize = 100) {
  const allUsers = [];
  const root = createUser(0, null, null);
  allUsers.push(root);
  const queue = [{ user: root, level: 1 }];

  while (queue.length > 0) {
    const { user, level } = queue.shift();
    if (level > maxLevels) continue;

    const numChildren = faker.number.int({ min: level === 2 ? 3 : 1, max: level === 2 ? 5 : 3 });
    for (let i = 0; i < numChildren && allUsers.length < teamSize; i++) {
      const child = createUser(level, user.referralCode, root.uid);
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
    console.log(`${index + 1}. ${user.firstName} ${user.lastName} (${user.role}) - Level ${user.level}`);
    console.log(`   Referred By: ${user.referredBy}`);
    console.log(`   Referral Code: ${user.referralCode}`);
    console.log(`   Email: ${user.email}`);
    console.log(`   Downline IDs: ${user.downlineIds.length > 0 ? user.downlineIds.join(", ") : "None"}`);
    console.log("—".repeat(60));
  });
}

if (process.argv.includes("--dry-run")) {
  const users = buildHierarchy(5, 100);
  printDryRun(users);
}

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

// --- START: New additions for country and state logic ---

const statesByCountry = {
  'United States': [
    'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California', 'Colorado',
    'Connecticut', 'Delaware', 'District of Columbia', 'Florida', 'Georgia',
    'Hawaii', 'Idaho', 'Illinois', 'Indiana', 'Iowa', 'Kansas', 'Kentucky',
    'Louisiana', 'Maine', 'Maryland', 'Massachusetts', 'Michigan', 'Minnesota',
    'Mississippi', 'Missouri', 'Montana', 'Nebraska', 'Nevada', 'New Hampshire',
    'New Jersey', 'New Mexico', 'New York', 'North Carolina', 'North Dakota',
    'Ohio', 'Oklahoma', 'Oregon', 'Pennsylvania', 'Puerto Rico', 'Rhode Island',
    'South Carolina', 'South Dakota', 'Tennessee', 'Texas', 'Utah', 'Vermont',
    'Virginia', 'Virgin Islands', 'Washington', 'West Virginia', 'Wisconsin',
    'Wyoming'
  ],
  'Canada': [
    'Alberta', 'British Columbia', 'Manitoba', 'New Brunswick',
    'Newfoundland and Labrador', 'Nova Scotia', 'Ontario',
    'Prince Edward Island', 'Quebec', 'Saskatchewan',
    'Northwest Territories', 'Nunavut', 'Yukon'
  ],
  // Note: 'Albania' is present in your Dart map but excluded from the countries list below
  // as per your request to limit to US and Canada.
};

const allowedCountries = ['United States', 'Canada'];

function getRandomElement(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

// --- END: New additions for country and state logic ---


function generateReferralCode() {
  return Math.random().toString(36).substring(2, 10).toUpperCase();
}

function createUser(level, referredBy, uplineAdminUid) {
  const uid = uuidv4();
  const firstName = faker.person.firstName();
  const lastName = faker.person.lastName();

  // --- START: Modified country and state selection ---
  const selectedCountry = getRandomElement(allowedCountries);
  const selectedStates = statesByCountry[selectedCountry] || []; // Fallback to empty array
  const selectedState = getRandomElement(selectedStates) || faker.location.state(); // Fallback to faker if no states found
  // --- END: Modified country and state selection ---

  return {
    uid,
    email: faker.internet.email({ firstName, lastName }),
    firstName,
    lastName,
    country: selectedCountry, // Modified
    state: selectedState,     // Modified
    city: faker.location.city(), // City can still be random
    createdAt: new Date().toISOString(),
    referralCode: generateReferralCode(),
    referredBy, // This will be the referralCode of the direct sponsor
    role: level === 0 ? "admin" : "user",
    level,
    photoUrl: faker.image.avatar(),
    direct_sponsor_count: 0, // Will be updated after children are added
    total_team_count: 0, // Will be updated after children are added
    upline_admin: uplineAdminUid, // The UID of the top-level admin
    downlineIds: [], // Initialize as empty, will be populated during hierarchy build
  };
}

function buildHierarchy(maxLevels = 5, totalDownlineUsers = 300) {
  const existingAdminUid = "KJ8uFnlhKhWgBa4NVcwT";
  const existingAdminReferralCode = "KJ8uFnlhKhWgBa4NVcwT";

  const allUsers = [];
  const queue = [];
  const userMap = new Map(); // To easily find users by UID for downlineIds update

  // Provided existing Admin user details
  const existingAdminUser = {
    uid: existingAdminUid,
    email: "scscot@gmail.com",
    firstName: "Stephen",
    lastName: "Scott",
    country: "United States", // Admin's country, as specified
    state: "California",      // Admin's state, as specified
    city: "Los Angeles",
    createdAt: new Date().toISOString(),
    referralCode: existingAdminReferralCode,
    referredBy: null, // Admin has no referrer
    role: "admin",
    level: 0, // Admin is level 0
    photoUrl: faker.image.avatar(),
    direct_sponsor_count: 0,
    total_team_count: 0,
    upline_admin: null, // Admin has no upline admin
    downlineIds: [], // This will store the UIDs of their entire downline
  };

  allUsers.push(existingAdminUser);
  userMap.set(existingAdminUid, existingAdminUser);

  queue.push({ user: existingAdminUser, level: 0 }); // Start with the admin at level 0

  let level1Count = 0;
  let currentDownlineUsersCount = 0; // Track generated downline users

  while (queue.length > 0 && currentDownlineUsersCount < totalDownlineUsers) {
    const { user, level } = queue.shift();

    if (level >= maxLevels) continue;

    const isLevel0Or1 = level <= 1; // Admin (level 0) and their direct referrals (level 1)
    const numChildren = isLevel0Or1
      ? Math.max(3, faker.number.int({ min: 3, max: 5 }))
      : faker.number.int({ min: 1, max: 3 });

    for (
      let i = 0;
      i < numChildren && currentDownlineUsersCount < totalDownlineUsers;
      i++
    ) {
      const child = createUser(level + 1, user.referralCode, existingAdminUid); // Child's level is current level + 1
      allUsers.push(child);
      userMap.set(child.uid, child); // Add to map for easy lookup

      user.direct_sponsor_count += 1; // Update sponsor's direct_sponsor_count

      // Add child's UID to the sponsor's downlineIds (initially just direct)
      user.downlineIds.push(child.uid);

      queue.push({ user: child, level: level + 1 });

      if (level + 1 === 1) {
        level1Count++;
      }
      currentDownlineUsersCount++;
    }
  }

  // Post-processing for accurate total_team_count and finalized downlineIds
  for (let i = allUsers.length - 1; i >= 0; i--) {
    const currentUser = allUsers[i];
    if (currentUser.downlineIds && currentUser.downlineIds.length > 0) {
      let fullDownline = new Set(currentUser.downlineIds); // Start with direct downline

      // Recursively add indirect downline UIDs
      const processDownline = (uids) => {
        for (const uid of uids) {
          const downlineUser = userMap.get(uid);
          if (downlineUser && downlineUser.downlineIds) {
            downlineUser.downlineIds.forEach(indirectUid => {
              if (!fullDownline.has(indirectUid)) {
                fullDownline.add(indirectUid);
                // Recursively process new indirect downline users if they are themselves sponsors
                // This ensures full depth traversal.
                processDownline([indirectUid]);
              }
            });
          }
        }
      };
      processDownline(currentUser.downlineIds); // Start with direct downline UIDs

      currentUser.total_team_count = fullDownline.size;
      currentUser.downlineIds = Array.from(fullDownline);
    } else {
      currentUser.total_team_count = 0;
      currentUser.downlineIds = [];
    }
  }

  console.log(`✅ Total Downline Users Generated: ${currentDownlineUsersCount}`);
  console.log(`✅ Level 1 Users Generated (direct referrals of admin): ${level1Count}`);
  console.log(`✅ Total users (Admin + Downline): ${allUsers.length}`);

  return allUsers;
}

function printDryRun(users) {
  console.log("🔍 Dry Run - User Hierarchy");
  users.forEach((user, index) => {
    console.log(
      `\n${index + 1}. ${user.firstName} ${user.lastName} (${user.role}) - Level ${user.level}`
    );
    console.log(` UID: ${user.uid}`);
    console.log(` Email: ${user.email}`);
    console.log(` ReferralCode: ${user.referralCode}`);
    console.log(` ReferredBy: ${user.referredBy}`);
    console.log(
      ` Country: ${user.country}, State: ${user.state}, City: ${user.city}`
    );
    console.log(` CreatedAt: ${user.createdAt}`);
    console.log(` Direct Sponsors: ${user.direct_sponsor_count}`);
    console.log(` Total Team: ${user.total_team_count}`);
    console.log(` Upline Admin: ${user.upline_admin}`);
    // Log only the first few downline UIDs for brevity in dry run, or all if list is short
    const downlineDisplay = user.downlineIds.length > 5
      ? `${user.downlineIds.slice(0, 5).join(", ")}, ... (${user.downlineIds.length} total)`
      : user.downlineIds.join(", ");
    console.log(` Downline UIDs: [${downlineDisplay}]`);
  });
}

async function insertUsers(users) {
  const db = admin.firestore();
  const batch = db.batch();
  let usersProcessedCount = 0;

  users.forEach((user) => {
    const ref = db.collection("users").doc(user.uid);
    batch.set(ref, user, { merge: true }); // Use merge: true for safe updates
    usersProcessedCount++;
  });
  await batch.commit();
  console.log(`✅ Inserted/Updated ${usersProcessedCount} users into Firestore.`);
}

(async () => {
  const users = buildHierarchy(10, 300); // 10 maxLevels for 8-10 depth, 300 downline users

  if (isDryRun) {
    printDryRun(users);
  } else if (isInsert) {
    await insertUsers(users);
  } else {
    console.log("❗ Please specify --dry-run or --insert");
  }
})();
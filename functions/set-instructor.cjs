
const admin = require('firebase-admin');

admin.initializeApp({
  projectId: 'passwithpannu-b1b80',
});

async function main() {
  const email = process.argv[2];

  if (!email) {
    throw new Error('Instructor email is required.');
  }

  const user = await admin.auth().getUserByEmail(email);

  await admin.auth().setCustomUserClaims(user.uid, {
    ...(user.customClaims || {}),
    admin: true,
  });

  console.log(`Instructor access granted to: ${email}`);
  console.log(`UID: ${user.uid}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

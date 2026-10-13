// Usage (from /functions):  node scripts/set-admin.js instructor@example.com
// Needs credentials: GOOGLE_APPLICATION_CREDENTIALS=serviceAccount.json (never commit it)
// or FIREBASE_AUTH_EMULATOR_HOST / FIRESTORE_EMULATOR_HOST + GCLOUD_PROJECT for the emulator.
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

(async () => {
  const email = process.argv[2];
  if (!email) throw new Error('Pass the instructor email as the first argument');
  initializeApp();
  const user = await getAuth().getUserByEmail(email);
  await getAuth().setCustomUserClaims(user.uid, { admin: true });
  await getFirestore().collection('users').doc(user.uid).set(
    {
      uid: user.uid,
      email,
      fullName: user.displayName || 'Instructor',
      role: 'admin',
      isActive: true,
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  console.log(`${email} is now an admin. Sign out and back in to refresh the token.`);
})().catch((e) => { console.error(e); process.exit(1); });

/** Deploy as Firebase Functions (Node 20); see README for dependencies and secrets. */
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
admin.initializeApp();
const db = admin.firestore();
const smtpUser = defineSecret('SMTP_USER');
const smtpPass = defineSecret('SMTP_PASSWORD');
const smtpHost = defineSecret('SMTP_HOST');
const smtpFrom = defineSecret('SMTP_FROM');
const baseUrl = defineSecret('ACTIVATION_URL');

function checkAdmin(request) {
  if (request.auth?.token?.admin !== true) throw new HttpsError('permission-denied', 'Instructor account required');
}

exports.inviteStudent = onCall({region: 'europe-west2', secrets: [smtpUser, smtpPass, smtpHost, smtpFrom, baseUrl]}, async (request) => {
  checkAdmin(request);
  const {fullName, email, phone = '', lessonType} = request.data || {};
  if (typeof fullName !== 'string' || fullName.trim().length < 2 ||
      typeof email !== 'string' || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) ||
      !['manual', 'automatic'].includes(lessonType)) {
    throw new HttpsError('invalid-argument', 'Invalid student details');
  }
  const normalized = email.trim().toLowerCase();
  let user;
  try {
    user = await admin.auth().getUserByEmail(normalized);
    const doc = await db.collection('users').doc(user.uid).get();
    if (!doc.exists || doc.data()?.role !== 'student') throw new HttpsError('already-exists', 'Email already belongs to another account');
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    if (e.code !== 'auth/user-not-found') throw new HttpsError('internal', 'Could not check existing account');
    user = await admin.auth().createUser({email: normalized, displayName: fullName.trim(), disabled: false});
  }
  await db.collection('users').doc(user.uid).set({
    uid: user.uid, fullName: fullName.trim(), email: normalized, phone: String(phone).trim(),
    lessonType, role: 'student', isActive: true, invitationStatus: 'invited',
    invitedAt: admin.firestore.FieldValue.serverTimestamp(), invitedBy: request.auth.uid,
  }, {merge: true});
  // Firebase generates a one-use password-setup/reset OOB link, subject to expiration.
  const resetLink = await admin.auth().generatePasswordResetLink(normalized, {url: baseUrl.value()});
  const transport = nodemailer.createTransport({
    host: smtpHost.value(), port: 465, secure: true,
    auth: {user: smtpUser.value(), pass: smtpPass.value()},
  });
  try {
    await transport.sendMail({from: smtpFrom.value(), to: normalized,
      subject: 'Activate your Pass With Pannu account',
      text: `Hello ${fullName.trim()},\n\nYour instructor has invited you to Pass With Pannu. Set your password securely here:\n${resetLink}\n\nAfter setting your password, open the app and sign in. You must accept the driving school Terms & Conditions before using lessons.\n\nIf you did not expect this invitation, ignore this email.`,
    });
  } catch (e) {
    throw new HttpsError('unavailable', 'Invitation email could not be sent. Check SMTP configuration and retry.');
  }
  return {ok: true, uid: user.uid};
});

function londonParts(date) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Europe/London', year:'numeric', month:'2-digit', day:'2-digit',
    hour:'2-digit', minute:'2-digit', hourCycle:'h23',
  }).formatToParts(date);
  return Object.fromEntries(parts.filter(p => p.type !== 'literal').map(p => [p.type, p.value]));
}
function londonDayKey(date) { const p=londonParts(date); return `${p.year}-${p.month}-${p.day}`; }
function tomorrowKey(now) {
  const p=londonParts(now);
  const d = new Date(Date.UTC(Number(p.year), Number(p.month)-1, Number(p.day)+1));
  return d.toISOString().slice(0,10);
}
function londonTime(date) { const p=londonParts(date); return `${p.hour}:${p.minute}`; }
async function sendOnce(collection, doc, kind, message) {
  const data = doc.data();
  const studentId = data.studentId;
  if (!studentId) return;
  const id = `${kind}_${doc.id}_${londonDayKey(message.date)}`;
  const record = db.collection('reminderDeliveries').doc(id);
  // Claim once before sending. A crash after claim may require admin replay.
  const claimed = await db.runTransaction(async tx => {
    const existing = await tx.get(record);
    if (existing.exists) return false;
    tx.create(record, {kind, sourceCollection: collection, sourceId: doc.id,
      status: 'processing', createdAt: admin.firestore.FieldValue.serverTimestamp()});
    return true;
  });
  if (!claimed) return;
  try {
    const user = await db.collection('users').doc(studentId).get();
    const tokens = user.data()?.fcmTokens;
    const tokenList = Array.isArray(tokens) ? tokens.filter(x=>typeof x === 'string' && x.length) : [];
    if (!tokenList.length) {
      await record.update({status:'no_tokens'}); return;
    }
    const response = await admin.messaging().sendEachForMulticast({tokens: tokenList,
      notification: {title: message.title, body: message.body},
      data: {type: kind, referenceId: doc.id},
    });
    await record.update({status:'sent', successCount: response.successCount,
      failureCount: response.failureCount, sentAt:admin.firestore.FieldValue.serverTimestamp()});
  } catch (e) {
    await record.update({status:'failed', error: String(e).slice(0,300)});
  }
}
exports.sendEveningReminders = onSchedule({schedule: '0 18 * * *', timeZone: 'Europe/London', region: 'europe-west2'}, async () => {
  const now = new Date();
  const tomorrow = tomorrowKey(now);
  // Date range wider than 24h handles DST; filter exact local next-day below.
  const start = admin.firestore.Timestamp.fromDate(new Date(Date.now() - 2*86400000));
  const end = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 4*86400000));
  const bookings = await db.collection('bookings').where('startDateTime', '>=', start).where('startDateTime', '<', end).get();
  for (const doc of bookings.docs) {
    const d=doc.data(); const dt=d.startDateTime?.toDate();
    if (!dt || londonDayKey(dt)!==tomorrow || !['confirmed','pending'].includes(d.status)) continue;
    await sendOnce('bookings', doc, 'lesson', {
      date:dt, title:'Your driving lesson is tomorrow',
      body:`Lesson at ${londonTime(dt)}. Pickup: ${d.pickupAddress || 'as agreed'}. Bring your provisional driving licence.`,
    });
  }
  const tests = await db.collection('drivingTests').where('testAt', '>=', start).where('testAt', '<', end).get();
  for (const doc of tests.docs) {
    const d=doc.data(); const dt=d.testAt?.toDate();
    if (!dt || londonDayKey(dt)!==tomorrow || d.status!=='scheduled') continue;
    const pickupTime = d.pickupAt?.toDate();
    await sendOnce('drivingTests', doc, 'driving_test', {
      date:dt, title:'Your driving test is tomorrow',
      body:`Test at ${londonTime(dt)}. Agreed pickup: ${pickupTime?londonTime(pickupTime):'as arranged'}${d.pickupAddress?', '+d.pickupAddress:''}. Bring your provisional driving licence.`,
    });
  }
});

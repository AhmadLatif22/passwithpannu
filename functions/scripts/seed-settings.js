// Usage (from /functions):  node scripts/seed-settings.js
// Writes app_settings/main with the defaults; edit afterwards in the admin Settings page.
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

(async () => {
  initializeApp();
  await getFirestore().collection('app_settings').doc('main').set({
    timezone: 'Europe/London',
    lessonDurationMinutes: 120,
    slotStepMinutes: 30,
    studentChangeNoticeHours: 48,
    minBookingNoticeHours: 12,
    maxAdvanceBookingDays: 90,
    travelBufferMinutes: 10,
    fallbackSpeedKmh: 28,
    reminderOffsetsHours: [24, 2],
    requireAdminApproval: false,
    workingHours: {
      1: { start: '08:00', end: '18:00' }, 2: { start: '08:00', end: '18:00' },
      3: { start: '08:00', end: '18:00' }, 4: { start: '08:00', end: '18:00' },
      5: { start: '08:00', end: '18:00' }, 6: { start: '09:00', end: '16:00' }, 7: null,
    },
    serviceArea: { lat: 52.9225, lng: -1.4746, radiusKm: 30 },
  }, { merge: true });
  console.log('Seeded app_settings/main');
})().catch((e) => { console.error(e); process.exit(1); });

import { onSchedule } from 'firebase-functions/v2/scheduler';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { DateTime } from 'luxon';
import { db } from '../firebase';
import { notifyUser } from '../services/notify';

const ZONE = 'Europe/London';

/**
 * Every evening at 18:00 London time (handles BST/GMT automatically).
 * Reminders are per booking/test start, so moving an appointment re-enables
 * the correct new reminder, while repeated scheduler attempts are deduplicated.
 * A claim is committed before notification delivery: it favours avoiding
 * duplicates over guaranteed delivery in the event of a transient push failure.
 */
export const sendLessonReminders = onSchedule(
  { schedule: '0 18 * * *', timeZone: ZONE, region: 'europe-west2' },
  async () => {
    const tomorrow = DateTime.now().setZone(ZONE).plus({ days: 1 }).startOf('day');
    const from = Timestamp.fromMillis(tomorrow.toMillis());
    const to = Timestamp.fromMillis(tomorrow.plus({ days: 1 }).toMillis());

    const bookings = await db.collection('bookings')
      .where('startDateTime', '>=', from)
      .where('startDateTime', '<', to)
      .get();

    for (const doc of bookings.docs) {
      if (doc.get('status') !== 'confirmed') continue;
      const start = (doc.get('startDateTime') as Timestamp).toMillis();
      const key = `evening_${start}`;
      const claimed = await db.runTransaction(async tx => {
        const latest = await tx.get(doc.ref);
        if (latest.get('status') !== 'confirmed' ||
            (latest.get('startDateTime') as Timestamp)?.toMillis() !== start ||
            latest.get(`remindersSent.${key}`) === true) return false;
        tx.update(doc.ref, { [`remindersSent.${key}`]: true });
        return true;
      });
      if (!claimed) continue;
      const time = DateTime.fromMillis(start, { zone: ZONE }).toFormat('h:mm a');
      await notifyUser(doc.get('studentId') as string, {
        title: 'Your driving lesson is tomorrow',
        body: `Your lesson is at ${time}. Pickup: ${doc.get('pickupAddress') || 'Please confirm with your instructor'}. Please bring your provisional driving licence.`,
        type: 'reminder',
        bookingId: doc.id,
      });
    }

    const tests = await db.collection('drivingTests')
      .where('testAt', '>=', from)
      .where('testAt', '<', to)
      .get();

    for (const doc of tests.docs) {
      if (doc.get('status') !== 'scheduled') continue;
      const start = (doc.get('testAt') as Timestamp).toMillis();
      const key = `evening_${start}`;
      const claimed = await db.runTransaction(async tx => {
        const latest = await tx.get(doc.ref);
        if (latest.get('status') !== 'scheduled' ||
            (latest.get('testAt') as Timestamp)?.toMillis() !== start ||
            latest.get(`remindersSent.${key}`) === true) return false;
        tx.update(doc.ref, { [`remindersSent.${key}`]: true, updatedAt: FieldValue.serverTimestamp() });
        return true;
      });
      if (!claimed) continue;
      const testTime = DateTime.fromMillis(start, { zone: ZONE }).toFormat('h:mm a');
      const pickup = doc.get('pickupAt') as Timestamp | undefined;
      const pickupTime = pickup ? DateTime.fromMillis(pickup.toMillis(), { zone: ZONE }).toFormat('h:mm a') : 'Please confirm with your instructor';
      await notifyUser(doc.get('studentId') as string, {
        title: 'Driving test reminder for tomorrow',
        body: `Your driving test is at ${testTime}. Agreed pickup time: ${pickupTime}. Pickup: ${doc.get('pickupAddress') || 'Confirm with your instructor'}. Bring your provisional driving licence.`,
        type: 'reminder',
      });
    }
  },
);

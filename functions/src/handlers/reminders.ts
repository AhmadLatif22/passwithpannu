import { onSchedule } from 'firebase-functions/v2/scheduler';
import { Timestamp } from 'firebase-admin/firestore';
import { db } from '../firebase';
import { formatDayTime } from '../domain/time';
import { loadSettings } from '../services/settings';
import { notifyUser } from '../services/notify';

const GRACE_MS = 60 * 60_000; // never send a reminder more than an hour late

/**
 * Runs every 15 minutes (no dependence on the app being open).
 * Offsets come from app_settings.reminderOffsetsHours (default 24h and 2h).
 * Each reminder is sent once, tracked in booking.remindersSent["h<offset>"].
 */
export const sendLessonReminders = onSchedule({ schedule: 'every 15 minutes', timeZone: 'Europe/London' }, async () => {
  const settings = await loadSettings();
  const now = Date.now();
  const maxOffset = Math.max(...settings.reminderOffsetsHours);
  const snap = await db
    .collection('bookings')
    .where('startDateTime', '>', Timestamp.fromMillis(now))
    .where('startDateTime', '<=', Timestamp.fromMillis(now + maxOffset * 3_600_000))
    .get();

  for (const doc of snap.docs) {
    if (doc.get('status') !== 'confirmed') continue;
    const start = (doc.get('startDateTime') as Timestamp).toMillis();
    const createdAt = (doc.get('createdAt') as Timestamp | null)?.toMillis() ?? 0;
    const sent = (doc.get('remindersSent') ?? {}) as Record<string, boolean>;

    for (const hours of settings.reminderOffsetsHours) {
      const flag = `h${hours}`;
      const due = start - hours * 3_600_000;
      if (sent[flag] || now < due) continue;
      const stale = now - due > GRACE_MS;
      // Booked inside the reminder window (e.g. 5h ahead): the 24h reminder never applies.
      const bookedLate = createdAt > due;
      const claimed = await db.runTransaction(async (tx) => {
        const fresh = await tx.get(doc.ref);
        if (fresh.get(`remindersSent.${flag}`) === true || fresh.get('status') !== 'confirmed') return false;
        tx.update(doc.ref, { [`remindersSent.${flag}`]: true });
        return true;
      });
      if (!claimed || stale || bookedLate) continue;
      await notifyUser(doc.get('studentId') as string, {
        title: 'Lesson reminder',
        body: `Your driving lesson is ${hours >= 24 ? 'tomorrow' : `in ${hours} hours`}: ${formatDayTime(new Date(start), settings.timezone)}.`,
        type: 'reminder',
        bookingId: doc.id,
      });
    }
  }
});

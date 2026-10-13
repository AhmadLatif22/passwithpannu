import { onCall } from 'firebase-functions/v2/https';
import { DateTime } from 'luxon';
import { db } from '../firebase';
import { mapsKey } from '../config';
import { computeAvailableSlots } from '../domain/availability';
import { LESSON_TYPES } from '../domain/types';
import { createTravelService } from '../travel/providers';
import { loadSettings } from '../services/settings';
import { readSchedule } from '../services/schedule';
import { dateKey, enumOf, latLng, requireAuth, str } from './common';

/**
 * Live availability for one day, specific to the student's pickup location
 * (travel time is checked both from the previous and to the next lesson).
 * Lesson type is validated and echoed; both types share one diary.
 */
export const getAvailableSlots = onCall({ secrets: [mapsKey] }, async (req) => {
  requireAuth(req);
  const date = dateKey(req.data, 'date');
  enumOf(req.data, 'lessonType', LESSON_TYPES);
  const pickup = latLng(req.data, 'pickupLatitude', 'pickupLongitude');
  const settings = await loadSettings();
  const travel = createTravelService(settings, mapsKey.value(), db);
  const sched = await readSchedule(db, null, date, settings.timezone);
  const slots = await computeAvailableSlots({ settings, now: new Date(), pickup, travel, ...sched }, date);
  return {
    durationMinutes: settings.lessonDurationMinutes,
    slots: slots.map((s) => ({ start: s.start.toISOString(), end: s.end.toISOString() })),
  };
});

/** Which days of a month (yyyy-MM) have at least one bookable slot, so the calendar can grey out the rest. */
export const getAvailableDates = onCall({ secrets: [mapsKey] }, async (req) => {
  requireAuth(req);
  const month = str(req.data, 'month', 7); // "2026-10"
  if (!/^\d{4}-\d{2}$/.test(month)) throw new Error('bad month');
  const pickup = latLng(req.data, 'pickupLatitude', 'pickupLongitude');
  const settings = await loadSettings();
  const travel = createTravelService(settings, mapsKey.value(), db);
  const zone = settings.timezone;

  const first = DateTime.fromISO(`${month}-01`, { zone });
  const today = DateTime.now().setZone(zone).startOf('day');
  const last = today.plus({ days: settings.maxAdvanceBookingDays });
  const keys: string[] = [];
  for (let d = first; d.month === first.month; d = d.plus({ days: 1 })) {
    if (d >= today && d <= last) keys.push(d.toFormat('yyyy-MM-dd'));
  }

  const available: string[] = [];
  for (let i = 0; i < keys.length; i += 8) {
    const batch = keys.slice(i, i + 8);
    const results = await Promise.all(
      batch.map(async (k) => {
        const sched = await readSchedule(db, null, k, zone);
        const slots = await computeAvailableSlots({ settings, now: new Date(), pickup, travel, ...sched }, k, { stopAtFirst: true });
        return slots.length > 0 ? k : null;
      }),
    );
    available.push(...results.filter((k): k is string => k !== null));
  }
  return { dates: available };
});

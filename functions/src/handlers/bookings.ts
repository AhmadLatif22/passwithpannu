import { onCall } from 'firebase-functions/v2/https';
import { DocumentData, DocumentReference, FieldValue, Timestamp, Transaction } from 'firebase-admin/firestore';
import { randomBytes } from 'crypto';
import { db } from '../firebase';
import { mapsKey } from '../config';
import { checkCandidate, Overrides, RejectReason } from '../domain/availability';
import { canTransition } from '../domain/rules';
import { addMinutes, dayKeyOf, formatDayTime, formatLongDayTime } from '../domain/time';
import { AppSettings, BookingStatus, LatLng, LESSON_TYPES, LessonType } from '../domain/types';
import { TravelTimeService } from '../domain/travel';
import { createTravelService } from '../travel/providers';
import { loadSettings } from '../services/settings';
import { readSchedule } from '../services/schedule';
import { notifyAdmins, notifyUser } from '../services/notify';
import { appError, bool, enumOf, isoDate, latLng, optStr, requireAdmin, requireAuth, str } from './common';
import { HttpsError } from 'firebase-functions/v2/https';

const SECRETS = [mapsKey];

export function slotError(reason: RejectReason): HttpsError {
  return appError('failed-precondition', 'slot_unavailable', 'That time is no longer available.', { reason });
}

/** Admin "override" relaxes everything except overlap with another lesson. */
const ADMIN_OVERRIDE: Overrides = { skipTravel: true, skipBlocks: true, skipHours: true, skipNotice: true };

const bump = (tx: Transaction, ref: DocumentReference) =>
  tx.set(ref, { version: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() }, { merge: true });

const lockRef = (dateKey: string) => db.collection('schedule_days').doc(dateKey);

function reference(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = randomBytes(6);
  return 'PWP-' + Array.from(bytes, (b) => alphabet[b % alphabet.length]).join('');
}

interface PlacementInput {
  lessonType: LessonType;
  start: Date;
  pickupAddress: string;
  pickup: LatLng;
}

function parsePlacement(data: unknown): PlacementInput {
  return {
    lessonType: enumOf(data, 'lessonType', LESSON_TYPES),
    start: isoDate(data, 'startIso'),
    pickupAddress: str(data, 'pickupAddress', 300),
    pickup: latLng(data, 'pickupLatitude', 'pickupLongitude'),
  };
}

async function loadProfile(uid: string): Promise<DocumentData> {
  const snap = await db.collection('users').doc(uid).get();
  if (!snap.exists || snap.get('isActive') === false) {
    throw appError('failed-precondition', 'profile_missing', 'Your account is not active.');
  }
  return snap.data()!;
}

/**
 * Creates a booking atomically. A per-day lock document is read and written in
 * every scheduling transaction, so two requests for the same day always
 * serialise: the loser re-reads the diary and fails with `slot_unavailable`.
 */
async function createBookingCore(opts: {
  studentId: string;
  actorId: string;
  input: PlacementInput;
  settings: AppSettings;
  travel: TravelTimeService;
  overrides?: Overrides;
  forceConfirmed: boolean;
}): Promise<{ id: string; reference: string; status: BookingStatus; start: Date; end: Date }> {
  const { studentId, actorId, input, settings, travel, overrides } = opts;
  const profile = await loadProfile(studentId);
  const zone = settings.timezone;
  const end = addMinutes(input.start, settings.lessonDurationMinutes);
  const dateKey = dayKeyOf(input.start, zone);
  const ctxBase = { settings, pickup: input.pickup, travel, overrides };

  // Pre-check outside the transaction: fails fast and warms the travel cache.
  {
    const sched = await readSchedule(db, null, dateKey, zone);
    const pre = await checkCandidate({ ...ctxBase, now: new Date(), ...sched }, input.start);
    if (!pre.ok) throw slotError(pre.reason);
  }

  const status: BookingStatus = opts.forceConfirmed || !settings.requireAdminApproval ? 'confirmed' : 'pending';
  const ref = db.collection('bookings').doc();
  const refCode = reference();

  await db.runTransaction(async (tx) => {
    await tx.get(lockRef(dateKey));
    const sched = await readSchedule(db, tx, dateKey, zone);
    const res = await checkCandidate({ ...ctxBase, now: new Date(), ...sched }, input.start);
    if (!res.ok) throw slotError(res.reason);
    bump(tx, lockRef(dateKey));
    tx.set(ref, {
      bookingId: ref.id,
      reference: refCode,
      studentId,
      studentName: profile.fullName ?? '',
      studentEmail: profile.email ?? '',
      studentPhone: profile.phone ?? null,
      lessonType: input.lessonType,
      startDateTime: Timestamp.fromDate(input.start),
      endDateTime: Timestamp.fromDate(end),
      durationMinutes: settings.lessonDurationMinutes,
      dayKey: dateKey,
      pickupAddress: input.pickupAddress,
      pickupLatitude: input.pickup.lat,
      pickupLongitude: input.pickup.lng,
      status,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      createdBy: actorId,
      updatedBy: actorId,
      cancellationReason: null,
      cancelledBy: null,
      cancelledAt: null,
      previousStartTime: null,
      newStartTime: null,
      adminNotes: null,
      remindersSent: {},
    });
  });

  const when = formatDayTime(input.start, zone);
  await notifyUser(studentId, {
    title: status === 'confirmed' ? 'Lesson confirmed' : 'Booking received',
    body:
      status === 'confirmed'
        ? `Your ${input.lessonType} driving lesson on ${when} is confirmed.`
        : `Your ${input.lessonType} lesson request for ${when} was received and is awaiting confirmation.`,
    type: status === 'confirmed' ? 'booking_confirmed' : 'booking_created',
    bookingId: ref.id,
  });
  if (actorId === studentId) {
    await notifyAdmins({
      title: 'New booking',
      body: `${profile.fullName ?? 'A student'} booked a ${input.lessonType} lesson on ${when}.`,
      type: 'booking_created',
      bookingId: ref.id,
    });
  }
  return { id: ref.id, reference: refCode, status, start: input.start, end };
}

export const createBooking = onCall({ secrets: SECRETS }, async (req) => {
  const uid = requireAuth(req);
  const settings = await loadSettings();
  const travel = createTravelService(settings, mapsKey.value(), db);
  const r = await createBookingCore({
    studentId: uid,
    actorId: uid,
    input: parsePlacement(req.data),
    settings,
    travel,
    forceConfirmed: false,
  });
  return { bookingId: r.id, reference: r.reference, status: r.status, start: r.start.toISOString(), end: r.end.toISOString() };
});

export const adminCreateBooking = onCall({ secrets: SECRETS }, async (req) => {
  const adminUid = requireAdmin(req);
  const studentId = str(req.data, 'studentId', 128);
  const settings = await loadSettings();
  const travel = createTravelService(settings, mapsKey.value(), db);
  const r = await createBookingCore({
    studentId,
    actorId: adminUid,
    input: parsePlacement(req.data),
    settings,
    travel,
    overrides: bool(req.data, 'override') ? ADMIN_OVERRIDE : { skipNotice: true },
    forceConfirmed: true,
  });
  return { bookingId: r.id, reference: r.reference };
});

/**
 * Reads + validates a move; returns a `commit` closure that performs the writes.
 * Splitting it this way keeps Firestore's "all reads before writes" rule while
 * letting both the admin reschedule and request-approval flows share the logic.
 */
export async function planMove(
  tx: Transaction,
  p: {
    bookingRef: DocumentReference;
    booking: DocumentData;
    newStart: Date;
    settings: AppSettings;
    travel: TravelTimeService;
    adminUid: string;
    overrides?: Overrides;
  },
): Promise<{ commit: (extra?: Record<string, unknown>) => void; oldStart: Date; newEnd: Date }> {
  const zone = p.settings.timezone;
  const oldStart = (p.booking.startDateTime as Timestamp).toDate();
  const newKey = dayKeyOf(p.newStart, zone);
  const keys = Array.from(new Set([p.booking.dayKey as string, newKey])).sort();
  const locks = keys.map(lockRef);
  await Promise.all(locks.map((r) => tx.get(r)));

  const sched = await readSchedule(db, tx, newKey, zone, p.bookingRef.id);
  const res = await checkCandidate(
    {
      settings: p.settings,
      now: new Date(),
      pickup: { lat: p.booking.pickupLatitude as number, lng: p.booking.pickupLongitude as number },
      travel: p.travel,
      overrides: p.overrides,
      ...sched,
    },
    p.newStart,
  );
  if (!res.ok) throw slotError(res.reason);

  const newEnd = addMinutes(p.newStart, p.settings.lessonDurationMinutes);
  return {
    oldStart,
    newEnd,
    commit: (extra = {}) => {
      locks.forEach((l) => bump(tx, l));
      tx.update(p.bookingRef, {
        startDateTime: Timestamp.fromDate(p.newStart),
        endDateTime: Timestamp.fromDate(newEnd),
        dayKey: newKey,
        previousStartTime: Timestamp.fromDate(oldStart),
        newStartTime: Timestamp.fromDate(p.newStart),
        status: 'confirmed',
        remindersSent: {},
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: p.adminUid,
        ...extra,
      });
    },
  };
}

export const adminRescheduleBooking = onCall({ secrets: SECRETS }, async (req) => {
  const adminUid = requireAdmin(req);
  const bookingId = str(req.data, 'bookingId', 128);
  const newStart = isoDate(req.data, 'newStartIso');
  const settings = await loadSettings();
  const travel = createTravelService(settings, mapsKey.value(), db);
  const overrides = bool(req.data, 'override') ? ADMIN_OVERRIDE : { skipNotice: true, skipHours: true };
  const bookingRef = db.collection('bookings').doc(bookingId);

  const { studentId, lessonType } = await db.runTransaction(async (tx) => {
    const snap = await tx.get(bookingRef);
    if (!snap.exists) throw appError('not-found', 'booking_not_found', 'Booking not found.');
    const booking = snap.data()!;
    if (booking.status === 'changeRequested' || booking.status === 'cancellationRequested') {
      throw appError('failed-precondition', 'resolve_request_first', 'Resolve the student’s open request first.');
    }
    if (booking.status !== 'confirmed' && booking.status !== 'pending') {
      throw appError('failed-precondition', 'invalid_status', 'This lesson can no longer be moved.');
    }
    const plan = await planMove(tx, { bookingRef, booking, newStart, settings, travel, adminUid, overrides });
    plan.commit();
    return { studentId: booking.studentId as string, lessonType: booking.lessonType as string };
  });

  await notifyUser(studentId, {
    title: 'Lesson rescheduled',
    body: `Your driving lesson has been rescheduled to ${formatLongDayTime(newStart, settings.timezone)}.`,
    type: 'booking_rescheduled',
    bookingId,
  });
  return { ok: true, lessonType };
});

export const adminCancelBooking = onCall(async (req) => {
  const adminUid = requireAdmin(req);
  const bookingId = str(req.data, 'bookingId', 128);
  const reason = str(req.data, 'reason', 500);
  const settings = await loadSettings();
  const bookingRef = db.collection('bookings').doc(bookingId);

  const { studentId, start } = await db.runTransaction(async (tx) => {
    const snap = await tx.get(bookingRef);
    if (!snap.exists) throw appError('not-found', 'booking_not_found', 'Booking not found.');
    const b = snap.data()!;
    if (!canTransition(b.status as BookingStatus, 'cancelled')) {
      throw appError('failed-precondition', 'invalid_status', 'This lesson cannot be cancelled.');
    }
    const open = await tx.get(db.collection('booking_requests').where('bookingId', '==', bookingId).where('status', '==', 'pending'));
    tx.update(bookingRef, {
      status: 'cancelled',
      cancelledBy: adminUid,
      cancellationReason: reason,
      cancelledAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: adminUid,
    });
    open.docs.forEach((d) =>
      tx.update(d.ref, {
        // A pending cancellation request is effectively granted; a change request is moot.
        status: d.get('requestType') === 'cancel' ? 'approved' : 'rejected',
        adminResponse: 'Lesson cancelled by Pass With Pannu.',
        resolvedAt: FieldValue.serverTimestamp(),
        resolvedBy: adminUid,
      }),
    );
    return { studentId: b.studentId as string, start: (b.startDateTime as Timestamp).toDate() };
  });

  await notifyUser(studentId, {
    title: 'Lesson cancelled',
    body: `Your driving lesson scheduled for ${formatDayTime(start, settings.timezone)} has been cancelled by Pass With Pannu.`,
    type: 'booking_cancelled',
    bookingId,
  });
  return { ok: true };
});

export const adminCompleteBooking = onCall(async (req) => {
  const adminUid = requireAdmin(req);
  const bookingId = str(req.data, 'bookingId', 128);
  const bookingRef = db.collection('bookings').doc(bookingId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(bookingRef);
    if (!snap.exists) throw appError('not-found', 'booking_not_found', 'Booking not found.');
    const b = snap.data()!;
    if (!canTransition(b.status as BookingStatus, 'completed')) {
      throw appError('failed-precondition', 'invalid_status', 'This lesson cannot be completed.');
    }
    if ((b.startDateTime as Timestamp).toMillis() > Date.now()) {
      throw appError('failed-precondition', 'not_started', 'The lesson has not started yet.');
    }
    tx.update(bookingRef, { status: 'completed', updatedAt: FieldValue.serverTimestamp(), updatedBy: adminUid });
  });
  return { ok: true };
});

/** Edit lesson details that don't move the time: type, pickup, private admin notes. */
export const adminUpdateBooking = onCall({ secrets: SECRETS }, async (req) => {
  const adminUid = requireAdmin(req);
  const bookingId = str(req.data, 'bookingId', 128);
  const settings = await loadSettings();
  const travel = createTravelService(settings, mapsKey.value(), db);
  const bookingRef = db.collection('bookings').doc(bookingId);
  const data = (req.data ?? {}) as Record<string, unknown>;
  const patch: Record<string, unknown> = {};
  if (data.lessonType !== undefined) patch.lessonType = enumOf(data, 'lessonType', LESSON_TYPES);
  if (data.adminNotes !== undefined) patch.adminNotes = optStr(data, 'adminNotes', 1000) ?? null;
  const newPickup = data.pickupAddress !== undefined;
  if (newPickup) {
    patch.pickupAddress = str(data, 'pickupAddress', 300);
    const p = latLng(data, 'pickupLatitude', 'pickupLongitude');
    patch.pickupLatitude = p.lat;
    patch.pickupLongitude = p.lng;
  }

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(bookingRef);
    if (!snap.exists) throw appError('not-found', 'booking_not_found', 'Booking not found.');
    const b = snap.data()!;
    if (!['pending', 'confirmed', 'changeRequested', 'cancellationRequested'].includes(b.status as string)) {
      throw appError('failed-precondition', 'invalid_status', 'This lesson can no longer be edited.');
    }
    if (newPickup) {
      const zone = settings.timezone;
      await tx.get(lockRef(b.dayKey as string));
      const sched = await readSchedule(db, tx, b.dayKey as string, zone, bookingId);
      const res = await checkCandidate(
        {
          settings,
          now: new Date(Date.now() - 365 * 86_400_000), // editing an in-progress/past lesson is allowed
          pickup: { lat: patch.pickupLatitude as number, lng: patch.pickupLongitude as number },
          travel,
          overrides: bool(data, 'override') ? ADMIN_OVERRIDE : { skipNotice: true, skipHours: true, skipBlocks: true },
          ...sched,
        },
        (b.startDateTime as Timestamp).toDate(),
      );
      if (!res.ok) throw slotError(res.reason);
      bump(tx, lockRef(b.dayKey as string));
    }
    tx.update(bookingRef, { ...patch, updatedAt: FieldValue.serverTimestamp(), updatedBy: adminUid });
  });
  return { ok: true };
});

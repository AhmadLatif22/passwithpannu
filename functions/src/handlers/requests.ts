import { onCall } from 'firebase-functions/v2/https';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { db } from '../firebase';
import { mapsKey } from '../config';
import { canTransition, requestOutcome, studentMayRequestChange } from '../domain/rules';
import { formatDayTime, formatLongDayTime } from '../domain/time';
import { BookingStatus, RequestType } from '../domain/types';
import { createTravelService } from '../travel/providers';
import { loadSettings } from '../services/settings';
import { notifyAdmins, notifyUser } from '../services/notify';
import { appError, bool, enumOf, isoDate, optStr, requireAdmin, requireAuth, str } from './common';
import { planMove } from './bookings';

const REQUEST_TYPES = ['reschedule', 'cancel'] as const;

/**
 * Student change / cancellation REQUEST. The lesson time is never touched here;
 * only the status flips so the slot stays held until the admin decides.
 */
export const createBookingRequest = onCall(async (req) => {
  const uid = requireAuth(req);
  const bookingId = str(req.data, 'bookingId', 128);
  const type: RequestType = enumOf(req.data, 'requestType', REQUEST_TYPES);
  const reason = optStr(req.data, 'reason', 1000);
  const requestedRaw = optStr(req.data, 'requestedStartIso', 40);
  const requestedStart = requestedRaw ? isoDate(req.data, 'requestedStartIso') : undefined;
  const settings = await loadSettings();

  if (type === 'cancel' && (!reason || reason.length < 5)) {
    throw appError('invalid-argument', 'reason_required', 'Please tell us why you need to cancel.');
  }
  if (requestedStart && requestedStart.getTime() <= Date.now()) {
    throw appError('invalid-argument', 'invalid_input', 'Preferred time must be in the future.');
  }

  const bookingRef = db.collection('bookings').doc(bookingId);
  const reqRef = db.collection('booking_requests').doc();

  const info = await db.runTransaction(async (tx) => {
    const snap = await tx.get(bookingRef);
    if (!snap.exists || snap.get('studentId') !== uid) throw appError('not-found', 'booking_not_found', 'Booking not found.');
    const b = snap.data()!;
    const open = await tx.get(db.collection('booking_requests').where('bookingId', '==', bookingId).where('status', '==', 'pending'));
    if (!open.empty) throw appError('failed-precondition', 'request_already_open', 'You already have an open request for this lesson.');
    if (b.status !== 'confirmed') throw appError('failed-precondition', 'not_confirmed', 'Only confirmed lessons can be changed.');

    const start = (b.startDateTime as Timestamp).toDate();
    if (!studentMayRequestChange(start, new Date(), settings.studentChangeNoticeHours)) {
      throw appError(
        'failed-precondition',
        'too_late_to_change',
        'Changes or cancellations must normally be requested at least 48 hours before your lesson.',
      );
    }
    const next: BookingStatus = type === 'cancel' ? 'cancellationRequested' : 'changeRequested';
    tx.set(reqRef, {
      requestId: reqRef.id,
      bookingId,
      studentId: uid,
      studentName: b.studentName,
      reference: b.reference,
      lessonType: b.lessonType,
      pickupAddress: b.pickupAddress,
      requestType: type,
      currentDateTime: b.startDateTime,
      requestedDateTime: requestedStart ? Timestamp.fromDate(requestedStart) : null,
      reason: reason ?? null,
      status: 'pending',
      adminResponse: null,
      createdAt: FieldValue.serverTimestamp(),
      resolvedAt: null,
      resolvedBy: null,
    });
    tx.update(bookingRef, { status: next, updatedAt: FieldValue.serverTimestamp(), updatedBy: uid });
    return { start, studentName: b.studentName as string };
  });

  await notifyAdmins({
    title: type === 'cancel' ? 'Cancellation request' : 'Change request',
    body: `${info.studentName} asked to ${type === 'cancel' ? 'cancel' : 'change'} their lesson on ${formatDayTime(info.start, settings.timezone)}.`,
    type: 'request_created',
    bookingId,
  });
  return { requestId: reqRef.id };
});

export const resolveBookingRequest = onCall({ secrets: [mapsKey] }, async (req) => {
  const adminUid = requireAdmin(req);
  const requestId = str(req.data, 'requestId', 128);
  const decision = enumOf(req.data, 'decision', ['approve', 'reject'] as const);
  const adminResponse = optStr(req.data, 'adminResponse', 1000) ?? null;
  const settings = await loadSettings();
  const travel = createTravelService(settings, mapsKey.value(), db);
  const reqRef = db.collection('booking_requests').doc(requestId);

  const out = await db.runTransaction(async (tx) => {
    const rSnap = await tx.get(reqRef);
    if (!rSnap.exists) throw appError('not-found', 'request_not_found', 'Request not found.');
    const r = rSnap.data()!;
    if (r.status !== 'pending') throw appError('failed-precondition', 'already_resolved', 'This request was already handled.');
    const bookingRef = db.collection('bookings').doc(r.bookingId as string);
    const bSnap = await tx.get(bookingRef);
    if (!bSnap.exists) throw appError('not-found', 'booking_not_found', 'Booking not found.');
    const b = bSnap.data()!;
    const type = r.requestType as RequestType;
    const outcome = requestOutcome(type, decision);
    if (!canTransition(b.status as BookingStatus, outcome.bookingStatus)) {
      throw appError('failed-precondition', 'invalid_status', 'The booking is no longer in a state that allows this.');
    }

    let newStart: Date | undefined;
    let plan: Awaited<ReturnType<typeof planMove>> | undefined;
    if (outcome.applyNewTime) {
      newStart = isoDate(req.data, 'newStartIso'); // admin confirms the final slot
      plan = await planMove(tx, {
        bookingRef,
        booking: b,
        newStart,
        settings,
        travel,
        adminUid,
        overrides: bool(req.data, 'override')
          ? { skipTravel: true, skipBlocks: true, skipHours: true, skipNotice: true }
          : { skipNotice: true, skipHours: true },
      });
    }

    tx.update(reqRef, {
      status: decision === 'approve' ? 'approved' : 'rejected',
      adminResponse,
      resolvedAt: FieldValue.serverTimestamp(),
      resolvedBy: adminUid,
    });
    if (plan) {
      plan.commit();
    } else if (type === 'cancel' && decision === 'approve') {
      tx.update(bookingRef, {
        status: 'cancelled',
        cancelledBy: adminUid,
        cancellationReason: (r.reason as string | null) ?? 'Cancelled at student request',
        cancelledAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: adminUid,
      });
    } else {
      // Rejected: the original booking stays exactly as it was.
      tx.update(bookingRef, { status: 'confirmed', updatedAt: FieldValue.serverTimestamp(), updatedBy: adminUid });
    }
    return { studentId: r.studentId as string, bookingId: r.bookingId as string, type, start: (b.startDateTime as Timestamp).toDate(), newStart };
  });

  const zone = settings.timezone;
  const note = adminResponse ? ` ${adminResponse}` : '';
  let body: string;
  if (decision === 'reject') {
    body = `Your request to ${out.type === 'cancel' ? 'cancel' : 'change'} your lesson on ${formatDayTime(out.start, zone)} was declined. Your lesson is unchanged.${note}`;
  } else if (out.type === 'cancel') {
    body = `Your cancellation request was approved. Your lesson on ${formatDayTime(out.start, zone)} is cancelled.${note}`;
  } else {
    body = `Your change request was approved. Your lesson is now ${formatLongDayTime(out.newStart!, zone)}.${note}`;
  }
  await notifyUser(out.studentId, {
    title: decision === 'approve' ? 'Request approved' : 'Request declined',
    body,
    type: decision === 'approve' ? 'request_approved' : 'request_rejected',
    bookingId: out.bookingId,
  });
  return { ok: true };
});

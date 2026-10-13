import { BookingStatus, RequestType } from './types';

export const ALLOWED_TRANSITIONS: Record<BookingStatus, BookingStatus[]> = {
  pending: ['confirmed', 'rejected', 'cancelled'],
  confirmed: ['changeRequested', 'cancellationRequested', 'cancelled', 'completed'],
  changeRequested: ['confirmed', 'cancelled', 'completed'],
  cancellationRequested: ['cancelled', 'confirmed', 'completed'],
  cancelled: [],
  completed: [],
  rejected: [],
};

export function canTransition(from: BookingStatus, to: BookingStatus): boolean {
  return ALLOWED_TRANSITIONS[from].includes(to);
}

export function hoursUntil(start: Date, now: Date): number {
  return (start.getTime() - now.getTime()) / 3_600_000;
}

/** 48-hour rule: students may only request a change/cancellation with enough notice. */
export function studentMayRequestChange(start: Date, now: Date, noticeHours: number): boolean {
  return hoursUntil(start, now) >= noticeHours;
}

/** Half-open interval overlap: back-to-back ranges do NOT overlap. */
export function overlaps(aStart: Date, aEnd: Date, bStart: Date, bEnd: Date): boolean {
  return aStart.getTime() < bEnd.getTime() && bStart.getTime() < aEnd.getTime();
}

export interface RequestOutcome {
  bookingStatus: BookingStatus;
  applyNewTime: boolean;
}

/**
 * What happens to the booking when the admin resolves a request.
 * A request on its own never changes the lesson time; only an approved
 * reschedule does, and only with a slot the admin confirms.
 */
export function requestOutcome(type: RequestType, decision: 'approve' | 'reject'): RequestOutcome {
  if (decision === 'reject') return { bookingStatus: 'confirmed', applyNewTime: false };
  if (type === 'cancel') return { bookingStatus: 'cancelled', applyNewTime: false };
  return { bookingStatus: 'confirmed', applyNewTime: true };
}

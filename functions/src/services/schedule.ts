import { Firestore, Query, Timestamp, Transaction } from 'firebase-admin/firestore';
import { BusyBooking, TimeBlock } from '../domain/availability';
import { dayBounds } from '../domain/time';
import { BookingStatus, OCCUPYING_STATUSES } from '../domain/types';

export interface ScheduleSnapshot {
  bookings: BusyBooking[];
  blocks: TimeBlock[];
}

/**
 * Reads everything that can occupy [dateKey]. Pass [tx] to read inside a transaction.
 * Queries use a single field each, so no composite indexes are needed.
 */
export async function readSchedule(
  db: Firestore,
  tx: Transaction | null,
  dateKey: string,
  zone: string,
  excludeBookingId?: string,
): Promise<ScheduleSnapshot> {
  const run = (q: Query) => (tx ? tx.get(q) : q.get());
  const { start, end } = dayBounds(dateKey, zone);
  const [bSnap, blSnap] = await Promise.all([
    run(db.collection('bookings').where('dayKey', '==', dateKey)),
    run(db.collection('availability_blocks').where('endDateTime', '>', Timestamp.fromDate(start))),
  ]);

  const bookings: BusyBooking[] = bSnap.docs
    .filter((d) => d.id !== excludeBookingId && OCCUPYING_STATUSES.includes(d.get('status') as BookingStatus))
    .map((d) => ({
      id: d.id,
      start: (d.get('startDateTime') as Timestamp).toDate(),
      end: (d.get('endDateTime') as Timestamp).toDate(),
      location: { lat: d.get('pickupLatitude') as number, lng: d.get('pickupLongitude') as number },
    }));

  const blocks: TimeBlock[] = blSnap.docs
    .map((d) => ({ start: (d.get('startDateTime') as Timestamp).toDate(), end: (d.get('endDateTime') as Timestamp).toDate() }))
    .filter((b) => b.start.getTime() < end.getTime());

  return { bookings, blocks };
}

import { DateTime } from 'luxon';
import { checkCandidate, computeAvailableSlots, ScheduleContext } from './availability';
import { canTransition, ALLOWED_TRANSITIONS, hoursUntil, overlaps, requestOutcome, studentMayRequestChange } from './rules';
import { addMinutes, dayKeyOf, formatDayTime } from './time';
import { DEFAULT_SETTINGS, BookingStatus } from './types';
import { TravelTimeService } from './travel';

const Z = 'Europe/London';
const london = (iso: string) => DateTime.fromISO(iso, { zone: Z }).toJSDate();
const A = { lat: 52.92, lng: -1.47 };
const B = { lat: 52.95, lng: -1.5 };

/** Fixed 25-minute drive between different places, 0 for the same place. */
const travel25: TravelTimeService = {
  getMinutes: async (a, b) => (a.lat === b.lat && a.lng === b.lng ? 0 : 25),
};

const NOW = london('2026-10-05T08:00:00'); // Monday
const ctx = (over: Partial<ScheduleContext> = {}): ScheduleContext => ({
  settings: DEFAULT_SETTINGS,
  now: NOW,
  bookings: [],
  blocks: [],
  pickup: B,
  travel: travel25,
  ...over,
});
const lesson = (id: string, s: string, loc = A) => {
  const start = london(s);
  return { id, start, end: addMinutes(start, 120), location: loc };
};

describe('duration & time utils', () => {
  it('lesson end = start + 2h', () => {
    const s = london('2026-10-12T10:00:00');
    expect(addMinutes(s, DEFAULT_SETTINGS.lessonDurationMinutes).toISOString()).toBe(london('2026-10-12T12:00:00').toISOString());
  });
  it('dayKey uses the business zone (BST midnight edge)', () => {
    expect(dayKeyOf(new Date('2026-10-12T23:30:00Z'), Z)).toBe('2026-10-13'); // 00:30 BST
    expect(formatDayTime(london('2026-10-12T10:00:00'), Z)).toBe('12 October at 10:00 AM');
  });
});

describe('48-hour rule', () => {
  const start = london('2026-10-12T10:00:00');
  it('allows exactly 48h and more', () => {
    expect(studentMayRequestChange(start, addMinutes(start, -48 * 60), 48)).toBe(true);
    expect(studentMayRequestChange(start, addMinutes(start, -72 * 60), 48)).toBe(true);
  });
  it('blocks under 48h', () => {
    expect(studentMayRequestChange(start, addMinutes(start, -47 * 60 - 59), 48)).toBe(false);
    expect(hoursUntil(start, addMinutes(start, -24 * 60))).toBe(24);
  });
});

describe('status transitions', () => {
  it('terminal states allow nothing', () => {
    for (const s of ['cancelled', 'completed', 'rejected'] as BookingStatus[]) expect(ALLOWED_TRANSITIONS[s]).toEqual([]);
  });
  it('students path: confirmed -> changeRequested -> confirmed', () => {
    expect(canTransition('confirmed', 'changeRequested')).toBe(true);
    expect(canTransition('changeRequested', 'confirmed')).toBe(true);
    expect(canTransition('cancelled', 'confirmed')).toBe(false);
    expect(canTransition('completed', 'cancelled')).toBe(false);
  });
});

describe('request workflow', () => {
  it('reject leaves booking confirmed with no time change', () => {
    expect(requestOutcome('reschedule', 'reject')).toEqual({ bookingStatus: 'confirmed', applyNewTime: false });
    expect(requestOutcome('cancel', 'reject')).toEqual({ bookingStatus: 'confirmed', applyNewTime: false });
  });
  it('approved cancel cancels; approved reschedule applies new time', () => {
    expect(requestOutcome('cancel', 'approve')).toEqual({ bookingStatus: 'cancelled', applyNewTime: false });
    expect(requestOutcome('reschedule', 'approve')).toEqual({ bookingStatus: 'confirmed', applyNewTime: true });
  });
});

describe('overlap', () => {
  it('back-to-back is not an overlap, partial is', () => {
    const a = london('2026-10-12T10:00:00');
    const b = london('2026-10-12T12:00:00');
    expect(overlaps(a, b, b, addMinutes(b, 120))).toBe(false);
    expect(overlaps(a, b, addMinutes(a, 60), addMinutes(b, 60))).toBe(true);
  });
});

describe('availability engine', () => {
  it('rejects the past, too-soon, outside hours, Sundays and misaligned starts', async () => {
    expect(await checkCandidate(ctx(), london('2026-10-05T07:00:00'))).toEqual({ ok: false, reason: 'in_past' });
    expect(await checkCandidate(ctx(), london('2026-10-05T12:00:00'))).toEqual({ ok: false, reason: 'too_soon' });
    expect(await checkCandidate(ctx(), london('2026-10-06T07:00:00'))).toEqual({ ok: false, reason: 'outside_hours' });
    expect(await checkCandidate(ctx(), london('2026-10-06T17:00:00'))).toEqual({ ok: false, reason: 'outside_hours' }); // ends 19:00
    expect(await checkCandidate(ctx(), london('2026-10-11T10:00:00'))).toEqual({ ok: false, reason: 'outside_hours' }); // Sunday
    expect(await checkCandidate(ctx(), london('2026-10-06T10:15:00'))).toEqual({ ok: false, reason: 'misaligned' });
  });

  it('rejects overlaps and blocked periods', async () => {
    const c = ctx({ bookings: [lesson('x', '2026-10-06T10:00:00', B)] });
    expect(await checkCandidate(c, london('2026-10-06T11:00:00'))).toEqual({ ok: false, reason: 'overlap' });
    const blocked = ctx({ blocks: [{ start: london('2026-10-06T12:00:00'), end: london('2026-10-06T15:00:00') }] });
    expect(await checkCandidate(blocked, london('2026-10-06T10:30:00'))).toEqual({ ok: false, reason: 'blocked' });
    expect(await checkCandidate(blocked, london('2026-10-06T15:00:00'))).toEqual({ ok: true });
  });

  it('travel buffer: previous ends 12:00 at A, 25 min drive + 10 min buffer', async () => {
    const c = ctx({ bookings: [lesson('a', '2026-10-06T10:00:00', A)], pickup: B });
    expect(await checkCandidate(c, london('2026-10-06T12:00:00'))).toEqual({ ok: false, reason: 'travel_before' });
    expect(await checkCandidate(c, london('2026-10-06T12:30:00'))).toEqual({ ok: false, reason: 'travel_before' }); // 12:35 needed
    expect(await checkCandidate(c, london('2026-10-06T13:00:00'))).toEqual({ ok: true });
  });

  it('same pickup place needs only the buffer', async () => {
    const c = ctx({ bookings: [lesson('a', '2026-10-06T10:00:00', A)], pickup: A });
    expect(await checkCandidate(c, london('2026-10-06T12:00:00'))).toEqual({ ok: false, reason: 'travel_before' }); // buffer 10
    expect(await checkCandidate(c, london('2026-10-06T12:30:00'))).toEqual({ ok: true });
  });

  it('checks the NEXT lesson too (new -> next)', async () => {
    const c = ctx({ bookings: [lesson('n', '2026-10-06T14:00:00', A)], pickup: B });
    // 10:00-12:00 then 25+10 min drive -> 12:35 <= 14:00 ok
    expect(await checkCandidate(c, london('2026-10-06T10:00:00'))).toEqual({ ok: true });
    // 11:30-13:30 + 35 = 14:05 > 14:00 -> not feasible
    expect(await checkCandidate(c, london('2026-10-06T11:30:00'))).toEqual({ ok: false, reason: 'travel_after' });
  });

  it('admin overrides relax travel/blocks but never overlap', async () => {
    const c = ctx({ bookings: [lesson('a', '2026-10-06T10:00:00', A)], overrides: { skipTravel: true, skipBlocks: true } });
    expect(await checkCandidate(c, london('2026-10-06T12:00:00'))).toEqual({ ok: true });
    expect(await checkCandidate(c, london('2026-10-06T11:00:00'))).toEqual({ ok: false, reason: 'overlap' });
  });

  it('lists only genuinely valid slots for a day', async () => {
    const c = ctx({ bookings: [lesson('a', '2026-10-06T10:00:00', A)], pickup: B });
    const slots = await computeAvailableSlots(c, '2026-10-06');
    const starts = slots.map((s) => DateTime.fromJSDate(s.start, { zone: Z }).toFormat('HH:mm'));
    // 08:00-10:00 then 35 min travel -> 08:00 needs end+35<=10:00 => ok (10:35 > 10:00!) check below
    expect(starts).not.toContain('10:00');
    expect(starts).not.toContain('12:00');
    expect(starts).not.toContain('12:30');
    expect(starts).toContain('13:00');
    expect(starts).toContain('16:00'); // last slot ending 18:00
    expect(starts).not.toContain('16:30');
  });
});

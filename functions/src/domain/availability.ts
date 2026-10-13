import { AppSettings, LatLng } from './types';
import { addMinutes, dayKeyOf, isoWeekday, workingWindow } from './time';
import { TravelTimeService } from './travel';
import { overlaps } from './rules';

export interface BusyBooking {
  id: string;
  start: Date;
  end: Date;
  location: LatLng;
}
export interface TimeBlock {
  start: Date;
  end: Date;
}
export interface Slot {
  start: Date;
  end: Date;
}
/** Admin-only relaxations. Overlap with another lesson can NEVER be overridden. */
export interface Overrides {
  skipTravel?: boolean;
  skipBlocks?: boolean;
  skipHours?: boolean;
  skipNotice?: boolean;
}

export type RejectReason =
  | 'in_past'
  | 'too_soon'
  | 'too_far_ahead'
  | 'outside_hours'
  | 'misaligned'
  | 'blocked'
  | 'overlap'
  | 'travel_before'
  | 'travel_after';

export type CheckResult = { ok: true } | { ok: false; reason: RejectReason };

export interface ScheduleContext {
  settings: AppSettings;
  now: Date;
  /** Occupying bookings on the candidate's day (excluding the booking being moved). */
  bookings: BusyBooking[];
  blocks: TimeBlock[];
  pickup: LatLng;
  travel: TravelTimeService;
  overrides?: Overrides;
}

const fail = (reason: RejectReason): CheckResult => ({ ok: false, reason });

function memoTravel(t: TravelTimeService): TravelTimeService {
  const cache = new Map<string, Promise<number>>();
  return {
    getMinutes(a, b, at) {
      const k = `${a.lat},${a.lng}|${b.lat},${b.lng}|${at.getTime()}`;
      let p = cache.get(k);
      if (!p) {
        p = t.getMinutes(a, b, at);
        cache.set(k, p);
      }
      return p;
    },
  };
}

/**
 * The one place that decides whether a lesson may start at [start].
 * Used both to list slots and (inside a transaction) to validate a booking.
 *
 *   previous.end + travel(previous -> new) + buffer <= new.start
 *   new.end      + travel(new -> next)     + buffer <= next.start
 */
export async function checkCandidate(ctx: ScheduleContext, start: Date): Promise<CheckResult> {
  const { settings, now } = ctx;
  const o = ctx.overrides ?? {};
  const zone = settings.timezone;
  const end = addMinutes(start, settings.lessonDurationMinutes);

  if (start.getTime() <= now.getTime()) return fail('in_past');

  if (!o.skipNotice) {
    if (start.getTime() < now.getTime() + settings.minBookingNoticeHours * 3_600_000) return fail('too_soon');
    if (start.getTime() > now.getTime() + settings.maxAdvanceBookingDays * 86_400_000) return fail('too_far_ahead');
  }

  if (!o.skipHours) {
    const dateKey = dayKeyOf(start, zone);
    const wh = settings.workingHours[String(isoWeekday(dateKey, zone))];
    if (!wh) return fail('outside_hours');
    const { open, close } = workingWindow(dateKey, zone, wh);
    if (start < open || end > close) return fail('outside_hours');
    const offsetMin = (start.getTime() - open.getTime()) / 60_000;
    if (offsetMin % settings.slotStepMinutes !== 0) return fail('misaligned');
  }

  if (!o.skipBlocks && ctx.blocks.some((b) => overlaps(start, end, b.start, b.end))) return fail('blocked');
  if (ctx.bookings.some((b) => overlaps(start, end, b.start, b.end))) return fail('overlap');

  if (!o.skipTravel) {
    const buffer = settings.travelBufferMinutes;
    const prev = ctx.bookings
      .filter((b) => b.end.getTime() <= start.getTime())
      .sort((a, b) => b.end.getTime() - a.end.getTime())[0];
    const next = ctx.bookings
      .filter((b) => b.start.getTime() >= end.getTime())
      .sort((a, b) => a.start.getTime() - b.start.getTime())[0];

    if (prev) {
      const mins = await ctx.travel.getMinutes(prev.location, ctx.pickup, prev.end);
      if (addMinutes(prev.end, mins + buffer).getTime() > start.getTime()) return fail('travel_before');
    }
    if (next) {
      const mins = await ctx.travel.getMinutes(ctx.pickup, next.location, end);
      if (addMinutes(end, mins + buffer).getTime() > next.start.getTime()) return fail('travel_after');
    }
  }
  return { ok: true };
}

/** Every valid slot on [dateKey] (business-zone date). Only genuinely bookable slots are returned. */
export async function computeAvailableSlots(
  ctx: ScheduleContext,
  dateKey: string,
  opts: { stopAtFirst?: boolean } = {},
): Promise<Slot[]> {
  const { settings } = ctx;
  const wh = settings.workingHours[String(isoWeekday(dateKey, settings.timezone))];
  if (!wh) return [];
  const { open, close } = workingWindow(dateKey, settings.timezone, wh);
  const memo: ScheduleContext = { ...ctx, travel: memoTravel(ctx.travel) };
  const slots: Slot[] = [];
  for (
    let t = open;
    addMinutes(t, settings.lessonDurationMinutes).getTime() <= close.getTime();
    t = addMinutes(t, settings.slotStepMinutes)
  ) {
    const res = await checkCandidate(memo, t);
    if (res.ok) {
      slots.push({ start: t, end: addMinutes(t, settings.lessonDurationMinutes) });
      if (opts.stopAtFirst) break;
    }
  }
  return slots;
}

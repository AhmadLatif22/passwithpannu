import { DateTime } from 'luxon';
import { WorkingHours } from './types';

export const toZone = (d: Date, zone: string): DateTime => DateTime.fromJSDate(d, { zone });

/** "2026-10-12" in the business time zone. Used to group a day's bookings. */
export const dayKeyOf = (d: Date, zone: string): string => toZone(d, zone).toFormat('yyyy-MM-dd');

export const addMinutes = (d: Date, minutes: number): Date => new Date(d.getTime() + minutes * 60_000);

export function parseHm(hm: string): { h: number; m: number } {
  const [h, m] = hm.split(':').map((x) => parseInt(x, 10));
  if (Number.isNaN(h) || Number.isNaN(m)) throw new Error(`Bad time "${hm}"`);
  return { h, m };
}

export function isoWeekday(dateKey: string, zone: string): number {
  return DateTime.fromISO(dateKey, { zone }).weekday;
}

export function workingWindow(dateKey: string, zone: string, wh: WorkingHours): { open: Date; close: Date } {
  const day = DateTime.fromISO(dateKey, { zone });
  const o = parseHm(wh.start);
  const c = parseHm(wh.end);
  return {
    open: day.set({ hour: o.h, minute: o.m, second: 0, millisecond: 0 }).toJSDate(),
    close: day.set({ hour: c.h, minute: c.m, second: 0, millisecond: 0 }).toJSDate(),
  };
}

export function dayBounds(dateKey: string, zone: string): { start: Date; end: Date } {
  const d = DateTime.fromISO(dateKey, { zone });
  return { start: d.startOf('day').toJSDate(), end: d.endOf('day').toJSDate() };
}

/** "12 October at 10:00 AM" */
export function formatDayTime(d: Date, zone: string): string {
  return toZone(d, zone).setLocale('en-US').toFormat("d LLLL 'at' h:mm a");
}

/** "Tuesday, 14 October at 2:00 PM" */
export function formatLongDayTime(d: Date, zone: string): string {
  return toZone(d, zone).setLocale('en-US').toFormat("cccc, d LLLL 'at' h:mm a");
}

export function isValidDateKey(s: unknown): s is string {
  return typeof s === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(s) && DateTime.fromISO(s).isValid;
}

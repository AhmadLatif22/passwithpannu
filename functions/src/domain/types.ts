export type LessonType = 'automatic' | 'manual';
export const LESSON_TYPES: LessonType[] = ['automatic', 'manual'];

/** Single source of truth for booking states (mirrors lib/features/bookings/domain/booking_status.dart). */
export type BookingStatus =
  | 'pending'
  | 'confirmed'
  | 'changeRequested'
  | 'cancellationRequested'
  | 'cancelled'
  | 'completed'
  | 'rejected';

/** Statuses whose time slot is still occupied in the diary. */
export const OCCUPYING_STATUSES: BookingStatus[] = [
  'pending',
  'confirmed',
  'changeRequested',
  'cancellationRequested',
];

export type RequestType = 'reschedule' | 'cancel';
export type RequestStatus = 'pending' | 'approved' | 'rejected';

export interface LatLng {
  lat: number;
  lng: number;
}

export interface WorkingHours {
  start: string; // "HH:mm" in business time zone
  end: string;
}

export interface AppSettings {
  timezone: string;
  lessonDurationMinutes: number;
  slotStepMinutes: number;
  /** Students must request change/cancel at least this long before the lesson. */
  studentChangeNoticeHours: number;
  /** Students cannot book a slot starting sooner than this. */
  minBookingNoticeHours: number;
  maxAdvanceBookingDays: number;
  /** Extra padding added on top of the driving time between two lessons. */
  travelBufferMinutes: number;
  fallbackSpeedKmh: number;
  reminderOffsetsHours: number[];
  requireAdminApproval: boolean;
  /** Keys are ISO weekdays "1" (Mon) .. "7" (Sun). null = not working. */
  workingHours: Record<string, WorkingHours | null>;
  /** Used only to bias address autocomplete. */
  serviceArea: { lat: number; lng: number; radiusKm: number };
}

export const DEFAULT_SETTINGS: AppSettings = {
  timezone: 'Europe/London',
  lessonDurationMinutes: 120,
  slotStepMinutes: 30,
  studentChangeNoticeHours: 48,
  minBookingNoticeHours: 12,
  maxAdvanceBookingDays: 90,
  travelBufferMinutes: 10,
  fallbackSpeedKmh: 28,
  reminderOffsetsHours: [24, 2],
  requireAdminApproval: false,
  workingHours: {
    '1': { start: '08:00', end: '18:00' },
    '2': { start: '08:00', end: '18:00' },
    '3': { start: '08:00', end: '18:00' },
    '4': { start: '08:00', end: '18:00' },
    '5': { start: '08:00', end: '18:00' },
    '6': { start: '09:00', end: '16:00' },
    '7': null,
  },
  serviceArea: { lat: 52.9225, lng: -1.4746, radiusKm: 30 },
};

import { CallableRequest, FunctionsErrorCode, HttpsError } from 'firebase-functions/v2/https';
import { LatLng } from '../domain/types';
import { isValidDateKey } from '../domain/time';

export function requireAuth(req: CallableRequest): string {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in required.', { code: 'unauthenticated' });
  return req.auth.uid;
}

/** Admin = Firebase custom claim `admin: true`. Never read from client-supplied data. */
export function requireAdmin(req: CallableRequest): string {
  const uid = requireAuth(req);
  if (req.auth?.token.admin !== true) {
    throw new HttpsError('permission-denied', 'Admin only.', { code: 'not_admin' });
  }
  return uid;
}

/** Throws an HttpsError carrying a stable machine code in `details.code` for the Flutter client. */
export function appError(code: FunctionsErrorCode, appCode: string, message: string, extra: Record<string, unknown> = {}): HttpsError {
  return new HttpsError(code, message, { code: appCode, ...extra });
}

type Data = Record<string, unknown>;
const asData = (d: unknown): Data => (d && typeof d === 'object' ? (d as Data) : {});

export function str(data: unknown, key: string, max = 300): string {
  const v = asData(data)[key];
  if (typeof v !== 'string' || v.trim().length === 0 || v.length > max) {
    throw appError('invalid-argument', 'invalid_input', `Invalid "${key}".`);
  }
  return v.trim();
}
export function optStr(data: unknown, key: string, max = 1000): string | undefined {
  const v = asData(data)[key];
  if (v === undefined || v === null || v === '') return undefined;
  if (typeof v !== 'string' || v.length > max) throw appError('invalid-argument', 'invalid_input', `Invalid "${key}".`);
  return v.trim();
}
export function num(data: unknown, key: string): number {
  const v = asData(data)[key];
  if (typeof v !== 'number' || !Number.isFinite(v)) throw appError('invalid-argument', 'invalid_input', `Invalid "${key}".`);
  return v;
}
export function bool(data: unknown, key: string): boolean {
  return asData(data)[key] === true;
}
export function isoDate(data: unknown, key: string): Date {
  const d = new Date(str(data, key, 40));
  if (Number.isNaN(d.getTime())) throw appError('invalid-argument', 'invalid_input', `Invalid "${key}".`);
  return d;
}
export function dateKey(data: unknown, key: string): string {
  const v = asData(data)[key];
  if (!isValidDateKey(v)) throw appError('invalid-argument', 'invalid_input', `Invalid "${key}".`);
  return v;
}
export function latLng(data: unknown, latKey: string, lngKey: string): LatLng {
  const lat = num(data, latKey);
  const lng = num(data, lngKey);
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) throw appError('invalid-argument', 'invalid_input', 'Invalid coordinates.');
  return { lat, lng };
}
export function enumOf<T extends string>(data: unknown, key: string, allowed: readonly T[]): T {
  const v = asData(data)[key];
  if (typeof v !== 'string' || !allowed.includes(v as T)) throw appError('invalid-argument', 'invalid_input', `Invalid "${key}".`);
  return v as T;
}

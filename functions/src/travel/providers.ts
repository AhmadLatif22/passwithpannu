import { createHash } from 'crypto';
import { DateTime } from 'luxon';
import { Firestore, Timestamp } from 'firebase-admin/firestore';
import { AppSettings, LatLng } from '../domain/types';
import { TravelTimeService, estimateMinutes } from '../domain/travel';

/** Google Routes API (computeRoutes). Throws on any failure so callers can fall back. */
export class GoogleRoutesTravelTime implements TravelTimeService {
  constructor(private readonly apiKey: string) {}

  async getMinutes(from: LatLng, to: LatLng, departAt: Date): Promise<number> {
    const body: Record<string, unknown> = {
      origin: { location: { latLng: { latitude: from.lat, longitude: from.lng } } },
      destination: { location: { latLng: { latitude: to.lat, longitude: to.lng } } },
      travelMode: 'DRIVE',
      routingPreference: 'TRAFFIC_AWARE',
    };
    // departureTime must be in the future for traffic-aware routing.
    if (departAt.getTime() > Date.now() + 60_000) body.departureTime = departAt.toISOString();

    const res = await fetch('https://routes.googleapis.com/directions/v2:computeRoutes', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': this.apiKey,
        'X-Goog-FieldMask': 'routes.duration',
      },
      body: JSON.stringify(body),
    });
    if (!res.ok) throw new Error(`Routes API ${res.status}`);
    const json = (await res.json()) as { routes?: { duration?: string }[] };
    const secs = parseInt((json.routes?.[0]?.duration ?? '').replace('s', ''), 10);
    if (Number.isNaN(secs)) throw new Error('Routes API: no route');
    return Math.ceil(secs / 60);
  }
}

/** Firestore cache keyed by ~110 m coordinate cells and a peak/off-peak band. */
export class CachedTravelTime implements TravelTimeService {
  constructor(
    private readonly inner: TravelTimeService,
    private readonly store: Firestore,
    private readonly zone: string,
    private readonly ttlMs = 14 * 86_400_000,
  ) {}

  private key(a: LatLng, b: LatLng, at: Date): string {
    const r = (x: number) => x.toFixed(3);
    const t = DateTime.fromJSDate(at, { zone: this.zone });
    const h = t.hour + t.minute / 60;
    const weekday = t.weekday <= 5;
    const band = weekday && h >= 7 && h < 9.5 ? 'am' : weekday && h >= 16 && h < 18.5 ? 'pm' : 'off';
    return createHash('sha1').update(`${r(a.lat)},${r(a.lng)}|${r(b.lat)},${r(b.lng)}|${band}`).digest('hex');
  }

  async getMinutes(from: LatLng, to: LatLng, departAt: Date): Promise<number> {
    const ref = this.store.collection('travel_cache').doc(this.key(from, to, departAt));
    const snap = await ref.get();
    if (snap.exists) {
      const fetchedAt = (snap.get('fetchedAt') as Timestamp).toMillis();
      if (Date.now() - fetchedAt < this.ttlMs) return snap.get('minutes') as number;
    }
    const minutes = await this.inner.getMinutes(from, to, departAt);
    await ref.set({ minutes, fetchedAt: Timestamp.now() });
    return minutes;
  }
}

/** Tries the primary provider; on any failure uses a conservative estimate (fail closed). */
export class ResilientTravelTime implements TravelTimeService {
  constructor(
    private readonly primary: TravelTimeService,
    private readonly fallback: TravelTimeService,
  ) {}
  async getMinutes(from: LatLng, to: LatLng, departAt: Date): Promise<number> {
    try {
      return await this.primary.getMinutes(from, to, departAt);
    } catch (e) {
      console.warn('Travel provider failed, using estimate', e);
      return this.fallback.getMinutes(from, to, departAt);
    }
  }
}

export class EstimateTravelTime implements TravelTimeService {
  constructor(private readonly speedKmh: number) {}
  async getMinutes(from: LatLng, to: LatLng): Promise<number> {
    return estimateMinutes(from, to, this.speedKmh);
  }
}

export function createTravelService(
  settings: AppSettings,
  apiKey: string,
  store: Firestore,
): TravelTimeService {
  const estimate = new EstimateTravelTime(settings.fallbackSpeedKmh);
  if (!apiKey) return estimate;
  return new ResilientTravelTime(new CachedTravelTime(new GoogleRoutesTravelTime(apiKey), store, settings.timezone), estimate);
}

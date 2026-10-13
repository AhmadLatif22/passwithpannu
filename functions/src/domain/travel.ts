import { LatLng } from './types';

/**
 * Abstraction over whichever routing provider is used (Google Routes API today).
 * Implementations return driving minutes for a trip departing at [departAt].
 */
export interface TravelTimeService {
  getMinutes(from: LatLng, to: LatLng, departAt: Date): Promise<number>;
}

export function haversineKm(a: LatLng, b: LatLng): number {
  const R = 6371;
  const rad = (x: number) => (x * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

/** Conservative offline estimate: straight line x1.4 road factor at a pessimistic speed, plus 5 min. */
export function estimateMinutes(a: LatLng, b: LatLng, speedKmh: number): number {
  const km = haversineKm(a, b) * 1.4;
  return Math.ceil((km / speedKmh) * 60) + 5;
}

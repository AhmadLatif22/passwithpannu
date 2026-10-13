import { onCall } from 'firebase-functions/v2/https';
import { mapsKey } from '../config';
import { loadSettings } from '../services/settings';
import { appError, requireAuth, str, optStr } from './common';

function key(): string {
  const k = mapsKey.value();
  if (!k) throw appError('failed-precondition', 'maps_not_configured', 'Address search is not configured.');
  return k;
}

/** Address autocomplete proxy (Places API New). Keeps the Maps key off the device. */
export const placesAutocomplete = onCall({ secrets: [mapsKey] }, async (req) => {
  requireAuth(req);
  const input = str(req.data, 'input', 200);
  const sessionToken = optStr(req.data, 'sessionToken', 100);
  const area = (await loadSettings()).serviceArea;
  const res = await fetch('https://places.googleapis.com/v1/places:autocomplete', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Goog-Api-Key': key() },
    body: JSON.stringify({
      input,
      sessionToken,
      includedRegionCodes: ['gb'],
      locationBias: { circle: { center: { latitude: area.lat, longitude: area.lng }, radius: Math.min(area.radiusKm * 1000, 50000) } },
    }),
  });
  if (!res.ok) throw appError('unavailable', 'places_failed', 'Address search is unavailable.');
  const json = (await res.json()) as { suggestions?: { placePrediction?: { placeId: string; text?: { text: string } } }[] };
  return {
    suggestions: (json.suggestions ?? [])
      .map((s) => s.placePrediction)
      .filter((p): p is { placeId: string; text?: { text: string } } => !!p)
      .map((p) => ({ placeId: p.placeId, description: p.text?.text ?? '' })),
  };
});

export const placeDetails = onCall({ secrets: [mapsKey] }, async (req) => {
  requireAuth(req);
  const placeId = str(req.data, 'placeId', 200);
  const sessionToken = optStr(req.data, 'sessionToken', 100);
  const qs = sessionToken ? `?sessionToken=${encodeURIComponent(sessionToken)}` : '';
  const res = await fetch(`https://places.googleapis.com/v1/places/${encodeURIComponent(placeId)}${qs}`, {
    headers: { 'X-Goog-Api-Key': key(), 'X-Goog-FieldMask': 'formattedAddress,location' },
  });
  if (!res.ok) throw appError('unavailable', 'places_failed', 'Address search is unavailable.');
  const json = (await res.json()) as { formattedAddress?: string; location?: { latitude: number; longitude: number } };
  if (!json.location) throw appError('not-found', 'places_failed', 'Address not found.');
  return { address: json.formattedAddress ?? '', lat: json.location.latitude, lng: json.location.longitude };
});

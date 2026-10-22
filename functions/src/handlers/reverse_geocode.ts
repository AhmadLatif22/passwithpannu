import { onCall } from 'firebase-functions/v2/https';
import { mapsKey } from '../config';
import { appError, requireAuth } from './common';

/** Reverse-geocode an exact pickup pin without exposing the server Maps key. */
export const reverseGeocodePickup = onCall({ secrets: [mapsKey] }, async (req) => {
  requireAuth(req);
  const lat = req.data?.lat;
  const lng = req.data?.lng;
  if (typeof lat !== 'number' || typeof lng !== 'number' ||
      !Number.isFinite(lat) || !Number.isFinite(lng) ||
      lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    throw appError('invalid-argument', 'invalid_coordinates', 'Select a valid location on the map.');
  }
  const apiKey = mapsKey.value();
  if (!apiKey) {
    throw appError('failed-precondition', 'maps_not_configured', 'Address lookup is not configured.');
  }
  const query = new URLSearchParams({ latlng: `${lat},${lng}`, key: apiKey, language: 'en' });
  const response = await fetch(`https://maps.googleapis.com/maps/api/geocode/json?${query.toString()}`);
  if (!response.ok) {
    throw appError('unavailable', 'geocoding_unavailable', 'Address lookup is temporarily unavailable.');
  }
  const json = (await response.json()) as {
    status: string;
    results?: { formatted_address?: string; types?: string[]; address_components?: { short_name: string; types: string[] }[] }[];
  };
  if (json.status !== 'OK' || !json.results?.length) {
    throw appError('not-found', 'address_not_found', 'No address was found here. Try a nearby point.');
  }
  const result = json.results.find((item) => item.types?.includes('street_address')) ?? json.results[0];
  const country = result.address_components?.find((c) => c.types.includes('country'))?.short_name;
  if (country !== 'GB') {
    throw appError('out-of-range', 'outside_uk', 'Please select a location in the United Kingdom.');
  }
  if (!result.formatted_address) {
    throw appError('not-found', 'address_not_found', 'No readable address found for this point.');
  }
  // Keep the student's exact pin, not the geocoder's approximate road centroid.
  return { address: result.formatted_address, lat, lng };
});

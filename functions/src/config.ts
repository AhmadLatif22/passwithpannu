import { defineSecret } from 'firebase-functions/params';

/**
 * Server-side Google Maps Platform key (Routes API + Places API (New)).
 * Set with:  firebase functions:secrets:set GOOGLE_MAPS_SERVER_KEY
 * It is never shipped inside the Flutter app.
 */
export const mapsKey = defineSecret('GOOGLE_MAPS_SERVER_KEY');
export const REGION = 'europe-west2'; // London. Keep Firestore in a matching EU location.

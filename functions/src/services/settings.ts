import { db } from '../firebase';
import { AppSettings, DEFAULT_SETTINGS } from '../domain/types';

/** Loads app_settings/main merged over safe defaults. */
export async function loadSettings(): Promise<AppSettings> {
  const snap = await db.collection('app_settings').doc('main').get();
  const data = (snap.data() ?? {}) as Partial<AppSettings>;
  return {
    ...DEFAULT_SETTINGS,
    ...data,
    workingHours: { ...DEFAULT_SETTINGS.workingHours, ...(data.workingHours ?? {}) },
    serviceArea: { ...DEFAULT_SETTINGS.serviceArea, ...(data.serviceArea ?? {}) },
  };
}

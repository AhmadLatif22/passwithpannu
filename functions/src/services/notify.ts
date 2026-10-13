import { FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { db } from '../firebase';

export type NotificationType =
  | 'booking_created'
  | 'booking_confirmed'
  | 'booking_rescheduled'
  | 'booking_cancelled'
  | 'request_created'
  | 'request_approved'
  | 'request_rejected'
  | 'reminder';

export interface Notice {
  title: string;
  body: string;
  type: NotificationType;
  bookingId?: string;
}

/** Stores an in-app notification and pushes it to every registered device. Never throws. */
export async function notifyUser(uid: string, n: Notice): Promise<void> {
  try {
    await db.collection('notifications').add({
      userId: uid,
      title: n.title,
      body: n.body,
      type: n.type,
      bookingId: n.bookingId ?? null,
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });
    const devices = await db.collection('users').doc(uid).collection('devices').get();
    const tokens = devices.docs.map((d) => d.get('token') as string).filter(Boolean);
    if (tokens.length === 0) return;
    const res = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title: n.title, body: n.body },
      data: { type: n.type, bookingId: n.bookingId ?? '' },
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    // Prune tokens FCM says are dead.
    await Promise.all(
      res.responses.map(async (r, i) => {
        const code = r.error?.code;
        if (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token') {
          await devices.docs[i].ref.delete();
        }
      }),
    );
  } catch (e) {
    console.error('notifyUser failed', uid, e);
  }
}

export async function notifyAdmins(n: Notice): Promise<void> {
  const admins = await db.collection('users').where('role', '==', 'admin').get();
  await Promise.all(admins.docs.map((d) => notifyUser(d.id, n)));
}

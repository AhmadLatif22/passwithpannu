// Needs the Firestore emulator:  cd functions && npm run test:rules
import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { readFileSync } from 'fs';
import { doc, getDoc, setDoc, updateDoc, serverTimestamp } from 'firebase/firestore';

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'pwp-rules-test',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/alice'), { uid: 'alice', fullName: 'Alice A', email: 'a@x.com', role: 'student', isActive: true });
    await setDoc(doc(db, 'users/bob'), { uid: 'bob', fullName: 'Bob B', email: 'b@x.com', role: 'student', isActive: true });
    await setDoc(doc(db, 'bookings/b1'), { studentId: 'alice', status: 'confirmed' });
    await setDoc(doc(db, 'bookings/b2'), { studentId: 'bob', status: 'confirmed' });
  });
});
afterAll(() => env.cleanup());

const alice = () => env.authenticatedContext('alice', { email: 'a@x.com' }).firestore();
const admin = () => env.authenticatedContext('boss', { admin: true, email: 'boss@x.com' }).firestore();

describe('student permissions', () => {
  it('reads own booking but not another student\'s', async () => {
    await assertSucceeds(getDoc(doc(alice(), 'bookings/b1')));
    await assertFails(getDoc(doc(alice(), 'bookings/b2')));
  });
  it('cannot write bookings (no direct time edits)', async () => {
    await assertFails(updateDoc(doc(alice(), 'bookings/b1'), { startDateTime: new Date() }));
    await assertFails(updateDoc(doc(alice(), 'bookings/b1'), { status: 'cancelled' }));
  });
  it('cannot create booking_requests directly (callable only)', async () => {
    await assertFails(setDoc(doc(alice(), 'booking_requests/r1'), { studentId: 'alice' }));
  });
  it('can edit name/phone but not role', async () => {
    await assertSucceeds(updateDoc(doc(alice(), 'users/alice'), { fullName: 'Alice Z', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(alice(), 'users/alice'), { role: 'admin' }));
  });
  it('cannot read another user or availability blocks', async () => {
    await assertFails(getDoc(doc(alice(), 'users/bob')));
    await assertFails(getDoc(doc(alice(), 'availability_blocks/x')));
  });
  it('cannot self-register as admin', async () => {
    const db = env.authenticatedContext('eve', { email: 'e@x.com' }).firestore();
    await assertFails(setDoc(doc(db, 'users/eve'), {
      uid: 'eve', fullName: 'Eve E', email: 'e@x.com', role: 'admin', isActive: true, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(setDoc(doc(db, 'users/eve'), {
      uid: 'eve', fullName: 'Eve E', email: 'e@x.com', role: 'student', isActive: true, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));
  });
});

describe('admin permissions', () => {
  it('reads all bookings and users but still cannot write bookings directly', async () => {
    await assertSucceeds(getDoc(doc(admin(), 'bookings/b2')));
    await assertSucceeds(getDoc(doc(admin(), 'users/alice')));
    await assertFails(updateDoc(doc(admin(), 'bookings/b2'), { status: 'cancelled' }));
  });
  it('can manage availability blocks', async () => {
    await assertSucceeds(setDoc(doc(admin(), 'availability_blocks/blk'), {
      id: 'blk', startDateTime: new Date('2026-12-25T00:00:00Z'), endDateTime: new Date('2026-12-26T00:00:00Z'),
      reason: 'Holiday', createdBy: 'boss', createdAt: serverTimestamp(),
    }));
  });
});

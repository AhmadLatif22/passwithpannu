
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import { db } from '../firebase';
import {
  TERMS_VERSION,
  TERMS_TEXT,
  TERMS_SHA256,
} from '../policies/terms_v1_1';

export const acceptStudentTerms = onCall(async (req) => {
  const uid = req.auth?.uid;

  if (!uid) {
    throw new HttpsError(
      'unauthenticated',
      'Sign in to accept the terms.',
    );
  }

  if (req.auth?.token.admin === true) {
    throw new HttpsError(
      'permission-denied',
      'This flow is for students only.',
    );
  }

  if (req.data?.version !== TERMS_VERSION) {
    throw new HttpsError(
      'failed-precondition',
      'Please update the app to review the current terms.',
    );
  }

  const userRef = db.collection('users').doc(uid);

  const acceptanceRef = userRef
    .collection('termsAcceptances')
    .doc(TERMS_VERSION);

  await db.runTransaction(async (tx) => {
    const [userSnap, acceptanceSnap] = await Promise.all([
      tx.get(userRef),
      tx.get(acceptanceRef),
    ]);

    if (!userSnap.exists || userSnap.get('role') !== 'student') {
      throw new HttpsError(
        'permission-denied',
        'An instructor invitation is required.',
      );
    }

    const profileEmail = userSnap.get('email') as string | undefined;
    const authEmail = req.auth?.token.email;

    if (
      !profileEmail ||
      !authEmail ||
      profileEmail.toLowerCase() !== authEmail.toLowerCase()
    ) {
      throw new HttpsError(
        'permission-denied',
        'Account email does not match the invitation.',
      );
    }

    // Prevent activation of previously suspended accounts.
    if (acceptanceSnap.exists && userSnap.get('isActive') !== true) {
      throw new HttpsError(
        'permission-denied',
        'This account is currently inactive.',
      );
    }

    if (!acceptanceSnap.exists) {
      const invitationStatus = userSnap.get('invitationStatus');
      const invitedBy = userSnap.get('invitedBy');

      if (
        userSnap.get('isActive') !== false ||
        !['invited', 'sent'].includes(invitationStatus) ||
        typeof invitedBy !== 'string' ||
        invitedBy.trim().length === 0
      ) {
        throw new HttpsError(
          'permission-denied',
          'A valid instructor invitation is required.',
        );
      }

      // Preserve the exact version of the accepted agreement.
      tx.create(acceptanceRef, {
        uid,
        version: TERMS_VERSION,
        documentTitle:
          'Pass With Pannu Driving Lesson Terms & Conditions',
        effectiveDate: '2026-10-18',
        policyText: TERMS_TEXT,
        sha256: TERMS_SHA256,
        acceptedAt: FieldValue.serverTimestamp(),
        confirmation:
          'I have read and agree to the Terms & Conditions',
      });
    }

    // Activate the student after the agreement is recorded.
    tx.update(userRef, {
      isActive: true,
      termsAccepted: true,
      termsVersion: TERMS_VERSION,
      termsAcceptedAt: acceptanceSnap.exists
        ? acceptanceSnap.get('acceptedAt')
        : FieldValue.serverTimestamp(),
      invitationStatus: 'active',
      activatedAt:
        userSnap.get('activatedAt') ??
        FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  return {
    success: true,
    version: TERMS_VERSION,
  };
});


import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue } from 'firebase-admin/firestore';

import { db } from '../firebase';
import { REGION } from '../config';
import { requireAdmin, str, optStr } from './common';

const resendApiKey = defineSecret('RESEND_API_KEY');

// CHANGE THIS to an address on your verified Resend domain.
const SENDER_EMAIL = 'Pass With Pannu <bookings@updates.passwithpannu.com>';

const REPLY_TO_EMAIL = 'passwithpannu@passwithpannu.com';
const escapeHtml = (value: string): string =>
  value.replace(/[&<>"']/g, (char) => {
    const map: Record<string, string> = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#39;',
    };
    return map[char];
  });

export const inviteStudent = onCall(
  {
    region: REGION,
    secrets: [resendApiKey],
    maxInstances: 10,
  },
  async (request) => {
    // 1. Only authorized instructors can send invitations.
    const adminUid = requireAdmin(request);

    // 2. Validate student information.
    const fullName = str(request.data, 'fullName', 100);
    const email = str(request.data, 'email', 254)
      .toLowerCase();

    const phone = optStr(request.data, 'phone', 30) ?? '';

    const lessonType = str(request.data, 'lessonType', 20);

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      throw new HttpsError(
        'invalid-argument',
        'Invalid email address.',
      );
    }

    if (!['manual', 'automatic'].includes(lessonType)) {
      throw new HttpsError(
        'invalid-argument',
        'Invalid lesson type.',
      );
    }

    if (SENDER_EMAIL.includes('YOURDOMAIN')) {
      throw new HttpsError(
        'failed-precondition',
        'Configure the verified Resend sender domain.',
      );
    }

    const auth = getAuth();

    // 3. Reject existing accounts to avoid duplicates
    // or accidentally taking control of another user.
    try {
      await auth.getUserByEmail(email);

      throw new HttpsError(
        'already-exists',
        'A user with this email already exists. Check Firebase Authentication before retrying.',
      );
    } catch (error: unknown) {
      if (error instanceof HttpsError) {
        throw error;
      }

      const code = (error as { code?: string })?.code;

      if (code !== 'auth/user-not-found') {
        throw new HttpsError(
          'internal',
          'Unable to check existing student accounts.',
        );
      }
    }

    // 4. Create Firebase Authentication account.
    const student = await auth.createUser({
      email,
      displayName: fullName,
      emailVerified: false,
    });

    // 5. Store invited student profile.
    // isActive remains false until Terms acceptance.
    try {
      await db.collection('users').doc(student.uid).set({
        uid: student.uid,
        fullName,
        email,
        phone,
        lessonType,
        role: 'student',
        isActive: false,
        invitationStatus: 'invited',
        invitedBy: adminUid,
        invitedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        termsAccepted: false,
        termsVersion: null,
        termsAcceptedAt: null,
      });
    } catch (error) {
      console.error('Could not create student profile', error);

      // Profile was not created: remove orphaned Auth user.
      try {
        await auth.deleteUser(student.uid);
      } catch (cleanupError) {
        console.error('Could not clean up Auth user', cleanupError);
      }

      throw new HttpsError(
        'internal',
        'Could not create student profile.',
      );
    }

    // 6. Generate Firebase password-setup link.
    let setupLink: string;

    try {
      setupLink = await auth.generatePasswordResetLink(email);
    } catch (error) {
      console.error('Failed to generate password setup link', error);

      throw new HttpsError(
        'internal',
        'Account created, but the activation link could not be generated.',
      );
    }

    // 7. Send branded invitation through Resend.
    const safeName = escapeHtml(fullName);
    const safeLink = escapeHtml(setupLink);

    let response: Response;

    try {
      response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${resendApiKey.value()}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: SENDER_EMAIL,
          to: [email],
          reply_to: REPLY_TO_EMAIL,
          subject: 'Welcome to Pass With Pannu – Activate Your Account',
          html: `
            <div style="
              max-width:600px;
              margin:0 auto;
              font-family:Arial,sans-serif;
              background:#0B0D14;
              color:#F8FAFC;
              padding:32px;
              border-radius:14px;
            ">
              <h1 style="color:#3E77FF;">
                Pass With Pannu
              </h1>

              <h2>Welcome, ${safeName}!</h2>

              <p>
                You've been invited to join Pass With Pannu.
              </p>

              <p>
                Activate your student account to manage
                driving lessons, track your progress and
                receive lesson reminders.
              </p>

              <p>
                Click below to set your password.
              </p>

              <a href="${safeLink}" style="
                display:inline-block;
                background:#3E77FF;
                color:white;
                padding:15px 26px;
                border-radius:8px;
                text-decoration:none;
                font-weight:bold;
              ">
                Set My Password
              </a>

              <p style="margin-top:25px;">
                After setting your password, sign in to
                the app and accept the Terms & Conditions
                to activate your student account.
              </p>

              <p style="color:#18D67B;">
                Master the Road to Success
              </p>

              <p>
                Pass With Pannu<br>
                Derby, United Kingdom
              </p>

              <p style="font-size:12px;color:#AAB3C5;">
                If you were not expecting this invitation,
                please contact Pass With Pannu.
              </p>
            </div>
          `,
        }),
      });
    } catch (error) {
      console.error('Resend network failure', error);

      throw new HttpsError(
        'unavailable',
        'Account created, but email delivery could not be requested.',
      );
    }

    if (!response.ok) {
      console.error(
        'Resend error',
        response.status,
        await response.text(),
      );

      throw new HttpsError(
        'internal',
        'Account created, but the invitation email was not accepted by Resend.',
      );
    }

    // 8. Mark invitation request as sent.
    try {
      await db.collection('users').doc(student.uid).update({
        invitationStatus: 'sent',
        invitationEmailSentAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      // Email may already have been accepted by Resend.
      // Never pretend it was not sent.
      console.error('Invitation sent; status update failed', error);
    }

    return {
      success: true,
      studentId: student.uid,
      email,
      message: 'Student invitation sent successfully.',
    };
  },
);

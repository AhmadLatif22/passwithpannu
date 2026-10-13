# Pass With Pannu: driving lesson booking platform

Student mobile app (Android + iOS) and instructor admin dashboard (Flutter Web) for a single instructor,
built on Flutter, Riverpod, Firebase Auth, Cloud Firestore, Cloud Functions and FCM.

> **Status.** The Cloud Functions domain logic is unit-tested (16 passing tests, `npm test`) and type-checks.
> The Flutter code and the Firestore rules tests were written without a Flutter SDK / emulator available, so
> run `flutter analyze` and `flutter test` first and treat the first run as a shake-down.

## 1. What is built

| Spec area | Where |
|---|---|
| Brand theme (purple/black, Playfair Display + Outfit) | `lib/core/theme/*`, `lib/core/constants/app_constants.dart` |
| Splash (native + in-app), auth state check | `flutter_native_splash` config in `pubspec.yaml`, `features/auth/presentation/splash_page.dart` |
| Register / login / logout / reset password | `features/auth/*` |
| Student home, lessons (upcoming/previous), booking detail, profile, notifications | `features/home`, `features/bookings`, `features/profile`, `features/notifications` |
| 5-step booking flow + confirmation | `features/bookings/presentation/flow/*` |
| Availability engine (hours, blocks, bookings, travel time, notice) | `functions/src/domain/availability.ts` (+ tests) |
| Travel time abstraction (Google Routes, cache, fallback) | `functions/src/domain/travel.ts`, `functions/src/travel/providers.ts` |
| Atomic booking + no double booking | `functions/src/handlers/bookings.ts` (per-day lock + transaction) |
| Change/cancel REQUESTS + 48h rule + admin approve/reject | `functions/src/handlers/requests.ts`, `features/lesson_requests/*`, `features/admin/requests/*` |
| Admin: dashboard, diary (day/week/month), bookings, students, requests, availability blocks, settings | `features/admin/*` |
| Push notifications + in-app history | `functions/src/services/notify.ts`, `lib/core/services/fcm_service.dart` |
| Reminders (24 h / 2 h, configurable) | `functions/src/handlers/reminders.ts` (scheduled every 15 min) |
| Security rules | `firestore.rules`, `functions/rules-test/rules.test.ts` |

## 2. Architecture

```
Flutter (student app / admin web)           Firebase
  presentation (Riverpod, widgets)   reads   Firestore  <-- security rules: clients READ only
  domain (pure rules, models)       ------>  (own bookings, own requests, own notifications)
  data (repositories)
        |  callable functions (all scheduling WRITES + availability)
        v
  Cloud Functions (europe-west2, Admin SDK) --> Firestore transactions, FCM, Google Routes/Places
```

Decisions worth knowing:

* **Clients never write bookings.** `createBooking`, `createBookingRequest`, `resolveBookingRequest`,
  `adminRescheduleBooking`, `adminCancelBooking`, `adminCompleteBooking`, `adminCreateBooking`,
  `adminUpdateBooking` are callable functions. Rules deny every client write to `bookings` / `booking_requests`,
  so students cannot edit a confirmed time even with a modified app. Admin is the custom claim `admin: true`.
* **Availability is computed on the server.** Travel checks need other students' pickup points, which students
  must never be able to read. `getAvailableSlots` / `getAvailableDates` return only valid slots, and
  `createBooking` re-runs the same check inside a transaction.
* **Concurrency.** Every scheduling transaction reads and writes `schedule_days/{yyyy-MM-dd}`, so two bookings for
  the same day always serialise; the loser fails with `slot_unavailable` and the app sends the student back to
  pick another time.
* **Pending requests hold the slot.** `changeRequested` / `cancellationRequested` bookings keep occupying the diary
  until the admin decides. The lesson time is never touched by a request.
* **Admin overrides.** Travel, blocked periods, hours and notice can be overridden by the instructor after an explicit
  warning dialog. Overlapping another lesson can never be overridden.
* **Maps key stays off the device.** Places autocomplete and the Routes API are called from Cloud Functions.
  The app has no Maps SDK and no API key.
* **Fail closed.** If the Routes API is down, a conservative distance-based estimate is used rather than offering a
  slot that might be impossible.

### Deliberate deviations from the brief

1. **Pickup comes before date/time in the booking flow** (Type, Pickup, Date, Time, Review). Travel feasibility
   depends on the pickup point, so slots cannot be correct until it is known.
2. **`AvailabilityService` lives on the server** (see above), with a thin `AvailabilityRepository` in Flutter.
3. **No `flutter_dotenv` / client `.env`.** Nothing secret is in the app. Build flags use `--dart-define`.
4. **Admin web push is not enabled** (needs a VAPID key and service worker). The admin web shows live badges for
   pending requests and notifications; admin on a phone gets push. Easy to add later.
5. New bookings are `confirmed` immediately. Turn on "Approve new bookings manually" in Settings to use `pending`.
6. Admin screens stream bookings from the last 180 days onward (keeps reads small).

## 3. Prerequisites

Flutter 3.35+ (Dart 3.8+), Node 20, Firebase CLI (`npm i -g firebase-tools`), FlutterFire CLI,
Xcode + CocoaPods (iOS), a Firebase project on the **Blaze** plan (Functions, secrets and scheduler need it).

## 4. Setup

```bash
./tool/setup.sh                     # creates android/ ios/ web/ around lib/, runs pub get
cd functions && npm install && cd ..
```

### Firebase project
1. Create a project in the Firebase console. Set the default Firestore location to **eur3 (Europe)** or
   `europe-west2` (London).
2. **Authentication** > Sign-in method > enable **Email/Password**. Add your admin web domain under Authorized domains.
3. **Firestore** > Create database (production mode).
4. `firebase login && firebase use --add` (or edit `.firebaserc`).
5. `dart pub global activate flutterfire_cli && flutterfire configure` registers the Android, iOS and Web apps and
   **overwrites `lib/firebase_options.dart`**. It also downloads `google-services.json` and `GoogleService-Info.plist`.
   Do not commit those files or `firebase_options.dart` if the repo is public.

### Android
* Application ID: `com.passwithpannu.app` in `android/app/build.gradle.kts` (`applicationId`), `minSdk = 23`.
* Firebase Gradle plugin: in `android/settings.gradle.kts` add
  `id("com.google.gms.google-services") version "4.4.2" apply false`, and in `android/app/build.gradle.kts` add
  `id("com.google.gms.google-services")` to `plugins {}`. `google-services.json` goes in `android/app/`.
* `android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:
  ```xml
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
  ```
  The default Kotlin `MainActivity : FlutterActivity()` needs no changes. No location permission is required
  (addresses are typed/searched, not read from GPS).
* Release signing: create `android/key.properties` (git-ignored) and a `signingConfigs.release` block, then
  `flutter build appbundle -t lib/main_student.dart --release`.

### iOS
* Open `ios/Runner.xcworkspace`. Set the bundle identifier (`com.passwithpannu.app`) and your team.
* Add `GoogleService-Info.plist` to the Runner target (drag into Xcode).
* Signing & Capabilities: add **Push Notifications** and **Background Modes > Remote notifications**.
* Create an **APNs Auth Key (.p8)** in your Apple developer account and upload it in Firebase console >
  Project settings > Cloud Messaging.
* Deployment target 13.0+ (`platform :ios, '13.0'` in `ios/Podfile`), then `cd ios && pod install`.
* `flutter build ipa -t lib/main_student.dart --release`.

### Branding assets
Put your logo at `assets/images/logo.png` (transparent PNG, about 1024 px). Then
`dart run flutter_native_splash:create && dart run flutter_launcher_icons`.
Until then the app falls back to a text wordmark. Colours in `app_colors.dart` were estimated from a screenshot;
replace them with the exact hex values from the website CSS.

### Maps / travel API
1. In Google Cloud (same project) enable **Routes API** and **Places API (New)**, and billing.
2. Create an API key restricted to those two APIs.
3. `firebase functions:secrets:set GOOGLE_MAPS_SERVER_KEY`
Without the key the app still works for scheduling (estimates only) but address search is disabled, and the
student booking flow needs address search to get coordinates.

### First run: admin account and settings
1. Register the instructor account (student app, or Firebase console > Authentication).
2. Credentials for scripts: `export GOOGLE_APPLICATION_CREDENTIALS=/path/serviceAccount.json` (never commit it).
3. `cd functions && node scripts/set-admin.js instructor@example.com` sets the `admin` claim.
   Sign out and back in to refresh the token.
4. `node scripts/seed-settings.js` writes default working hours (Mon-Fri 08-18, Sat 09-16), 10 min buffer,
   48 h notice, reminders at 24 h and 2 h. Edit them any time in Admin > Settings.

## 5. Running

```bash
flutter run -t lib/main_student.dart                  # student app on a device/emulator
flutter run -d chrome -t lib/main_admin.dart          # admin dashboard (web)
```

Local emulators (no cloud writes):
```bash
cd functions && npm run build && cd ..
firebase emulators:start --only auth,firestore,functions
flutter run -t lib/main_student.dart --dart-define=USE_EMULATOR=true
# physical phone: add --dart-define=EMULATOR_HOST=<your computer's LAN IP>
```

## 6. Deploying

```bash
firebase deploy --only firestore:rules,firestore:indexes   # security rules (no composite indexes needed)
firebase functions:secrets:set GOOGLE_MAPS_SERVER_KEY
firebase deploy --only functions                            # callables + reminder scheduler (europe-west2)
flutter build web -t lib/main_admin.dart --release
firebase deploy --only hosting                              # serves build/web
```

## 7. Testing

```bash
flutter analyze && flutter test            # Dart: duration, 48h rule, permissions, status transitions, dates, validators, widgets
cd functions && npm test                   # availability conflicts, travel buffers, 48h, transitions, request workflow
cd functions && npm run test:rules         # Firestore rules (needs Java + firebase-tools emulator)
```

Critical flows A to F: the rules behind each (slot validation, request-only changes, admin approval, cancellation
notifications, serialised same-slot bookings, travel rejection) are implemented in the functions and the domain
logic is unit-tested. An end-to-end run against the emulators (two simultaneous bookings for one slot, etc.)
is the next thing to automate and has not been run yet.

## 8. Firestore data model (summary)

`users/{uid}` (+ `devices/{token}`), `bookings/{id}`, `booking_requests/{id}`, `availability_blocks/{id}`,
`app_settings/main`, `notifications/{id}`; server-only: `travel_cache`, `schedule_days`.
Booking fields: `bookingId, reference, studentId, studentName, studentEmail, studentPhone, lessonType, startDateTime,
endDateTime, durationMinutes, dayKey, pickupAddress, pickupLatitude, pickupLongitude, status, createdAt, updatedAt,
createdBy, updatedBy, cancelledBy, cancellationReason, cancelledAt, previousStartTime, newStartTime, adminNotes,
remindersSent`. All timestamps are UTC; display uses Europe/London.

## 9. Known limitations / next steps

* Admin web push, offline-first caching and an iOS/Android widget test of the full booking flow are not included.
* Deactivating a student currently only flags the profile; enforcing it in `createBooking` is already done
  (`profile_missing`), but their existing session is not revoked.
* Run the emulator end-to-end tests for flows A to F before launch.
# passwithpannu

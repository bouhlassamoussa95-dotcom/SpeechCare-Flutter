# SpeechCare (Flutter)

Native Flutter port of the SpeechCare Capacitor/HTML app: same features, same section colours, same
Firebase project and same cloud-data format (your existing patients, sessions, reports, toys and
photos load unchanged after you sign in).

> **Important:** this project was converted and statically checked, but it has **not been compiled or run**
> yet (no Flutter SDK was available where it was written). Expect to fix a few small compile errors on the first
> build. The GitHub workflow and `flutter analyze` will list them; paste them back and they are quick to fix.

## 1. Build and install (pick one)

### A. GitHub Actions (no local setup; same idea as your old workflow)
1. Push this folder to a GitHub repo (branch `main`).
2. Optional: repo → Settings → Secrets → `OPENROUTER_API_KEY` (bakes the AI key into the APK).
3. Actions → *Build SpeechCare (Flutter) APK* → Run. Download the `SpeechCare-flutter-apk` artifact and install `app-release.apk`.

### B. Windows (PowerShell)
Needs Flutter SDK (`flutter doctor` green), Android SDK, Node.js.
```powershell
.\Build-SpeechCare-Flutter.ps1 -OpenRouterKey sk-or-v1-xxxx -Install   # key and -Install are optional
```
### C. Manual
```bash
flutter create --platforms=android --org com.chourouk --project-name speechcare_flutter .
node tool/patch_android.js          # manifest, icons, minSdk 23, desugaring
flutter pub get
flutter build apk --release --dart-define=OPENROUTER_API_KEY=sk-or-v1-xxxx
```
The app id is `com.chourouk.speechcare_flutter`, so it installs **next to** the old Capacitor app (no clash).

## 2. Firebase: one thing to check
`lib/firebase_options.dart` reuses the web config of your existing project. If sign-in shows
*"API key not valid / blocked"*, the key is restricted to web origins. Fix: Firebase Console → add an **Android app**
(package `com.chourouk.speechcare_flutter`) and run `flutterfire configure` (or temporarily remove the key's application restriction).
Firestore/Storage rules are unchanged (`firestore.rules`, `storage.rules` are included for reference).

## 3. AI assistant
Uses OpenRouter free models directly, exactly like the web app. The key comes from `--dart-define=OPENROUTER_API_KEY=...`.
If the build has no key, **Settings → AI (OpenRouter)** appears so you can paste one for testing (stored on the device only).

## 4. What was ported
Everything in the original: sign-in / sign-up / reset / email verification / offline preview; Home (period tiles, strip calendar,
donut), Today (countdown room), Sessions (appointments + patients modes, filters, workplace filter), Calendar (week/month),
Patients, Patient profile (next appointment, treatment program with pause/extend/shorten, completed-session reports, AI progress
review with de-identification, suggested activities per condition), appointment form (individual/group, repeat), patient form
(conditions, typical-frequency hint, extra workplaces), structured "Complete session" report + next-appointment preparation,
reschedule, consultations, finance (frozen per-session terms, per-place percentages/fixed amounts), workplaces, toys with photos
and AI activity ideas, Arabic/Darija activity library with text-to-speech, five report models in EN/FR/AR with AI per-section
help and "polish" (numbers/dates protected, with undo), editable **Word (.docx)** export with banner + signature, client message,
AI panel with context chips, notifications (15 min before + 07:30 daily summary), EN/FR/AR UI (RTL), light/dark/system,
cloud sync (3-way record merge, pending flags, live listeners, Storage photos, backups) – ported function by function.

Section colours, card accent bars, tiles, pills, segmented controls, header/nav styling are copied from the CSS variables.

## 5. Small differences from the web app
* Photos use Firebase Storage SDK directly (the web app's REST fallback for WebView problems is not needed).
* Reminders use inexact alarms (Android may shift them by a few minutes; avoids the exact-alarm permission).
* "Download Word" and "Edit / Email report" both open the Android share sheet (Word, WPS, Drive, email…).
* Offline start now always starts the sync engine (the web app skipped it if the token refresh failed).
* New appointments store their workplace id immediately, so the workplace filter works without a restart.
* Fonts: Cairo via `google_fonts` (downloaded the first time you are online, then cached).
* Everything not listed above behaves like the original; the cloud JSON shape is identical.

## 6. Test checklist
1. Sign in with your existing account; data appears; header colour changes per section.
2. Add patient → add sessions (repeat 4) → mark one done (structured report) → check Finance.
3. Switch EN/FR/AR (layout flips for Arabic) and dark mode.
4. Add a toy with a photo → turn off Wi-Fi → edit something → turn Wi-Fi on: status pill goes *pending → saved*.
5. Edit on the old web app / second phone: changes arrive here without losing either side's edits.
6. Reports → Download Word → open in Word/WPS (check Arabic RTL).
7. AI chip on a patient; "Insert into…" a report section.
8. Plan a session 20 min ahead → reminder notification.

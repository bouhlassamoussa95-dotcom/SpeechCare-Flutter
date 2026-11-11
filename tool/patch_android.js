#!/usr/bin/env node
/* Run AFTER `flutter create --platforms=android ...` : applies the SpeechCare Android settings.
   - AndroidManifest.xml (permissions, notification receivers, tel:/https queries, app label + icon)
   - launcher icons (same artwork as the Capacitor build)
   - Gradle: minSdk 23 (Firebase) + core library desugaring (flutter_local_notifications)            */
const fs = require('fs'), path = require('path');
const root = path.resolve(__dirname, '..');
const app = path.join(root, 'android', 'app');
if (!fs.existsSync(app)) { console.error('android/app not found. Run: flutter create --platforms=android --org com.chourouk --project-name speechcare_flutter .'); process.exit(1); }

/* ---------- manifest ---------- */
const manifest = `<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <application
        android:label="SpeechCare"
        android:name="\${applicationName}"
        android:icon="@mipmap/speechcare_icon"
        android:roundIcon="@mipmap/speechcare_icon_round"
        android:usesCleartextTraffic="false">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data android:name="io.flutter.embedding.android.NormalTheme" android:resource="@style/NormalTheme"/>
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data android:name="flutterEmbedding" android:value="2"/>
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
    </application>
    <queries>
        <intent><action android:name="android.intent.action.PROCESS_TEXT"/><data android:mimeType="text/plain"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="tel"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
        <intent><action android:name="android.intent.action.TTS_SERVICE"/></intent>
    </queries>
</manifest>
`;
fs.writeFileSync(path.join(app, 'src', 'main', 'AndroidManifest.xml'), manifest);
console.log('manifest written');

/* ---------- icons ---------- */
const src = path.join(__dirname, 'android-res'), dst = path.join(app, 'src', 'main', 'res');
function copyDir(a, b) {
  fs.mkdirSync(b, { recursive: true });
  for (const f of fs.readdirSync(a)) {
    const s = path.join(a, f), d = path.join(b, f);
    fs.statSync(s).isDirectory() ? copyDir(s, d) : fs.copyFileSync(s, d);
  }
}
copyDir(src, dst);
console.log('icons copied');

/* ---------- gradle ---------- */
const kts = path.join(app, 'build.gradle.kts'), groovy = path.join(app, 'build.gradle');
const file = fs.existsSync(kts) ? kts : (fs.existsSync(groovy) ? groovy : null);
if (!file) { console.error('No app/build.gradle(.kts) found'); process.exit(1); }
let g = fs.readFileSync(file, 'utf8');
const isKts = file === kts;
if (isKts) {
  g = g.replace(/minSdk\s*=\s*[^\n]+/, 'minSdk = 23');
  if (!/isCoreLibraryDesugaringEnabled/.test(g)) g = g.replace(/compileOptions\s*\{/, 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true');
  if (!/coreLibraryDesugaring\(/.test(g)) g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")\n}\n';
} else {
  g = g.replace(/minSdkVersion\s+[^\n]+/, 'minSdkVersion 23');
  if (!/coreLibraryDesugaringEnabled/.test(g)) g = g.replace(/compileOptions\s*\{/, 'compileOptions {\n        coreLibraryDesugaringEnabled true');
  if (!/coreLibraryDesugaring\s/.test(g)) g += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'\n}\n";
}
fs.writeFileSync(file, g);
console.log('gradle patched:', path.basename(file));
console.log('DONE. Next: flutter pub get && flutter build apk --release');

<#
 Builds the SpeechCare Flutter APK on Windows.
 Requirements: Flutter SDK on PATH (flutter doctor OK), Android SDK, Node.js.
 Usage:   .\Build-SpeechCare-Flutter.ps1                    (APK without a built-in AI key)
          .\Build-SpeechCare-Flutter.ps1 -OpenRouterKey sk-or-v1-...
          .\Build-SpeechCare-Flutter.ps1 -Install            (also installs on the connected phone via adb)
#>
param([string]$OpenRouterKey = '', [switch]$Install)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
function Need($c) { if (-not (Get-Command $c -ErrorAction SilentlyContinue)) { throw "$c was not found on PATH." } }
Need flutter; Need node
if (-not (Test-Path 'android\app')) {
  flutter create --platforms=android --org com.chourouk --project-name speechcare_flutter .
}
node tool\patch_android.js
flutter pub get
$defs = @()
if ($OpenRouterKey) { $defs += "--dart-define=OPENROUTER_API_KEY=$OpenRouterKey" }
flutter build apk --release @defs
$apk = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-release.apk'
Write-Host "APK: $apk" -ForegroundColor Green
if ($Install) { Need adb; adb install -r $apk }

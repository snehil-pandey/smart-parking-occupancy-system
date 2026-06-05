# Security Recheck

Date: 2026-06-02

## Scope

This recheck covered the main project branch only. The standalone `addon` branch was not checked out, merged, or modified.

## Files Cleaned

Generated and local-only artifacts removed from the working tree:

- Flutter/Dart caches: `.dart_tool/`
- Flutter/Android build outputs: `build/`, app-level `build/`
- Gradle/Kotlin caches: `.gradle/`, `.kotlin/`
- Coverage folders
- Temporary logs and temp files
- Local APK/AAB outputs, including root `apk/*.apk`
- Python `__pycache__/`

Local Firebase config/key files were found on disk but were intentionally not deleted because they may be needed for local development. They are ignored by `.gitignore` and are not tracked.

## Ignore Rules Checked

`.gitignore` now covers:

- `*.apk`
- `*.aab`
- `apk/`
- `apk/*.apk`
- `build/`
- `.dart_tool/`
- `.gradle/`
- `.env`
- `serviceAccountKey.json`
- `google-services.json`
- `GoogleService-Info.plist`
- Firebase Admin SDK key patterns
- Python virtualenv and cache folders

## Secrets Check Result

Tracked-file checks found no committed Firebase service account JSON, `google-services.json`, `.env`, APK, AAB, build output, or Gradle/Dart cache files.

Local ignored secrets/config files observed:

- `apps/park_here_user/android/app/google-services.json`
- `apps/park_here_admin/android/app/google-services.json`
- `demo/serviceAccountKey.json`
- `server/serviceAccountKey.json`

These are ignored and should remain local. If any of these files were ever shared outside the local machine, rotate the corresponding Firebase credentials.

Intentional demo credentials remain documented for `@parkhere.demo` accounts. They are development/demo credentials only and must not be reused in production.

## QR And Firebase Checks

- New QR payload generation uses opaque `qrId` only through `QrPayloadService.buildPayload`.
- Tests assert new QR payloads do not contain `userId`, vehicle data, or `bookingId`.
- Legacy JSON QR parsing remains migration-safe, but new generation does not emit booking JSON.
- Booking creation stores QR state in Firestore and active QR documents use one live `status` field: `active` or `entry_verified`.
- QR consumption uses Firestore transactions in `FirebaseBookingRepository.consumeQrTicket`.
- Slot reservation/release and review/image writes use Firestore transactions where consistency matters.
- User-facing Firebase errors are routed through `FirebaseErrorMessages.friendlyMessage`, including index-building errors.
- Runtime user/admin providers use Firebase repositories by default. In-memory/demo repositories remain for tests and explicit overrides.
- Demo reset deletes demo Auth users by domain by default and requires explicit dangerous confirmation phrases for full Auth/Firestore deletion.

## Vulnerabilities / Issues Found

- No tracked service account files or raw private keys found.
- No tracked APK/AAB artifacts remain after cleanup.
- `flutter pub outdated` reports outdated dependencies. Most Firebase packages have patch updates available, and several UI/plugin dependencies have newer major versions. No dedicated advisory scanner was available in this workspace, so this is dependency freshness rather than confirmed CVE output.
- APK blobs were committed in earlier history before this cleanup. Latest `main` no longer tracks them, but removing blobs from remote Git history would require history rewriting/force-push, which was not allowed.

## Fixes Applied

- Removed generated/cache artifacts from the working tree.
- Removed local APK outputs from the working tree.
- Added explicit ignore coverage for `apk/` and root `.gradle/`.
- Added this security recheck report.

## Commands Run

```powershell
git status --short --branch
git branch
git log --oneline --graph --decorate --all -40
git ls-files | rg "..."
rg "...secret patterns..." .
rg "...QR/Firebase safety patterns..." shared apps demo docs tools
flutter pub outdated
flutter analyze shared
flutter analyze apps\park_here_user
flutter analyze apps\park_here_admin
python -m py_compile <demo python files>
git check-ignore -v <local Firebase config/key paths>
```

## Remaining Risks

- Dependency upgrades should be planned separately because several packages have major-version changes.
- Firebase security rules should be reviewed again before production deployment with real users/payments.
- Local ignored Firebase config and service account files must stay off Git and should be rotated if exposed.
- Old APK blobs remain in remote history unless the team explicitly approves a history-rewrite cleanup.

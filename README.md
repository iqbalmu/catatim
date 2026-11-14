# CatatIM

An offline-first personal finance tracker for Android. Transactions from bank
and e-wallet notifications are captured automatically through Android's
`NotificationListenerService`, then curated into transactions by per-bank
rules. Everything is stored encrypted (SQLCipher) on the device: no server,
no account, no ads.

[![CI](https://github.com/iqbalmu/catatim/actions/workflows/ci.yml/badge.svg)](https://github.com/iqbalmu/catatim/actions/workflows/ci.yml)

## Features

Four main tabs: **Home · Transactions · Bon · Reports**, with a contextual +
button in the middle of the nav bar.

- **Automatic capture**: bank/e-wallet notifications → drafts → per-bank
  rules → final transactions. Uncertain drafts land in an inbox for manual
  curation (accept, ignore once, or ignore the pattern forever).
  Deduplication: duplicate notifications (push + SMS / resend) with the same
  bank, amount, and direction within ±120 seconds become a single
  transaction.
- **Receipt scanning**: photos of receipts are read by on-device OCR
  (ML Kit), uploaded nowhere. Also accepts shared text or images from other
  apps.
- **Transactions**: searchable list with account and period filters, plus a
  cash-flow summary. Tap a transaction to edit or delete it.
- **Reports**: cash-flow summary, weekly/monthly trends, category
  composition, and top expenses for a selected month or any custom range.
- **Budgets**: daily/weekly/monthly limits plus per-category allocations,
  optionally scoped to one account (e.g. "Food @ e-wallet"). Reachable from
  Home or Settings.
- **Bon** (personal IOUs): debts and receivables with a one-tap settle
  action; bons older than 30 days show a badge on the nav bar.
- **Notifications**: one attention center (permission off, limits exceeded,
  old bons) plus a raw-capture tab for tuning rules.
- **CatatIM Quest**: the Pochy mascot mirrors your budget condition;
  discipline streaks are computed from real data (3/7/14/21/30/60/100-day
  milestones).
- **Multi-account**: banks, e-wallets, and cash; each account has an opening
  balance and a running balance.
- **Backup**: an encrypted database copy protected by a PIN, with restore.
  The database key is device-bound (Android Keystore), so backups from
  another device go through a recovery flow.
- **Theming**: light/dark follows the system; the preference is stored.

## Permissions used

| Permission | Why |
|---|---|
| Notification access | Reads bank/e-wallet notifications as the transaction source. Core feature; no other notification content is used beyond creating drafts. |
| `CAMERA` | Photographing receipts for on-device OCR. |
| `POST_NOTIFICATIONS` | Showing local budget warnings (not marketing notifications). |
| `INTERNET` | Brought in by the ML Kit dependency. The app's own code makes no network calls: no HTTP client, no Firebase, no analytics. |

## Getting started

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generate drift code
flutter run                                                # or: flutter build apk
```

Requires a Flutter version that provides Dart SDK `^3.12.1` (see
`pubspec.yaml`) and the Android SDK.

First-time capture setup: Settings → **Auto capture** → *Start* → read the
disclosure → "I understand" → enable CatatIM under Android's *Notification
access*. To explore the app without real data, Settings offers **Fill sample
data** (debug builds only).

## Testing notifications over adb

`scripts/test_capture.sh` fires simulated notifications at a connected
device through a built-in `BroadcastReceiver` (debug builds only), without
moving any real money:

```bash
./scripts/test_capture.sh blu      # blu by BCA preset
./scripts/test_capture.sh nagari   # Bank Nagari / Ollin preset
./scripts/test_capture.sh guard    # negative: OTP/promos must be rejected
./scripts/test_capture.sh send --pkg com.bca --title "t" --body "b"
```

The seed rules (`assets/rules/seed_rules.json`) are built from common
formats and are not yet validated against real notifications from every
bank. To tune them: make one small transaction, open **Auto capture →
Maintenance**, adjust `matchAll`/`matchAny`/`counterparty`/`amount` in the
rules, then tap *re-read* to reprocess raw notifications without creating
new transactions.

## Build rilis

Buat keystore (sekali, simpan baik-baik — hilang = tak bisa update app):

```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Lalu buat `android/key.properties` (di-gitignore):

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=upload-keystore.jks
```

Tanpa `key.properties`, build release jatuh ke debug key — cukup untuk
uji lokal, bukan untuk didistribusikan. Build siap unggah:

```bash
flutter build appbundle                   # Play Store
flutter build apk --split-per-abi         # ±24 MB per ABI, bukan fat APK
```

## Project layout

| Path | What lives there |
|---|---|
| `lib/capture/` | Native MethodChannel/EventChannel bridge and the capture → parse → store pipeline |
| `lib/rules/` | Rules engine plus the rule format (`assets/rules/seed_rules.json`) |
| `lib/storage/` | Drift (SQLCipher) schema and repository, with a 120-second dedup window |
| `lib/notify/` | Local notification channel and budget warnings |
| `lib/ui/` | Four-tab shell: Home, Transactions, Bon, Reports; Settings, Budgets, receipt scanning, and supporting sheets |
| `lib/game/` | Mascot, streaks, quest progress |
| `lib/theme/` | Quest design system (Slate-Indigo, not default Material) |
| `android/.../MainActivity.kt` | `MainActivity`, `NotificationCatcher`, `NotificationSimulatorReceiver` |
| `scripts/` | adb-based simulated notification injection |

## License

[MIT](LICENSE).

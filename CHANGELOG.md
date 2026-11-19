# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-11-19

### Added
- Offline-first personal finance ledger encrypted with SQLCipher via Drift.
- Automatic bank and e-wallet notification capture (`NotificationListenerService`) with per-bank rule matching, 120-second deduplication, draft inbox with bulk per-bank accept, notification source viewer, capture health monitoring, and auto-category learning from keyword votes.
- On-device receipt OCR scanning (Google ML Kit) with receipt photo attachments and Android share-target support.
- Four-tab navigation (**Home · Transactions · Bon · Reports**) with contextual `+` action, searchable transactions, CSV export, category/account budgets, and personal IOUs (**Bon**) with due dates and one-tap settlement.
- Scheduled local daily reminders and bon due-date reminders.
- Android home screen widgets (including 2x2 mini widget and mood cards) with dynamic Pochy mascot and daily pace.
- CatatIM Quest gamification (Pochy mascot mood states and real-data discipline streaks) and encrypted PIN-protected backup/restore.

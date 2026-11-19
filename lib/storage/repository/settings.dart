part of '../repository.dart';

// SECTION: settings.dart
extension SettingsRepo on LedgerRepository {
  /// Apakah draf hasil parse langsung dicatat tanpa menunggu konfirmasi.
  Future<bool> autoRecordEnabled() async =>
      await getSetting(LedgerRepository.autoRecordKey) == '1';

  Future<void> setAutoRecordEnabled(bool on) =>
      setSetting(LedgerRepository.autoRecordKey, on ? '1' : '0');

  Stream<bool> watchAutoRecordEnabled() {
    return (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(LedgerRepository.autoRecordKey)))
        .watchSingleOrNull()
        .map((row) => row?.valueText == '1');
  }

  /// Notifikasi peringatan batas pengeluaran aktif.
  Future<bool> budgetAlertsEnabled() async =>
      await getSetting(LedgerRepository.budgetAlertsEnabledKey) == '1';

  Future<void> setBudgetAlertsEnabled(bool on) =>
      setSetting(LedgerRepository.budgetAlertsEnabledKey, on ? '1' : '0');

  Stream<bool> watchBudgetAlertsEnabled() {
    return (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(LedgerRepository.budgetAlertsEnabledKey)))
        .watchSingleOrNull()
        .map((row) => row?.valueText == '1');
  }

  /// Persen ambang peringatan (1–100; nilai rusak → bawaan 80).
  Future<int> budgetAlertThreshold() async {
    final raw = int.tryParse(
      await getSetting(LedgerRepository.budgetAlertThresholdKey) ?? '',
    );
    return (raw == null || raw < 1 || raw > 100)
        ? LedgerRepository.defaultBudgetAlertThreshold
        : raw;
  }

  Future<void> setBudgetAlertThreshold(int percent) => setSetting(
    LedgerRepository.budgetAlertThresholdKey,
    percent.clamp(1, 100).toString(),
  );

  /// State dedup peringatan: {scope#jenis: periodKey}. Disimpan agar
  /// satu garis hanya menembak sekali per periode.
  Future<Map<String, String>> budgetAlertState() async {
    final raw = await getSetting(LedgerRepository.budgetAlertStateKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries) '${entry.key}': '${entry.value}',
      };
    } catch (_) {
      return const {};
    }
  }

  Future<void> setBudgetAlertState(Map<String, String> state) =>
      setSetting(LedgerRepository.budgetAlertStateKey, jsonEncode(state));

  // --- settings -----------------------------------------------------------------

  Future<String?> getSetting(String key) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.valueText;
  }

  Future<void> setSetting(String key, String value) {
    return _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, valueText: value),
        );
  }

  /// Stream nilai setting integer (mis. batas harian/mingguan/bulanan) secara reaktif.
  Stream<int?> watchIntSetting(String key) {
    return (_db.select(
      _db.appSettings,
    )..where((s) => s.key.equals(key))).watchSingleOrNull().map((row) {
      final text = row?.valueText.trim();
      if (text == null || text.isEmpty) return null;
      return int.tryParse(text);
    });
  }

  /// Stream nilai beberapa key app_settings sekaligus (satu query) —
  /// dipakai layar Anggaran untuk batas + filter kategorinya.
  Stream<Map<String, String>> watchSettings(List<String> keys) {
    final query = _db.select(_db.appSettings)..where((s) => s.key.isIn(keys));
    return query.watch().map(
      (rows) => {for (final r in rows) r.key: r.valueText},
    );
  }

  /// Mode tema aplikasi: system, light, atau dark.
  Future<ThemeMode> getThemeMode() async {
    final raw = await getSetting(LedgerRepository.themeModeKey);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  /// Stream reaktif mode tema aplikasi.
  Stream<ThemeMode> watchThemeMode() {
    return (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(LedgerRepository.themeModeKey)))
        .watchSingleOrNull()
        .map((row) {
          final raw = row?.valueText;
          return switch (raw) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          };
        });
  }

  /// Ubah dan simpan mode tema aplikasi.
  Future<void> setThemeMode(ThemeMode mode) {
    final val = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    return setSetting(LedgerRepository.themeModeKey, val);
  }

  /// Pengingat catat harian aktif.
  Future<bool> dailyReminderEnabled() async =>
      await getSetting(LedgerRepository.dailyReminderEnabledKey) == '1';

  Future<void> setDailyReminderEnabled(bool on) =>
      setSetting(LedgerRepository.dailyReminderEnabledKey, on ? '1' : '0');

  Stream<bool> watchDailyReminderEnabled() {
    return (_db.select(
          _db.appSettings,
        )..where((s) => s.key.equals(LedgerRepository.dailyReminderEnabledKey)))
        .watchSingleOrNull()
        .map((row) => row?.valueText == '1');
  }

  /// Jam pengingat harian dalam menit dari tengah malam (0..1439, default 20:00).
  Future<int> dailyReminderMinutes() async {
    final raw = int.tryParse(
      await getSetting(LedgerRepository.dailyReminderMinutesKey) ?? '',
    );
    if (raw == null || raw < 0 || raw >= 24 * 60) {
      return LedgerRepository.defaultDailyReminderMinutes;
    }
    return raw;
  }

  Future<void> setDailyReminderMinutes(int minutes) => setSetting(
    LedgerRepository.dailyReminderMinutesKey,
    minutes.clamp(0, 24 * 60 - 1).toString(),
  );

  /// Pengingat jatuh tempo bon aktif (bawaan aktif agar bon bertanggal otomatis diingatkan).
  Future<bool> bonReminderEnabled() async {
    final raw = await getSetting(LedgerRepository.bonReminderEnabledKey);
    return raw == null || raw == '1';
  }

  Future<void> setBonReminderEnabled(bool on) =>
      setSetting(LedgerRepository.bonReminderEnabledKey, on ? '1' : '0');

  Stream<bool> watchBonReminderEnabled() {
    return (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(LedgerRepository.bonReminderEnabledKey)))
        .watchSingleOrNull()
        .map((row) => row == null || row.valueText == '1');
  }

  Future<List<int>> scheduledBonReminderIds() async {
    final raw = await getSetting(LedgerRepository.scheduledBonReminderIdsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.whereType<num>().map((e) => e.toInt()).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> setScheduledBonReminderIds(List<int> ids) =>
      setSetting(LedgerRepository.scheduledBonReminderIdsKey, jsonEncode(ids));
}

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
    final raw = int.tryParse(await getSetting(LedgerRepository.budgetAlertThresholdKey) ?? '');
    return (raw == null || raw < 1 || raw > 100)
        ? LedgerRepository.defaultBudgetAlertThreshold
        : raw;
  }

  Future<void> setBudgetAlertThreshold(int percent) =>
      setSetting(LedgerRepository.budgetAlertThresholdKey, percent.clamp(1, 100).toString());

  /// State dedup peringatan: {scope#jenis: periodKey}. Disimpan agar
  /// satu garis hanya menembak sekali per periode.
  Future<Map<String, String>> budgetAlertState() async {
    final raw = await getSetting(LedgerRepository.budgetAlertStateKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          '${entry.key}': '${entry.value}',
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
    final query = _db.select(_db.appSettings)
      ..where((s) => s.key.isIn(keys));
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
    return (_db.select(
      _db.appSettings,
    )..where((s) => s.key.equals(LedgerRepository.themeModeKey))).watchSingleOrNull().map((row) {
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

}

part of '../repository.dart';

// SECTION: banks_rules.dart
extension BanksRulesRepo on LedgerRepository {
  /// ID bank/e-wallet katalog (seed_rules) yang sedang terhubung.
  Future<Set<String>> connectedBankIds() async {
    final raw = await getSetting(LedgerRepository.connectedBanksKey);
    if (raw == null || raw.trim().isEmpty) return {};
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  /// Versi hidup dari [connectedBankIds].
  Stream<Set<String>> watchConnectedBanks() {
    return (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(LedgerRepository.connectedBanksKey)))
        .watchSingleOrNull()
        .map((row) {
          final raw = row?.valueText;
          if (raw == null || raw.trim().isEmpty) return {};
          return raw
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toSet();
        });
  }

  /// Hubungkan / putuskan satu bank. Urutan koneksi dipertahankan.
  Future<void> setBankConnected(String bankId, bool connected) async {
    final current = (await connectedBankIds()).toList();
    if (connected && !current.contains(bankId)) {
      current.add(bankId);
    } else if (!connected) {
      current.remove(bankId);
    }
    await setSetting(LedgerRepository.connectedBanksKey, current.join(','));
  }

  /// App apa pun yang dihubungkan user lewat Mode Belajar — disimpan
  /// sebagai baris "paket|nama" di app_settings.
  Future<List<({String package, String label})>> customBanks() async {
    final raw = await getSetting(LedgerRepository.customBanksKey);
    return _parseCustomBanks(raw);
  }

  /// Versi hidup dari [customBanks].
  Stream<List<({String package, String label})>> watchCustomBanks() {
    return (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(LedgerRepository.customBanksKey)))
        .watchSingleOrNull()
        .map((row) => _parseCustomBanks(row?.valueText));
  }

  static List<({String package, String label})> _parseCustomBanks(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return [
      for (final line in raw.split('\n'))
        if (line.contains('|'))
          (
            package: line.substring(0, line.indexOf('|')).trim(),
            label: line.substring(line.indexOf('|') + 1).trim(),
          ),
    ];
  }

  /// Hubungkan / putuskan app custom. bankId-nya berbentuk `app:<paket>`.
  Future<void> setCustomBankConnected(
    String package,
    String label,
    bool connected,
  ) async {
    final current = [...await customBanks()];
    if (connected && !current.any((c) => c.package == package)) {
      current.add((package: package, label: label));
    } else if (!connected) {
      current.removeWhere((c) => c.package == package);
    }
    await setSetting(
      LedgerRepository.customBanksKey,
      [for (final c in current) '${c.package}|${c.label}'].join('\n'),
    );
  }

  Future<List<CustomTemplate>> customTemplates() async {
    final raw = await getSetting(LedgerRepository.customTemplatesKey);
    return _parseCustomTemplates(raw);
  }

  Stream<List<CustomTemplate>> watchCustomTemplates() {
    return (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(LedgerRepository.customTemplatesKey)))
        .watchSingleOrNull()
        .map((row) => _parseCustomTemplates(row?.valueText));
  }

  static List<CustomTemplate> _parseCustomTemplates(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>? ?? const [];
      return [
        for (final item in list)
          if (item is Map<String, dynamic>) CustomTemplate.fromJson(item),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveCustomTemplate(CustomTemplate template) async {
    final current = [...await customTemplates()];
    final idx = current.indexWhere((t) => t.id == template.id);
    if (idx >= 0) {
      current[idx] = template;
    } else {
      current.add(template);
    }
    await setSetting(
      LedgerRepository.customTemplatesKey,
      jsonEncode([for (final t in current) t.toJson()]),
    );
  }

  Future<void> deleteCustomTemplate(String id) async {
    final current = [...await customTemplates()];
    current.removeWhere((t) => t.id == id);
    await setSetting(
      LedgerRepository.customTemplatesKey,
      jsonEncode([for (final t in current) t.toJson()]),
    );
  }

  Future<List<IgnoredPattern>> ignoredPatterns() async {
    final raw = await getSetting(LedgerRepository.ignoredPatternsKey);
    return _parseIgnoredPatterns(raw);
  }

  Stream<List<IgnoredPattern>> watchIgnoredPatterns() {
    return (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(LedgerRepository.ignoredPatternsKey)))
        .watchSingleOrNull()
        .map((row) => _parseIgnoredPatterns(row?.valueText));
  }

  static List<IgnoredPattern> _parseIgnoredPatterns(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>? ?? const [];
      return [
        for (final item in list)
          if (item is Map<String, dynamic>) IgnoredPattern.fromJson(item),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> addIgnoredPattern({
    required String pattern,
    required String label,
    String? bankId,
  }) async {
    final cleanPattern = pattern.trim().toLowerCase();
    if (cleanPattern.isEmpty) return;
    final current = [...await ignoredPatterns()];
    if (current.any((p) => p.pattern == cleanPattern && p.bankId == bankId)) {
      return;
    }
    current.add(
      IgnoredPattern(
        id: newUuid(),
        pattern: cleanPattern,
        label: label.trim(),
        bankId: bankId,
        createdAt: DateTime.now(),
      ),
    );
    await setSetting(
      LedgerRepository.ignoredPatternsKey,
      jsonEncode([for (final p in current) p.toJson()]),
    );
  }

  Future<void> deleteIgnoredPattern(String id) async {
    final current = [...await ignoredPatterns()];
    current.removeWhere((p) => p.id == id);
    await setSetting(
      LedgerRepository.ignoredPatternsKey,
      jsonEncode([for (final p in current) p.toJson()]),
    );
  }
}

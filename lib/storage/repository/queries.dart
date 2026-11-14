part of '../repository.dart';

// SECTION: queries.dart
extension QueriesRepo on LedgerRepository {
  // --- query transaksi --------------------------------------------------------

  JoinedSelectStatement _withCategoryQuery({
    DateTime? start,
    DateTime? end,
    int? limit,
    int? accountId,
  }) {
    final query = _db.select(_db.transactions).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ]);
    if (start != null && end != null) {
      // Periode [start, end) — ujung atas eksklusif;
      // transaksi tepat 00:00 bulan berikutnya milik bulan itu sendiri.
      query.where(
        _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      );
    }
    if (accountId != null) {
      query.where(_db.transactions.accountId.equals(accountId));
    }
    query.orderBy([OrderingTerm.desc(_db.transactions.occurredAt)]);
    if (limit != null) query.limit(limit);
    return query;
  }

  List<TxWithCategory> _mapRows(List<TypedResult> rows) => [
    for (final row in rows)
      TxWithCategory(
        tx: row.readTable(_db.transactions),
        category: row.readTableOrNull(_db.categories),
      ),
  ];

  Stream<List<TxWithCategory>> watchBetweenWithCategory(
    DateTime start,
    DateTime end, {
    int? accountId,
  }) => _withCategoryQuery(
    start: start,
    end: end,
    accountId: accountId,
  ).watch().map(_mapRows);

  Stream<List<TxWithCategory>> watchRecentWithCategory({
    int limit = 300,
    int? accountId,
  }) => _withCategoryQuery(
    limit: limit,
    accountId: accountId,
  ).watch().map(_mapRows);

  /// Jumlah transaksi per hari (UTC; drift menyimpan occurred_at sebagai
  /// epoch-ms UTC dan pembacaan lama juga mengelompokkan lewat field UTC)
  /// sejak [since] — sumber kebenaran streak di ProgressService.
  /// Diagregasi di SQLite (audit O-03), bukan menarik baris mentah.
  /// Bucket = hari LOKAL (modifier offset perangkat) — semantik sama
  /// dengan pembacaan Dart lama; drift menyimpan occurred_at epoch-detik.
  static String get _localTzModifier {
    final m = DateTime.now().timeZoneOffset.inMinutes;
    return m >= 0 ? '+$m minutes' : '-${-m} minutes';
  }

  Future<Map<DateTime, int>> txCountByDaySince(DateTime since) async {
    final rows = await _db
        .customSelect(
          "SELECT date(occurred_at, 'unixepoch', '$_localTzModifier') AS day, COUNT(*) AS c "
          'FROM transactions WHERE occurred_at >= ? GROUP BY day',
          variables: [Variable.withInt(since.millisecondsSinceEpoch ~/ 1000)],
          readsFrom: {_db.transactions},
        )
        .get();
    return {
      for (final r in rows)
        DateTime.parse(r.read<String>('day')): r.read<int>('c'),
    };
  }

  /// Total belanja MURNI per hari sejak [since] (inklusif); transfer ke
  /// pihak lain ikut, perpindahan dana milik sendiri tidak. Diagregasi
  /// di SQLite (audit O-03).
  ///
  /// [categories]=white-list kategori: null = semua kategori; set berisi
  /// [kUncategorizedId] juga menghitung transaksi tanpa kategori.
  Future<Map<DateTime, int>> outSpendByDaySince(
    DateTime since, {
    Set<int>? categories,
  }) async {
    if (categories != null && categories.isEmpty) return {};
    final sql = StringBuffer(
      "SELECT date(occurred_at, 'unixepoch', '$_localTzModifier') AS day, SUM(amount) AS s "
      'FROM transactions '
      "WHERE direction = 'outgoing' AND kind NOT IN ('internal', 'topup', 'withdrawal') "
      'AND occurred_at >= ?',
    );
    final variables = <Variable>[
      Variable.withInt(since.millisecondsSinceEpoch ~/ 1000),
    ];
    if (categories != null) {
      final ids = categories.where((id) => id != kUncategorizedId).toList();
      final clauses = <String>[];
      if (ids.isNotEmpty) {
        clauses.add(
          'category_id IN (${List.filled(ids.length, '?').join(', ')})',
        );
        variables.addAll(ids.map(Variable.withInt));
      }
      if (categories.contains(kUncategorizedId)) {
        clauses.add('category_id IS NULL');
      }
      if (clauses.isNotEmpty) sql.write(' AND (${clauses.join(' OR ')})');
    }
    sql.write(' GROUP BY day');
    final rows = await _db
        .customSelect(
          sql.toString(),
          variables: variables,
          readsFrom: {_db.transactions},
        )
        .get();
    return {
      for (final r in rows)
        DateTime.parse(r.read<String>('day')): r.read<int>('s'),
    };
  }

  /// Pemicu reaktif pemakaian batas: emit saat transaksi berubah ATAU
  /// filter kategori batas berubah — app_settings ikut readsFrom supaya
  /// kartu batas ikut berubah begitu user mengganti filter kategori.
  Stream<void> watchOutSpendTrigger(DateTime since) {
    return _db
        .customSelect(
          'SELECT 1 FROM transactions WHERE occurred_at >= ? LIMIT 1',
          variables: [Variable.withInt(since.millisecondsSinceEpoch ~/ 1000)],
          readsFrom: {_db.transactions, _db.appSettings},
        )
        .watch()
        .map((_) {});
  }

  /// Keluar bulan dikelompokkan per pasangan (kategori, akun) dalam
  /// [start, end). Kunci kategori null = tanpa kategori, dst.
  Stream<Map<({int? category, int? account}), int>> watchOutPairsBetween(
    DateTime start,
    DateTime end,
  ) {
    final amountSum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([
        _db.transactions.categoryId,
        _db.transactions.accountId,
        amountSum,
      ])
      ..where(
        _db.transactions.direction.equalsValue(Direction.outgoing) &
            _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      )
      ..groupBy([_db.transactions.categoryId, _db.transactions.accountId]);
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          (
            category: row.read(_db.transactions.categoryId),
            account: row.read(_db.transactions.accountId),
          ): row.read(amountSum) ?? 0,
      },
    );
  }

  /// Versi one-shot dari [watchOutPairsBetween].
  Future<Map<({int? category, int? account}), int>> outPairsBetween(
    DateTime start,
    DateTime end,
  ) async {
    final amountSum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([
        _db.transactions.categoryId,
        _db.transactions.accountId,
        amountSum,
      ])
      ..where(
        _db.transactions.direction.equalsValue(Direction.outgoing) &
            _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      )
      ..groupBy([_db.transactions.categoryId, _db.transactions.accountId]);
    final rows = await query.get();
    return {
      for (final row in rows)
        (
          category: row.read(_db.transactions.categoryId),
          account: row.read(_db.transactions.accountId),
        ): row.read(amountSum) ?? 0,
    };
  }

  /// Total (masuk atau keluar) dalam [start, end) — hidup (watch).
  Stream<int> watchSumBetween(
    DateTime start,
    DateTime end,
    Direction direction,
  ) {
    final amountSum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([amountSum])
      ..where(
        _db.transactions.direction.equalsValue(direction) &
            _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      );
    return query.watchSingle().map((row) => row.read(amountSum) ?? 0);
  }

  /// Versi one-shot dari [watchSumBetween] — untuk perhitungan sekali
  /// jalan (ProgressService.refresh) tanpa langganan stream.
  Future<int> sumBetween(
    DateTime start,
    DateTime end,
    Direction direction,
  ) async {
    final amountSum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([amountSum])
      ..where(
        _db.transactions.direction.equalsValue(direction) &
            _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      );
    final row = await query.getSingle();
    return row.read(amountSum) ?? 0;
  }

  /// Ringkasan arus kas bulanan (total masuk, total keluar, dan selisih bersih)
  /// langsung dari agregasi SQL SQLite menggunakan covering index.
  /// Transaksi transfer dikecualikan agar tidak menggelembungkan arus kas riil.
  Stream<({int totalIn, int totalOut, int net})> watchMonthlyCashflow(
    DateTime start,
    DateTime end, {
    int? accountId,
  }) {
    final inSum = _db.transactions.amount.sum(
      filter:
          _db.transactions.direction.equalsValue(Direction.incoming) &
          _db.transactions.kind
              .isInValues(LedgerRepository._internalKinds)
              .not(),
    );
    final outSum = _db.transactions.amount.sum(
      filter:
          _db.transactions.direction.equalsValue(Direction.outgoing) &
          _db.transactions.kind
              .isInValues(LedgerRepository._internalKinds)
              .not(),
    );

    final query = _db.selectOnly(_db.transactions)
      ..addColumns([inSum, outSum])
      ..where(
        _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      );

    if (accountId != null) {
      query.where(_db.transactions.accountId.equals(accountId));
    }

    return query.watchSingle().map((row) {
      final totalIn = row.read(inSum) ?? 0;
      final totalOut = row.read(outSum) ?? 0;
      return (totalIn: totalIn, totalOut: totalOut, net: totalIn - totalOut);
    });
  }

  /// Total keluar MURNI dalam [start, end): outgoing tanpa perpindahan
  /// dana milik sendiri (internal/topup/tarik tunai). Transfer ke pihak
  /// lain tetap dihitung — itu pengeluaran riil.
  ///
  /// [categories]=white-list kategori: null = semua kategori; set berisi
  /// [kUncategorizedId] juga menghitung transaksi tanpa kategori.
  Future<int> sumSpendBetween(
    DateTime start,
    DateTime end, {
    Set<int>? categories,
  }) async {
    if (categories != null && categories.isEmpty) return 0;
    final amountSum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([amountSum])
      ..where(
        _db.transactions.direction.equalsValue(Direction.outgoing) &
            _db.transactions.kind
                .isInValues(LedgerRepository._internalKinds)
                .not() &
            _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      );
    final filter = _categoryFilter(categories);
    if (filter != null) query.where(filter);
    final row = await query.getSingle();
    return row.read(amountSum) ?? 0;
  }

  /// Filter kategori untuk query — null berarti tanpa filter (semua
  /// kategori). Set kosong ditangani pemanggil (hasil selalu nol).
  Expression<bool>? _categoryFilter(Set<int>? categories) {
    if (categories == null) return null;
    final ids = categories.where((id) => id != kUncategorizedId).toList();
    final includeUncategorized = categories.contains(kUncategorizedId);
    final Expression<bool> selected = ids.isEmpty
        ? _db.transactions.categoryId.isNull()
        : _db.transactions.categoryId.isIn(ids);
    if (!includeUncategorized || ids.isEmpty) return selected;
    return selected | _db.transactions.categoryId.isNull();
  }

  /// Versi pemasukan-murni dari [sumBetween]: kind transfer dikecualikan.
  Future<int> sumIncomeBetween(DateTime start, DateTime end) async {
    final amountSum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([amountSum])
      ..where(
        _db.transactions.direction.equalsValue(Direction.incoming) &
            _db.transactions.kind
                .isInValues(LedgerRepository._internalKinds)
                .not() &
            _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      );
    final row = await query.getSingle();
    return row.read(amountSum) ?? 0;
  }

  /// Versi belanja-murni dari [outPairsBetween]: perpindahan dana milik
  /// sendiri dikecualikan (internal/topup/tarik tunai), transfer ke pihak
  /// lain tetap ikut.
  Future<Map<({int? category, int? account}), int>> outSpendPairsBetween(
    DateTime start,
    DateTime end,
  ) async {
    final amountSum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([
        _db.transactions.categoryId,
        _db.transactions.accountId,
        amountSum,
      ])
      ..where(
        _db.transactions.direction.equalsValue(Direction.outgoing) &
            _db.transactions.kind
                .isInValues(LedgerRepository._internalKinds)
                .not() &
            _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      )
      ..groupBy([_db.transactions.categoryId, _db.transactions.accountId]);
    final rows = await query.get();
    return {
      for (final row in rows)
        (
          category: row.read(_db.transactions.categoryId),
          account: row.read(_db.transactions.accountId),
        ): row.read(amountSum) ?? 0,
    };
  }

  /// Saldo berjalan tiap akun = saldo awal + masuk − keluar. Transfer/
  /// topup satu kaki sementara dihitung sebagai keluar/masuk akun asal;
  /// transfer dua kaki menyusul.
  Stream<Map<int, int>> watchAccountBalances() {
    final inSum = _db.transactions.amount.sum(
      filter: _db.transactions.direction.equalsValue(Direction.incoming),
    );
    final outSum = _db.transactions.amount.sum(
      filter: _db.transactions.direction.equalsValue(Direction.outgoing),
    );
    final query = _db.selectOnly(_db.accounts).join([
      leftOuterJoin(
        _db.transactions,
        _db.transactions.accountId.equalsExp(_db.accounts.id),
      ),
    ]);
    query.addColumns([
      _db.accounts.id,
      _db.accounts.openingBalance,
      inSum,
      outSum,
    ]);
    query.groupBy([_db.accounts.id]);
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.read(_db.accounts.id)!:
              _intOf(row.read(_db.accounts.openingBalance)) +
              _intOf(row.read(inSum)) -
              _intOf(row.read(outSum)),
      },
    );
  }

  Future<Map<int, int>> getAccountBalances() async {
    final inSum = _db.transactions.amount.sum(
      filter: _db.transactions.direction.equalsValue(Direction.incoming),
    );
    final outSum = _db.transactions.amount.sum(
      filter: _db.transactions.direction.equalsValue(Direction.outgoing),
    );
    final query = _db.selectOnly(_db.accounts).join([
      leftOuterJoin(
        _db.transactions,
        _db.transactions.accountId.equalsExp(_db.accounts.id),
      ),
    ]);
    query.addColumns([
      _db.accounts.id,
      _db.accounts.openingBalance,
      inSum,
      outSum,
    ]);
    query.groupBy([_db.accounts.id]);
    final rows = await query.get();
    return {
      for (final row in rows)
        row.read(_db.accounts.id)!:
            _intOf(row.read(_db.accounts.openingBalance)) +
            _intOf(row.read(inSum)) -
            _intOf(row.read(outSum)),
    };
  }

  static int _intOf(Object? value) => (value as num?)?.toInt() ?? 0;
}

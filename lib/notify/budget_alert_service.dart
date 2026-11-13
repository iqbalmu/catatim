import '../core/budget.dart' show BudgetSnapshot, LimitLine;
import '../core/budget_alert.dart';
import '../storage/repository.dart';
import 'notify_channel.dart';

/// Menampilkan notifikasi Android saat pengeluaran baru menyentuh
/// persentase batas. Dipanggil dari ProgressService tiap transaksi
/// tercatat — bukan saat app dibuka, agar tidak berisik saat user
/// membuka app (info kondisi sudah ada di hero card Beranda).
///
/// Batasan jujur: Dart hanya jalan saat proses app hidup (konsisten
/// pipeline capture). Crossing yang terjadi saat proses mati menyusul
/// di event transaksi berikutnya — state dedup membuatnya sekali saja.
class BudgetAlertService {
  BudgetAlertService({
    required LedgerRepository repository,
    NotifyChannel? channel,
  }) : _repo = repository,
       _channel = channel ?? const NotifyChannel();

  final LedgerRepository _repo;
  final NotifyChannel _channel;

  Future<void> check(BudgetSnapshot snapshot) async {
    try {
      if (!await _repo.budgetAlertsEnabled()) return;
      final threshold = await _repo.budgetAlertThreshold();
      final state = await _repo.budgetAlertState();
      ({int used, int? limit})? usage(LimitLine? line) =>
          line == null ? null : (used: line.used, limit: line.limit);
      final plan = planBudgetAlerts(
        lines: {
          BudgetAlertScope.daily: usage(snapshot.lineByLabel(kLineDaily)),
          BudgetAlertScope.weekly: usage(snapshot.lineByLabel(kLineWeekly)),
          BudgetAlertScope.monthly: usage(snapshot.lineByLabel(kLineMonthly)),
        },
        thresholdPercent: threshold,
        state: state,
        now: DateTime.now(),
      );
      if (plan.hits.isEmpty) return;
      await _repo.setBudgetAlertState(plan.newState);
      final message = budgetAlertMessage(plan.hits, thresholdPercent: threshold);
      if (message == null) return;
      await _channel.showBudgetAlert(title: message.title, body: message.body);
    } catch (_) {
      // DB tengah ditutup / channel gagal — jangan ganggu pencatatan.
    }
  }
}

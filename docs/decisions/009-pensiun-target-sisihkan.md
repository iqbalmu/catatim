# ADR-009: Pensiun segmen Target/Sisihkan — Rencana = Batas saja

## Status

Diterima (2026-10-16, commit `f37a1ef` `feat(rencana)!: hapus segmen
target & sisihkan`).

## Konteks

Rencana lahir dengan dua segmen: **Batas** (batas harian/mingguan/
bulanan + alokasi per jenis anggaran) dan **Target/Sisihkan**
(tabungan tujuan: engine laju setoran, model akun-virtual, skema v7).
Dua mekanisme berarti dua cara menghitung uang keluar — setoran target
bukan belanja, tapi alokasi batas menghitung pemakaian — sehingga
pace, streak, dan kalender butuh pengecualian khusus agar tidak
saling menggerogoti.

## Keputusan

Target/Sisihkan dipensiunkan. Skema DB v8 men-drop tabel `targets` dan
`target_deposits` saat upgrade; layar Rencana kini hanya berisi Batas
(jenis anggaran yang dikelola user + alokasi per jenis, opsional
di-scope ke akun). Riwayat setoran lama tidak hilang: tetap ada
sebagai transaksi transfer biasa (`bankId 'target'`). Pace, streak,
dan kalender rekap dihitung dari **belanja murni** — transfer biasa
tidak menggerogoti batas maupun alokasi jenis.

## Alternatif yang ditolak

Pertahankan dua mekanisme: menampung kasus "nabung untuk tujuan"
dengan harga kompleksitas akuntansi ganda di setiap agregat, tanpa
bukti kebutuhan yang mewajibkan layar tersendiri — sejalan dengan
non-goal roadmap: kompleksitas tanpa bukti kebutuhan ditolak.

## Konsekuensi

- Satu-satunya mekanisme penganggaran = Batas; Rencana disederhanakan
  menjadi satu segmen.
- Data target lama (tujuan + jadwal) hilang saat migrasi v8; nominal
  setoran tetap terlacak sebagai transaksi.
- "Belanja murni" menjadi definisi tunggal pemakaian di seluruh app:
  pace, streak, donat, tren, kalender, dan alokasi.

# bukuduit

Pencatat keuangan pribadi offline dengan capture notifikasi bank (Android).

## Flutter Hot Reload (proaktif)

Setiap kali mengedit atau membuat file `.dart` di bawah `lib/`:

1. **Kapan skip**:
   - Hanya trigger untuk file di `lib/`. Jangan trigger untuk `test/**`, `integration_test/**`, `benchmark/**`, `test_driver/**`, atau `example/**`.
   - Jangan trigger bila perubahan hanya komentar, docstring, atau whitespace.

2. **Discover & connect**:
   - Cari instance aplikasi yang sedang berjalan lewat tool `dtd` (atau `list_running_apps` / `vm_service`) dari Dart MCP server.

3. **Trigger reload**:
   - `hot_reload` — setelah mengubah widget UI (termasuk `build` method stateful widget) atau method sederhana.
   - `hot_restart` — bila mengubah logika fundamental, inisialisasi state (`initState`), global/static state, atau `main()`.

## Deploy ke HP vivo V2550 (wajib Wi-Fi attach)

OriginOS build `16.0.21.2.W20` (PD2539F_EX) **membunuh transport USB adb saat DDS Flutter terhubung** — `flutter run` via USB selalu gagal dengan `Error connecting to the service protocol ... Connection refused` (terverifikasi 5/5, mati ~340ms setelah forward dibuat). Juga: `am start` diabaikan bila dikirim via adb Wi-Fi, dan dump `logcat` besar via USB memicu pembunuhan transport yang sama.

Workflow yang terbukti jalan (USB tercolok + laptop & HP satu Wi-Fi):

```bash
adb tcpip 5555                          # sekali per sesi USB; IP HP: lihat `adb shell ip -f inet addr show wlan0`
adb connect <IP_HP>:5555
adb shell monkey -p id.xmuu.bukuduit -c android.intent.category.LAUNCHER 1   # launch HARUS via transport USB
flutter attach -d <IP_HP>:5555          # tunnel DDS lewat TCP — aman dari pembunuh USB
```

Catatan:

- Aplikasi ini auto-revive prosesnya via service background (notification listener); instance demikian tidak menjalankan engine Flutter. Kalau `attach` muter di banner VM service lama: `adb shell am force-stop id.xmuu.bukuduit`, lalu `monkey` lagi via USB, baru `attach`.
- Kalau adb USB kacau/wedged: toggle **USB debugging OFF→ON** di Opsi pengembang — itu reset `adbd` satu-satunya yang terbukti.
- Coba ulang `flutter run` USB biasa setiap ada update sistem vivo (regresi ini terlaporkan sembuh via OTA di vivo lain).

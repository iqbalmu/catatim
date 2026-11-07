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

#!/usr/bin/env bash
# ==============================================================================
# CatatIM — Skrip Uji Capture: Injeksi Notifikasi Bank Simulasi
# ==============================================================================
# Mengirim notifikasi simulasi ke device via Android BroadcastReceiver
# tanpa perlu transfer uang asli. Khusus build debug (receiver menolak
# broadcast di build rilis).
#
# Penggunaan:
#   ./scripts/test_capture.sh all                     # Kirim seluruh variasi preset
#   ./scripts/test_capture.sh blu                     # Kirim semua preset blu by BCA
#   ./scripts/test_capture.sh nagari                  # Kirim semua preset Bank Nagari / Ollin
#   ./scripts/test_capture.sh edge                    # Kirim variasi format & nominal
#   ./scripts/test_capture.sh guard                   # Kirim notifikasi negatif (OTP/promo)
#   ./scripts/test_capture.sh send --pkg <p> --title <t> --body <b>  # Custom
# ==============================================================================

set -e

ACTION="id.xmuu.catatim.SIMULATE_NOTIFICATION"
COMPONENT="id.xmuu.catatim/.NotificationSimulatorReceiver"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

check_device() {
  if ! command -v adb &> /dev/null; then
    echo -e "${RED}[ERROR] adb tidak ditemukan di PATH sistem.${NC}"
    exit 1
  fi
  local state
  state=$(adb get-state 2>/dev/null || echo "offline")
  if [ "$state" != "device" ]; then
    echo -e "${YELLOW}[PERINGATAN] Device ADB belum terdeteksi (state: $state).${NC}"
    echo "Pastikan HP/emulator terhubung dan USB/WiFi debugging aktif."
    exit 1
  fi
}

send_notif() {
  local pkg="$1"
  local title="$2"
  local body="$3"

  echo -e "${BLUE}▶ Menembakkan:${NC} [$pkg]"
  echo "  Judul : $title"
  echo "  Isi   : $body"

  adb shell am broadcast \
    -a "$ACTION" \
    -n "$COMPONENT" \
    --es package "$pkg" \
    --es title "$title" \
    --es body "$body" > /dev/null

  echo -e "  ${GREEN}✓ Berhasil terkirim ke antrean device.${NC}\n"
  sleep 0.5
}

test_blu() {
  echo -e "${YELLOW}=== Menguji Preset blu by BCA ===${NC}\n"
  send_notif "com.bcadigital.blu" "blu by BCA" "Penambahan dana blusaving sebesar Rp 150.000 berhasil"
  send_notif "com.bcadigital.blu" "blu" "Transfer masuk dari BUDI SANTOSO sebesar Rp 250.000 berhasil."
  send_notif "com.bcadigital.blu" "blu by BCA" "Kamu menerima uang dari SITI NURHALIZA sebesar Rp 50.000."
  send_notif "com.bcadigital.blu" "blu by BCA" "Transfer ke ANDI WIJAYA sebesar Rp 75.000 berhasil."
  send_notif "com.bcadigital.blu" "blu" "Pembayaran QR di KOPI KENANGAN sebesar Rp 38.000 berhasil"
  send_notif "com.bcadigital.blu" "blu by BCA" "Top up GoPay sebesar Rp 100.000 berhasil."
}

test_nagari() {
  echo -e "${YELLOW}=== Menguji Preset Bank Nagari / Ollin ===${NC}\n"
  send_notif "id.co.banknagari.ollin" "Ollin Bank Nagari" "Kredit masuk sebesar Rp 3.500.000 dari PT MAKMUR JAYA."
  send_notif "id.co.banknagari.ollin" "Ollin Bank Nagari" "Debit sebesar Rp 120.000 a.n. RAHMAD HIDAYAT berhasil diproses."
  send_notif "id.co.banknagari.ollin" "Ollin Bank Nagari" "Pembayaran QRIS sebesar Rp 45.000 di RM PADANG SEDERHANA berhasil."
  send_notif "id.co.banknagari.ollin" "Ollin Bank Nagari" "Top up ShopeePay sebesar Rp 200.000 sukses."
}

test_edge() {
  echo -e "${YELLOW}=== Menguji Variasi Format & Nominal ===${NC}\n"
  send_notif "com.bcadigital.blu" "blu by BCA" "Pembayaran tagihan sebesar Rp 125.500,00 berhasil"
  send_notif "com.bcadigital.blu" "blu" "Transfer masuk dari HENDRA IDR 500.000 berhasil."
  send_notif "id.co.banknagari.ollin" "Ollin Bank Nagari" "Pembayaran QRIS Rp85.000 berhasil diproses."
}

test_guard() {
  echo -e "${YELLOW}=== Menguji Guard Non-Finansial (Negatif Tests) ===${NC}\n"
  send_notif "com.bcadigital.blu" "blu by BCA" "JANGAN BERIKAN KODE OTP 948210 kepada siapa pun termasuk pihak bank."
  send_notif "com.bcadigital.blu" "blu by BCA" "Dapatkan cashback belanja hingga 50% untuk transaksi di merchant favoritmu!"
}

show_help() {
  echo "CatatIM Capture Notification Injection Tool"
  echo ""
  echo "Perintah:"
  echo "  $0 all                    Menjalankan seluruh variasi preset"
  echo "  $0 blu                    Menjalankan preset blu by BCA"
  echo "  $0 nagari                 Menjalankan preset Bank Nagari / Ollin"
  echo "  $0 edge                   Menjalankan preset variasi format angka"
  echo "  $0 guard                  Menjalankan preset tes non-finansial/OTP"
  echo "  $0 send --pkg <p> --title <t> --body <b>   Kirim notifikasi kustom"
}

MODE="$1"

case "$MODE" in
  all)
    check_device
    test_blu
    test_nagari
    test_edge
    test_guard
    echo -e "${GREEN}★ Seluruh skenario telah selesai ditembakkan!${NC}"
    ;;
  blu)
    check_device
    test_blu
    ;;
  nagari)
    check_device
    test_nagari
    ;;
  edge)
    check_device
    test_edge
    ;;
  guard)
    check_device
    test_guard
    ;;
  send)
    check_device
    shift
    PKG="com.bcadigital.blu"
    TITLE=""
    BODY=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --pkg) PKG="$2"; shift 2 ;;
        --title) TITLE="$2"; shift 2 ;;
        --body) BODY="$2"; shift 2 ;;
        *) echo "Parameter tidak dikenal: $1"; exit 1 ;;
      esac
    done
    if [ -z "$BODY" ]; then
      echo -e "${RED}[ERROR] Parameter --body wajib diisi.${NC}"
      exit 1
    fi
    send_notif "$PKG" "$TITLE" "$BODY"
    ;;
  *)
    show_help
    exit 0
    ;;
esac

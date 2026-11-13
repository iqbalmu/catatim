#!/usr/bin/env python3
"""Bangun docs/mockups/index.html dari mockup Beranda.

Semua mockup digambar dari satu grup fungsi (grid dp yang sama, skala
tipe yang sama, bayangan cushion yang sama) supaya antar mockup bisa
 dibandingkan apples-to-apples. Maskot memakai render 3D asli (duit.png).

Jalankan: python3 docs/mockups/build_mockups.py
"""

from __future__ import annotations

import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent

# Palet app (ADR-010) — light.
BG = "#FBF5EC"
SURFACE = "#FFFDF9"
FG = "#5B4433"
MUTED = "#AD9680"
BORDER = "#EDE0CE"
ACCENT = "#7FBDB1"
ACCENT_TINT = "#E6F2EF"
GOLD_BRIGHT = "#F9DCA8"
GOLD = "#E8B36B"
GOLD_INK = "#C08A3D"
BAD = "#B05530"
BAD_TINT = "#F7E4DA"
C2, C3, C4 = "#E07A5F", "#3D8AA8", "#8A6FBF"

W, H = 360, 780
STATUS_H = 24
NAV_TOP = 696

# ── helper SVG ────────────────────────────────────────────────────────────


class Canvas:
    """Pengumpul elemen SVG. Semua koordinat = dp (1 unit = 1 dp)."""

    def __init__(self, uid: str, w: int = W, h: int = H) -> None:
        self.uid = uid
        self.w = w
        self.h = h
        self.items: list[str] = []

    # bentuk dasar
    def rect(self, x, y, w, h, r=0, fill=None, stroke=None, op=None, sw=1.5):
        a = f'x="{x}" y="{y}" width="{w}" height="{h}"'
        if r:
            a += f' rx="{r}"'
        if fill:
            a += f' fill="{fill}"'
        if stroke:
            a += f' stroke="{stroke}" stroke-width="{sw}"'
        if op is not None:
            a += f' opacity="{op}"'
        self.items.append(f"<rect {a}/>")
        return self

    def circle(self, cx, cy, r, fill=None, stroke=None, sw=1.5, op=None):
        a = f'cx="{cx}" cy="{cy}" r="{r}"'
        if fill:
            a += f' fill="{fill}"'
        if stroke:
            a += f' stroke="{stroke}" stroke-width="{sw}"'
        if op is not None:
            a += f' opacity="{op}"'
        self.items.append(f"<circle {a}/>")
        return self

    def path(self, d, fill=None, stroke=None, sw=1.5, op=None):
        a = f'd="{d}"'
        if fill:
            a += f' fill="{fill}"'
        if stroke:
            a += f' stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"'
        if op is not None:
            a += f' opacity="{op}"'
        self.items.append(f"<path {a}/>")
        return self

    def ellipse(self, cx, cy, rx, ry, fill, op=None):
        a = f'cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{fill}"'
        if op is not None:
            a += f' opacity="{op}"'
        self.items.append(f"<ellipse {a}/>")
        return self

    def linear_grad(self, gid, stops, vertical=True):
        s = "".join(
            f'<stop offset="{o}" stop-color="{c}" stop-opacity="{op}"/>' for o, c, op in stops
        )
        y2 = "1" if vertical else "0"
        self.items.append(
            f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="{y2}">{s}</linearGradient>'
        )
        return self

    def radial_grad(self, gid, stops):
        s = "".join(
            f'<stop offset="{o}" stop-color="{c}" stop-opacity="{op}"/>' for o, c, op in stops
        )
        self.items.append(f'<radialGradient id="{gid}">{s}</radialGradient>')
        return self

    def grad_rect(self, gid, x, y, w, h, r=0):
        a = f'x="{x}" y="{y}" width="{w}" height="{h}"'
        if r:
            a += f' rx="{r}"'
        self.items.append(f'<rect {a} fill="url(#{gid})"/>')
        return self

    def text(self, x, y, s, size=13, weight=400, fill=FG, anchor="start", ls=None, op=None):
        a = (
            f'x="{x}" y="{y}" font-family="Nunito, system-ui, sans-serif" font-size="{size}" '
            f'font-weight="{weight}" fill="{fill}" text-anchor="{anchor}"'
        )
        if ls:
            a += f' letter-spacing="{ls}"'
        if op is not None:
            a += f' opacity="{op}"'
        self.items.append(f"<text {a}>{s}</text>")
        return self

    def image(self, x, y, h, href="duit.png", anchor="left"):
        """Render 3D Duit; tinggi h dp, lebar ikut rasio sumber (179x240)."""
        w = round(h * 179 / 240, 1)
        if anchor == "center":
            x = round(x - w / 2, 1)
        self.items.append(
            f'<image href="{href}" x="{x}" y="{y}" width="{w}" height="{h}" '
            f'preserveAspectRatio="xMidYMid meet"/>'
        )
        return self

    def shadow(self, x, y, w, h, r=22, op=0.12, blur=9, dy=8):
        fid = f"sh-{self.uid}-{len(self.items)}"
        self.items.append(
            f'<filter id="{fid}" x="-30%" y="-30%" width="160%" height="180%">'
            f'<feDropShadow dx="0" dy="{dy}" stdDeviation="{blur}" '
            f'flood-color="#5A4628" flood-opacity="{op}"/></filter>'
        )
        self.items.append(
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="#5A4628" filter="url(#{fid})"/>'
        )
        return self

    def card(self, x, y, w, h, r=22, shadow=True):
        if shadow:
            self.shadow(x, y, w, h, r=r)
        self.rect(x, y, w, h, r=r, fill=SURFACE, stroke=BORDER, sw=1.5)
        return self

    def render(self, title: str) -> str:
        return (
            f'<svg viewBox="0 0 {self.w} {self.h}" width="{self.w}" '
            f'xmlns="http://www.w3.org/2000/svg" role="img" aria-label="{title}">'
            + "".join(self.items)
            + "</svg>"
        )


# ── komponen bersama ──────────────────────────────────────────────────────


def status_bar(c: Canvas) -> None:
    c.text(24, 30, "8:33", size=10, weight=700, fill=MUTED)
    for i, w in enumerate((4, 7, 10)):
        c.rect(300 + i * 6, 22 + (10 - w), 4, w, r=1.5, fill=MUTED, op=0.5)
    c.rect(326, 22, 18, 10, r=2.5, fill=MUTED, op=0.5)


def nav(c: Canvas) -> None:
    c.shadow(16, NAV_TOP, 328, 60, r=24, op=0.16, blur=12, dy=10)
    c.rect(16, NAV_TOP, 328, 60, r=24, fill=SURFACE, stroke=BORDER, sw=1.5)
    for cx, active in ((56, True), (114, False), (246, False), (304, False)):
        c.rect(cx - 9, NAV_TOP + 16, 18, 14, r=5, fill=FG if active else MUTED, op=0.9 if active else 0.55)
    c.circle(180, NAV_TOP - 4, 26, fill=GOLD)



def halo(c: Canvas, cx, cy, r, gid) -> None:
    """Cahaya lembut di belakang karakter — panggung tanpa kartu."""
    c.radial_grad(gid, [(0, GOLD_BRIGHT, 0.95), (0.58, GOLD_BRIGHT, 0.5), (1, GOLD_BRIGHT, 0)])
    c.circle(cx, cy, r, fill=f"url(#{gid})")


def ground(c: Canvas, cx, y, w) -> None:
    """Bayangan tanah di bawah kaki karakter."""
    c.ellipse(cx, y, w / 2, w / 16, "#3E2214", 0.16)


def avatar_row(c: Canvas, cx, y, gap=24) -> None:
    """Deretan avatar akun, terpusat di titik cx."""
    for i, col in enumerate((C2, C3, C4)):
        c.circle(cx - 26 + i * gap, y, 11, fill=col, op=0.85)
    c.text(cx + 34, y + 4, "+1", size=11, weight=800, fill=MUTED, anchor="middle")




def t3_top(c: Canvas, caption="Duit tenang — masih dalam batas hari ini") -> None:
    """Bagian atas yang sama untuk semua variasi T3: ruang hangat + karakter di tengah."""
    status_bar(c)
    c.text(24, 60, "CatatIn", size=13, weight=800)
    c.circle(296, 54, 15, stroke=BORDER, sw=1.6)
    c.circle(330, 54, 15, stroke=BORDER, sw=1.6)
    c.circle(300, 47, 4, fill=BAD)

    c.linear_grad("bg", [(0, GOLD_BRIGHT, 0.85), (0.62, GOLD_BRIGHT, 0.35), (1, GOLD_BRIGHT, 0)])
    c.grad_rect("bg", 16, 76, 328, 244, r=24)
    halo(c, 180, 164, 106, "h")
    c.image(180, 84, 172, anchor="center")
    ground(c, 180, 258, 86)
    c.text(180, 278, caption, size=12, weight=700, fill=GOLD_INK, anchor="middle")



def pace_card(c: Canvas, y=416, x=16, w=328) -> None:
    h = 108
    c.card(x, y, w, h)
    c.text(x + 16, y + 26, "SISA AMAN HARI INI", size=10, weight=800, fill=MUTED, ls=1.5)
    c.rect(x + w - 62, y + 14, 46, 20, r=10, fill=ACCENT_TINT)
    c.text(x + w - 54, y + 28, "5 hari", size=11, weight=800, fill="#3E7A6D")
    c.text(x + 16, y + 60, "Rp50.000", size=26, weight=800)
    c.rect(x + 16, y + 72, w - 32, 10, r=5, fill=BORDER)
    c.rect(x + 16, y + 72, (w - 32) * 0.34, 10, r=5, fill=GOLD)
    c.text(x + 16, y + 96, "Pakai Rp0 dari Rp50.000", size=11, weight=600, fill=MUTED)


def tile(c: Canvas, x, y, w, h, label, value, sub=None, bar=False) -> None:
    """Kotak angka kecil."""
    c.card(x, y, w, h)
    c.text(x + 14, y + 24, label, size=10, weight=800, fill=MUTED, ls=1.2)
    c.text(x + 14, y + 54, value, size=20, weight=800)
    if sub:
        c.text(x + 14, y + 74, sub, size=11, weight=600, fill=MUTED)
    if bar:
        c.rect(x + 14, y + 84, w - 28, 6, r=3, fill=BORDER)
        c.rect(x + 14, y + 84, (w - 28) * 0.34, 6, r=3, fill=GOLD)


def variant_t3() -> str:
    """T3 — Karakter di tengah atas (ruang hangat), kartu saldo menempel."""
    c = Canvas("t3")
    t3_top(c)
    c.card(26, 286, 308, 98)
    c.text(180, 312, "Saldo", size=11, weight=700, fill=MUTED, anchor="middle")
    c.text(180, 348, "Rp4.922.000", size=30, weight=800, anchor="middle")
    avatar_row(c, 180, 372)
    pace_card(c, y=400)
    transaksi_card(c, y=516, n=2)
    nav(c)
    return c.render("Mockup T3: karakter di tengah atas, kartu saldo menempel")


def money_card(c: Canvas, x=16, y=292, w=328, h=140) -> None:
    """Kartu angka uang: label kiri, nilai kanan — satu grid, satu ide."""
    c.card(x, y, w, h)
    c.text(x + 16, y + 28, "Saldo", size=11, weight=700, fill=MUTED)
    c.text(x + w - 16, y + 36, "Rp4.922.000", size=28, weight=800, anchor="end")
    c.path(f"M{x + 16} {y + 50} h{w - 32}", stroke=BORDER, sw=1)
    c.text(x + 16, y + 76, "SISA AMAN HARI INI", size=10, weight=800, fill=MUTED, ls=1.5)
    c.rect(x + 150, y + 62, 46, 20, r=10, fill=ACCENT_TINT)
    c.text(x + 156, y + 76, "5 hari", size=11, weight=800, fill="#3E7A6D")
    c.text(x + w - 16, y + 84, "Rp50.000", size=22, weight=800, anchor="end")
    c.rect(x + 16, y + 94, w - 32, 10, r=5, fill=BORDER)
    c.rect(x + 16, y + 94, (w - 32) * 0.34, 10, r=5, fill=GOLD)
    c.text(x + 16, y + 124, "Terpakai Rp0", size=11, weight=600, fill=MUTED)
    c.rect(x + w - 196, y + 112, 92, 20, r=10, fill=BG)
    c.text(x + w - 190, y + 126, "Mingguan 300rb", size=11, weight=700, fill=MUTED)
    c.rect(x + w - 100, y + 112, 84, 20, r=10, fill=BG)
    c.text(x + w - 94, y + 126, "Bulanan 327rb", size=11, weight=700, fill=MUTED)


def arus_card(c: Canvas, x=16, y=448, w=328, h=104) -> None:
    """Arus bulan berjalan: keluar | masuk, dua kolom dengan pembatas."""
    c.card(x, y, w, h)
    c.text(x + 16, y + 26, "ARUS BULAN INI", size=10, weight=800, fill=MUTED, ls=1.5)
    mid = x + (w - 16) / 2
    c.path(f"M{mid - 8} {y + 42} v42", stroke=BORDER, sw=1)
    c.text(x + 16, y + 58, "Keluar", size=11, weight=700, fill=MUTED)
    c.text(x + 16, y + 88, "Rp327.000", size=22, weight=800, fill=BAD)
    c.text(mid + 8, y + 58, "Masuk", size=11, weight=700, fill=MUTED)
    c.text(mid + 8, y + 88, "Rp2.000", size=22, weight=800, fill="#4A8C7E")


def insight_strip(c: Canvas, x=16, y=568, w=328, h=88) -> None:
    """Ringkasan 7 hari: batang mingguan + tiga kategori teratas."""
    c.card(x, y, w, h)
    c.text(x + 16, y + 26, "7 HARI TERAKHIR", size=10, weight=800, fill=MUTED, ls=1.5)
    c.text(x + w - 16, y + 26, "keluar terbesar Warung 82rb", size=11, weight=700, fill=MUTED, anchor="end")
    for i, hgt in enumerate((18, 26, 14, 32, 22, 28, 20)):
        c.rect(x + 16 + i * 20, y + 70 - hgt, 12, hgt, r=4, fill=GOLD, op=0.55)
    for i, col in enumerate((C2, C3, C4)):
        c.circle(x + w - 66 + i * 22, y + 58, 9, fill=col, op=0.85)


def variant_l1() -> str:
    """L1 — Papan angka: satu kartu uang, satu kartu arus, insight, transaksi."""
    c = Canvas("l1")
    t3_top(c)
    money_card(c, y=292)
    arus_card(c, y=448)
    insight_strip(c, y=568)
    transaksi_card(c, y=672, n=2)
    nav(c)
    return c.render("Mockup L1: papan angka di bawah maskot")


def variant_l2() -> str:
    """L2 — Saldo jadi display; kartu batas, arus, insight, transaksi terpisah."""
    c = Canvas("l2")
    t3_top(c)
    c.text(180, 296, "Saldo", size=11, weight=700, fill=MUTED, anchor="middle")
    c.text(180, 340, "Rp4.922.000", size=34, weight=800, anchor="middle")
    avatar_row(c, 180, 366)
    pace_card(c, y=394)
    arus_card(c, y=518)
    insight_strip(c, y=638)
    transaksi_card(c, y=742, n=2)
    nav(c)
    return c.render("Mockup L2: saldo display lalu kartu-kartu terpisah")


def variant_l3() -> str:
    """L3 — Grid angka: dua kotak ringkas, lalu insight dan daftar."""
    c = Canvas("l3")
    t3_top(c)
    c.text(180, 296, "Saldo", size=11, weight=700, fill=MUTED, anchor="middle")
    c.text(180, 340, "Rp4.922.000", size=34, weight=800, anchor="middle")
    avatar_row(c, 180, 366)
    tile(c, 16, 382, 156, 96, "SISA AMAN HARI INI", "Rp50.000", "Terpakai Rp0", bar=True)
    tile(c, 188, 382, 156, 96, "ARUS BULAN INI", "Rp327rb", "Masuk Rp2rb")
    insight_strip(c, y=494)
    transaksi_card(c, y=598, n=2)
    nav(c)
    return c.render("Mockup L3: grid angka lalu insight dan daftar")





def transaksi_card(c: Canvas, y=530, x=16, w=328, n=3) -> None:
    h = 46 + 34 * (n - 1) + 31
    c.card(x, y, w, h)
    c.text(x + 16, y + 26, "Transaksi Terbaru", size=13, weight=800)
    c.text(x + w - 90, y + 26, "Lihat semua ›", size=11, weight=700, fill=MUTED)
    rows = (
        (ACCENT, "Top up", "+Rp2.000", "#4A8C7E"),
        (BAD_TINT, "Warung Nasi Bu Sri", "−Rp22.000", BAD),
        (BAD_TINT, "Kopi Kenangan", "−Rp18.000", BAD),
    )[:n]
    ry = y + 46
    for i, (col, name, amt, colr) in enumerate(rows):
        c.circle(x + 26, ry + 10, 12, fill=col, op=0.4)
        c.text(x + 48, ry + 15, name, size=13, weight=700)
        c.text(x + w - 16, ry + 15, amt, size=13, weight=800, fill=colr, anchor="end")
        if i < len(rows) - 1:
            c.path(f"M{x + 16} {ry + 30} h{w - 32}", stroke=BORDER, sw=1)
        ry += 34




VARIANTS = [
    {
        "key": "L1",
        "title": "Papan angka",
        "tag": "Kartu uang · kartu arus · insight · transaksi",
        "svgs": [variant_l1],
        "points": [
            "Semua angka penting dalam satu kartu uang: saldo, sisa aman hari ini + bar, mingguan/bulanan, chip streak.",
            "Arus bulan (keluar/masuk) dipisah jadi kartu dua kolom; insight 7 hari jadi strip tipis.",
            "Daftar transaksi penuh tetap ada di bawah — tidak ada info yang hilang.",
        ],
        "spec": "uang 328×140dp · arus 328×104dp · insight 328×88dp · gap 16dp",
    },
    {
        "key": "L2",
        "title": "Saldo display + kartu terpisah",
        "tag": "Angka besar dulu, lalu kartu-kartu kecil",
        "svgs": [variant_l2],
        "points": [
            "Saldo jadi display bebas (34dp, terpusat) supaya langsung terbaca setelah maskot.",
            "Tiap kartu satu ide: batas harian, arus bulan, insight 7 hari, transaksi.",
            "Paling mirip app sekarang, jadi paling gampang dipindahkan ke kode.",
        ],
        "spec": "display 34dp · kartu pace 328×108dp · arus 328×104dp · gap 16dp",
    },
    {
        "key": "L3",
        "title": "Grid angka + daftar",
        "tag": "Dua kotak ringkas, lalu insight dan transaksi",
        "svgs": [variant_l3],
        "points": [
            "Dua kotak angka (sisa hari ini, keluar bulan ini) memberi rujukan cepat tanpa kartu panjang.",
            "Insight 7 hari berupa strip ringkas; transaksi tetap jadi kartu penuh.",
            "Paling padat info per tinggi layar.",
        ],
        "spec": "display 34dp · 2 kotak 156×84dp · insight 328×88dp · gap 16dp",
    },
]

PAGE = """<!doctype html>
<html lang="id">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Mockup Beranda — CatatIn</title>
<style>
  :root {{
    --bg: {bg}; --surface: {surface}; --fg: {fg}; --muted: {muted};
    --border: {border}; --accent: {accent}; --c1: {c1}; --gold-ink: {goldink};
  }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0; background: var(--bg); color: var(--fg);
    font: 15px/1.55 Nunito, system-ui, -apple-system, "Segoe UI", sans-serif;
    padding: 34px 20px 130px;
  }}
  header {{ max-width: 1240px; margin: 0 auto 26px; }}
  h1 {{ font-size: 27px; margin: 0 0 6px; letter-spacing: -0.2px; }}
  .sub {{ color: var(--muted); margin: 0 0 18px; max-width: 74ch; }}
  .who {{ display: inline-flex; align-items: center; gap: 10px; background: var(--surface);
          border: 1px solid var(--border); border-radius: 999px; padding: 6px 16px 6px 8px; }}
  .who img {{ width: 36px; height: 36px; object-fit: contain; }}
  .who span {{ font-size: 13px; color: var(--muted); }}
  .grid {{ max-width: 1240px; margin: 0 auto; display: grid; gap: 24px;
           grid-template-columns: repeat(auto-fit, minmax(430px, 1fr)); }}
  .card {{ background: var(--surface); border: 1px solid var(--border); border-radius: 22px;
           padding: 20px; box-shadow: 0 8px 18px rgba(90,70,40,.09), inset 0 2px 0 rgba(255,255,255,.9);
           display: flex; flex-direction: column; }}
  .head {{ display: flex; align-items: baseline; gap: 10px; flex-wrap: wrap; }}
  .key {{ background: var(--c1); color: var(--gold-ink); border-radius: 999px;
          padding: 3px 12px; font-weight: 800; font-size: 13px; }}
  .card h2 {{ font-size: 18px; margin: 0; }}
  .tag {{ color: var(--muted); font-size: 13px; margin: 2px 0 14px; }}
  .frames {{ display: flex; gap: 14px; justify-content: center; align-items: flex-start;
             background: var(--bg); border-radius: 20px; padding: 12px; }}
  .frames svg {{ width: 100%; max-width: 320px; height: auto; display: block; }}
  ul {{ padding-left: 18px; margin: 14px 0 6px; font-size: 13.5px; }}
  li {{ margin: 4px 0; }}
  .spec {{ color: var(--muted); font-size: 12.5px; font-weight: 700; margin: 6px 0 14px; }}
  .pick {{ margin-top: auto; border: 0; border-radius: 999px; padding: 13px 18px; font: inherit;
          font-weight: 800; cursor: pointer; background: var(--c1); color: var(--gold-ink); }}
  .pick[aria-pressed="true"] {{ outline: 3px solid var(--accent); outline-offset: 2px; }}
  .bar {{ position: fixed; left: 50%; transform: translateX(-50%); bottom: 18px; z-index: 9;
          background: var(--surface); border: 1px solid var(--border); border-radius: 999px;
          box-shadow: 0 12px 28px rgba(90,65,30,.20); padding: 10px 12px 10px 20px;
          display: flex; gap: 14px; align-items: center; font-size: 13.5px; }}
  .bar button {{ border: 0; border-radius: 999px; padding: 10px 18px; font: inherit; font-weight: 800;
                 cursor: pointer; background: var(--c1); color: var(--gold-ink); }}
  .hint {{ color: var(--muted); }}
</style>
</head>
<body>
<header>
  <h1>Mockup Beranda — panggung Duit</h1>
  <p class="sub">Empat variasi dari arah yang kamu suka (A), digambar dengan skala dp dan tipografi
  yang sama persis dengan app supaya mudah dibandingkan. Klik <b>Pilih ini</b>, lalu <b>Salin pilihan</b>.</p>
  <span class="who"><img src="duit.png" alt="Duit"><span>render 3D asli yang dipakai di semua mockup</span></span>
</header>
<div class="grid">
{cards}
</div>
<div class="bar">
  <span id="state">Belum ada pilihan</span>
  <button id="copy">Salin pilihan</button>
  <span class="hint" id="hint"></span>
</div>
<script>
  const buttons = [...document.querySelectorAll('.pick')];
  const state = document.getElementById('state');
  const hint = document.getElementById('hint');
  let picked = null;
  buttons.forEach((b) => b.addEventListener('click', () => {{
    picked = b.dataset.pick;
    buttons.forEach((x) => x.setAttribute('aria-pressed', String(x === b)));
    state.textContent = 'Pilihan: ' + picked;
    hint.textContent = 'tekan Salin pilihan';
  }}));
  document.getElementById('copy').addEventListener('click', async () => {{
    const text = picked ? 'Pilih mockup ' + picked : 'Belum memilih mockup';
    try {{ await navigator.clipboard.writeText(text); hint.textContent = 'tersalin: ' + text; }}
    catch (e) {{ hint.textContent = text; }}
  }});
</script>
</body>
</html>
"""


def main() -> None:
    cards = []
    for v in VARIANTS:
        svgs = "\n".join(fn() if callable(fn) else fn for fn in v["svgs"])
        points = "\n".join(f"<li>{p}</li>" for p in v["points"])
        cards.append(
            f"""  <section class="card">
    <div class="head"><span class="key">{v['key']}</span><h2>{v['title']}</h2></div>
    <p class="tag">{v['tag']}</p>
    <div class="frames">{svgs}</div>
    <ul>
{points}
    </ul>
    <p class="spec">{v['spec']}</p>
    <button class="pick" data-pick="{v['key']} — {v['title']}" aria-pressed="false">Pilih ini</button>
  </section>"""
        )

    page = PAGE.format(
        bg=BG,
        surface=SURFACE,
        fg=FG,
        muted=MUTED,
        border=BORDER,
        accent=ACCENT,
        c1=GOLD,
        goldink=GOLD_INK,
        cards="\n".join(cards),
    )
    (ROOT / "index.html").write_text(page)
    print("wrote", ROOT / "index.html")


if __name__ == "__main__":
    main()

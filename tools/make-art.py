#!/usr/bin/env python3
"""Gera a arte original da DadarecoOS (logo e papel de parede) sem dependências.

Uso: python3 tools/make-art.py   (regrava os PNG dentro de config/includes.chroot)
"""
import math, random, struct, zlib, os

OUT_WALL = "config/includes.chroot/usr/share/backgrounds/dadarecoos/default.png"
OUT_LOGO = "config/includes.chroot/usr/share/pixmaps/dadarecoos.png"
OUT_CALA = "config/includes.chroot/etc/calamares/branding/dadarecoos/logo.png"


def png(path, w, h, rows, alpha=False):
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    raw = b"".join(b"\x00" + r for r in rows)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6 if alpha else 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def wallpaper(w=1920, h=1080):
    rnd = random.Random(7)
    top, bottom = (28, 26, 46), (58, 44, 92)            # noite -> violeta
    blobs = [(0.78, 0.30, 0.55, (180, 167, 245)),        # lavanda
             (0.20, 0.85, 0.60, (245, 160, 190)),        # rosa
             (0.55, 1.05, 0.45, (120, 190, 240))]        # azul
    rows = []
    for y in range(h):
        row = bytearray()
        v = y / h
        for x in range(w):
            u = x / w
            c = mix(top, bottom, v)
            for bx, by, br, bc in blobs:
                d = math.hypot((u - bx) * w / h, v - by) / br
                if d < 1:
                    c = mix(c, bc, 0.42 * (1 - d) ** 2)
            n = rnd.random() * 2 - 1                      # ruído contra faixas
            row += bytes(max(0, min(255, int(k + n))) for k in c)
        rows.append(bytes(row))
    png(OUT_WALL, w, h, rows)


def logo(s=256):
    # Quadrado arredondado em degradê com um anel aberto e um ponto: um "d" abstrato.
    def cover(d):                                         # antialias por distância
        return max(0.0, min(1.0, 0.5 - d))
    r_box, half = s * 0.22, s * 0.46
    cx = cy = s / 2
    rows = []
    for y in range(s):
        row = bytearray()
        for x in range(s):
            px, py = x + 0.5 - cx, y + 0.5 - cy
            qx, qy = abs(px) - (half - r_box), abs(py) - (half - r_box)
            d_box = math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - r_box
            a = cover(d_box)
            col = mix((180, 167, 245), (245, 160, 190), (x + y) / (2 * s))
            ring = abs(math.hypot(px + s * 0.04, py - s * 0.06) - s * 0.17) - s * 0.045
            stem_x, stem_y = abs(px - s * 0.175) - s * 0.045, abs(py + s * 0.03) - s * 0.25
            stem = math.hypot(max(stem_x, 0), max(stem_y, 0)) + min(max(stem_x, stem_y), 0)
            wht = max(cover(ring), cover(stem))
            col = mix(col, (255, 255, 255), wht)
            row += bytes(int(k) for k in col) + bytes([int(a * 255)])
        rows.append(bytes(row))
    png(OUT_LOGO, s, s, rows, alpha=True)
    png(OUT_CALA, s, s, rows, alpha=True)


if __name__ == "__main__":
    logo()
    wallpaper()
    print("ok")

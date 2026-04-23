#!/usr/bin/env python3
"""Emit 1024x1024 RGBA PNG: sky, sun, clouds, paper plane (for App Store icon)."""
import math
import struct
import zlib
from pathlib import Path

W = H = 1024


def png_chunk(chunk_type: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + chunk_type + data + struct.pack(">I", zlib.crc32(chunk_type + data) & 0xFFFFFFFF)


def blend(bg: tuple[int, int, int, int], fg: tuple[int, int, int, int], a: float) -> tuple[int, int, int, int]:
    br, bg_, bb, ba = bg
    fr, fg, fb, fa = fg
    t = a * fa / 255.0
    if t >= 1:
        return fr, fg, fb, 255
    return (
        int(br * (1 - t) + fr * t),
        int(bg_ * (1 - t) + fg * t),
        int(bb * (1 - t) + fb * t),
        255,
    )


def point_in_tri(px: float, py: float, ax: float, ay: float, bx: float, by: float, cx: float, cy: float) -> bool:
    def sign(px_, py_, ax_, ay_, bx_, by_):
        return (px_ - bx_) * (ay_ - by_) - (ax_ - bx_) * (py_ - by_)

    d1 = sign(px, py, ax, ay, bx, by)
    d2 = sign(px, py, bx, by, cx, cy)
    d3 = sign(px, py, cx, cy, ax, ay)
    has_neg = d1 < 0 or d2 < 0 or d3 < 0
    has_pos = d1 > 0 or d2 > 0 or d3 > 0
    return not (has_neg and has_pos)


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    app_out = root / "PlaneLaunchTycoon" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon-1024.png"
    tab_dir = root / "PlaneLaunchTycoon" / "Assets.xcassets" / "SoaringPlaneTab.imageset"
    tab_out = tab_dir / "SoaringPlaneTab.png"
    app_out.parent.mkdir(parents=True, exist_ok=True)
    tab_dir.mkdir(parents=True, exist_ok=True)

    # Pixel buffer RGBA
    pix = [[(0, 0, 0, 0) for _ in range(W)] for _ in range(H)]

    for y in range(H):
        for x in range(W):
            t = y / (H - 1)
            r = int(70 + t * 100)
            g = int(150 + t * 90)
            b = int(235 + t * 20)
            pix[y][x] = (r, g, b, 255)

    def soft_circle(cx: float, cy: float, rad: float, col: tuple[int, int, int, int]):
        for y in range(H):
            for x in range(W):
                d = math.hypot(x - cx, y - cy)
                if d < rad + 40:
                    a = max(0, 1 - (d - rad * 0.3) / (rad * 0.85))
                    if a > 0:
                        pix[y][x] = blend(pix[y][x], col, a)

    # Sun
    soft_circle(820, 200, 95, (255, 230, 120, 200))

    # Clouds
    for cx, cy, rx, ry in [(200, 280, 140, 50), (420, 220, 180, 55), (650, 320, 160, 48)]:
        for y in range(H):
            for x in range(W):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1:
                    pix[y][x] = blend(pix[y][x], (255, 255, 255, 255), 0.55)

    # Paper plane (nose right), center ~ (520, 520)
    ax, ay = 520, 520
    bx, by = 340, 420
    cx, cy = 340, 620
    shadow_dx, shadow_dy = 28, 42
    for y in range(H):
        for x in range(W):
            if point_in_tri(x, y, ax + shadow_dx, ay + shadow_dy, bx + shadow_dx, by + shadow_dy, cx + shadow_dx, cy + shadow_dy):
                pix[y][x] = blend(pix[y][x], (30, 45, 80, 180), 0.4)
            if point_in_tri(x, y, ax, ay, bx, by, cx, cy):
                # fold: upper vs lower half
                mid = (bx + cx) / 2
                if y < ay + (x - mid) * 0.02:
                    pix[y][x] = blend(pix[y][x], (250, 252, 255, 255), 1)
                else:
                    pix[y][x] = blend(pix[y][x], (230, 235, 245, 255), 1)

    # Vignette corners
    for y in range(H):
        for x in range(W):
            vx = abs(x - W / 2) / (W / 2)
            vy = abs(y - H / 2) / (H / 2)
            v = max(vx, vy)
            if v > 0.55:
                dark = min(0.35, (v - 0.55) * 0.9)
                pr, pg, pb, pa = pix[y][x]
                pix[y][x] = (int(pr * (1 - dark)), int(pg * (1 - dark)), int(pb * (1 - dark)), pa)

    def write_png(path: Path, w: int, h: int, get_px):
        raw = bytearray()
        for y in range(h):
            raw.append(0)
            for x in range(w):
                r, g, b, a = get_px(x, y)
                raw.extend((r, g, b, a))
        compressed = zlib.compress(bytes(raw), level=9)
        ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
        png = (
            b"\x89PNG\r\n\x1a\n"
            + png_chunk(b"IHDR", ihdr)
            + png_chunk(b"IDAT", compressed)
            + png_chunk(b"IEND", b"")
        )
        path.write_bytes(png)

    write_png(app_out, W, H, lambda x, y: pix[y][x])

    # Tab icon 180x180 downsample from center crop
    tw = th = 180
    scale = W / tw

    def tab_px(x, y):
        sx = int((x + 0.5) * scale)
        sy = int((y + 0.5) * scale)
        sx = min(W - 1, max(0, sx))
        sy = min(H - 1, max(0, sy))
        return pix[sy][sx]

    write_png(tab_out, tw, th, tab_px)
    print("Wrote", app_out, "and", tab_out)


if __name__ == "__main__":
    main()

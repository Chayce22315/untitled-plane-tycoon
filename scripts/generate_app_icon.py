#!/usr/bin/env python3
"""Emit a minimal 1024x1024 RGBA PNG (no third-party deps)."""
import struct
import zlib
from pathlib import Path

W = H = 1024


def png_chunk(chunk_type: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + chunk_type + data + struct.pack(">I", zlib.crc32(chunk_type + data) & 0xFFFFFFFF)


def main() -> None:
    out = Path(__file__).resolve().parents[1] / "PlaneLaunchTycoon" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon-1024.png"
    out.parent.mkdir(parents=True, exist_ok=True)

    # Sky gradient-ish: simple horizontal bands for speed
    raw = bytearray()
    for y in range(H):
        raw.append(0)  # filter type 0
        for x in range(W):
            t = y / (H - 1)
            r = int(80 + t * 60)
            g = int(140 + t * 80)
            b = int(220 + t * 35)
            raw.extend((r, g, b, 255))

    compressed = zlib.compress(bytes(raw), level=9)
    ihdr = struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", ihdr)
        + png_chunk(b"IDAT", compressed)
        + png_chunk(b"IEND", b"")
    )
    out.write_bytes(png)
    print("Wrote", out)


if __name__ == "__main__":
    main()

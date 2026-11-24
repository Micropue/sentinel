#!/usr/bin/env python3

import struct
import sys
from pathlib import Path


ICON_TYPES = (
    ("icp4", "icon_16x16.png", 16),
    ("icp5", "icon_32x32.png", 32),
    ("ic11", "icon_16x16@2x.png", 32),
    ("ic12", "icon_32x32@2x.png", 64),
    ("ic07", "icon_128x128.png", 128),
    ("ic08", "icon_256x256.png", 256),
    ("ic13", "icon_128x128@2x.png", 256),
    ("ic09", "icon_512x512.png", 512),
    ("ic14", "icon_256x256@2x.png", 512),
    ("ic10", "icon_512x512@2x.png", 1024),
)

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def png_dimensions(path: Path) -> tuple[int, int]:
    payload = path.read_bytes()
    if len(payload) < 24 or not payload.startswith(PNG_SIGNATURE):
        raise SystemExit(f"invalid PNG: {path}")
    return struct.unpack(">II", payload[16:24])


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: generate_icns.py ICONSET_DIR OUTPUT.icns")

    iconset = Path(sys.argv[1])
    output = Path(sys.argv[2])
    chunks = []

    for icon_type, filename, expected_size in ICON_TYPES:
        path = iconset / filename
        width, height = png_dimensions(path)
        if (width, height) != (expected_size, expected_size):
            raise SystemExit(
                f"{icon_type} expects {expected_size}x{expected_size}, "
                f"but {path.name} is {width}x{height}"
            )
        payload = path.read_bytes()
        chunks.append(
            icon_type.encode("ascii")
            + struct.pack(">I", len(payload) + 8)
            + payload
        )

    body = b"".join(chunks)
    output.write_bytes(b"icns" + struct.pack(">I", len(body) + 8) + body)


if __name__ == "__main__":
    main()

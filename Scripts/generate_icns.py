#!/usr/bin/env python3

import struct
import sys
from pathlib import Path


ICON_TYPES = (
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("ic11", "icon_32x32@2x.png"),
    ("ic12", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic13", "icon_128x128@2x.png"),
    ("ic09", "icon_512x512.png"),
    ("ic14", "icon_256x256@2x.png"),
    ("ic10", "icon_512x512@2x.png"),
)


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: generate_icns.py ICONSET_DIR OUTPUT.icns")

    iconset = Path(sys.argv[1])
    output = Path(sys.argv[2])
    chunks = []

    for icon_type, filename in ICON_TYPES:
        payload = (iconset / filename).read_bytes()
        chunks.append(
            icon_type.encode("ascii")
            + struct.pack(">I", len(payload) + 8)
            + payload
        )

    body = b"".join(chunks)
    output.write_bytes(b"icns" + struct.pack(">I", len(body) + 8) + body)


if __name__ == "__main__":
    main()

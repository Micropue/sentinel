#!/usr/bin/env python3

import math
import struct
import sys
import zlib
from pathlib import Path


SIZE = 1024


def clamp(value, minimum=0.0, maximum=1.0):
    return max(minimum, min(maximum, value))


def mix(a, b, amount):
    return tuple(a[index] + (b[index] - a[index]) * amount for index in range(3))


def rounded_box_sdf(x, y, center_x, center_y, half_width, half_height, radius):
    dx = abs(x - center_x) - (half_width - radius)
    dy = abs(y - center_y) - (half_height - radius)
    outside = math.hypot(max(dx, 0.0), max(dy, 0.0))
    inside = min(max(dx, dy), 0.0)
    return outside + inside - radius


def circle_sdf(x, y, center_x, center_y, radius):
    return math.hypot(x - center_x, y - center_y) - radius


def coverage_from_sdf(distance, feather=1.25):
    return clamp(0.5 - distance / feather)


def over(destination, source, alpha):
    destination_alpha = destination[3]
    source_alpha = clamp(alpha)
    output_alpha = source_alpha + destination_alpha * (1.0 - source_alpha)
    if output_alpha <= 0.00001:
        return (0.0, 0.0, 0.0, 0.0)

    rgb = []
    for index in range(3):
        value = (
            source[index] * source_alpha
            + destination[index] * destination_alpha * (1.0 - source_alpha)
        ) / output_alpha
        rgb.append(value)
    return (rgb[0], rgb[1], rgb[2], output_alpha)


def background_color(x, y):
    vertical = clamp(y / SIZE)
    diagonal = clamp((x + y) / (SIZE * 2))
    base = mix((0.027, 0.059, 0.125), (0.055, 0.148, 0.278), diagonal)
    base = mix(base, (0.018, 0.035, 0.085), vertical * 0.42)

    cyan_distance = math.hypot(x - 305, y - 260)
    cyan_amount = math.exp(-(cyan_distance * cyan_distance) / (2 * 290 * 290)) * 0.72
    base = mix(base, (0.12, 0.61, 0.94), cyan_amount)

    violet_distance = math.hypot(x - 770, y - 760)
    violet_amount = math.exp(-(violet_distance * violet_distance) / (2 * 305 * 305)) * 0.58
    base = mix(base, (0.39, 0.23, 0.86), violet_amount)

    top_light = math.exp(-((y - 150) ** 2) / (2 * 180 * 180))
    base = mix(base, (0.64, 0.82, 1.0), top_light * 0.12)
    return base


def lock_color(x, y):
    amount = clamp((y - 360) / 360)
    return mix((1.0, 1.0, 1.0), (0.76, 0.89, 1.0), amount * 0.26)


def render_pixel(x, y):
    px = x + 0.5
    py = y + 0.5
    result = (0.0, 0.0, 0.0, 0.0)

    outer = rounded_box_sdf(px, py, 512, 512, 448, 448, 218)
    glow_alpha = math.exp(-max(outer, 0.0) / 38.0) * 0.20
    if glow_alpha > 0.001:
        result = over(result, (0.055, 0.25, 0.66), glow_alpha)

    background_alpha = coverage_from_sdf(outer)
    if background_alpha > 0.0:
        base = background_color(px, py)
        edge_darkening = clamp(-outer / 80.0) * 0.11
        base = tuple(channel * (1.0 - edge_darkening) for channel in base)
        result = over(result, base, background_alpha)

    border_alpha = math.exp(-(outer * outer) / (2 * 2.25 * 2.25))
    result = over(result, (0.80, 0.93, 1.0), border_alpha * 0.47)

    inner = rounded_box_sdf(px, py, 512, 512, 413, 413, 190)
    inner_alpha = math.exp(-(inner * inner) / (2 * 1.4 * 1.4))
    result = over(result, (1.0, 1.0, 1.0), inner_alpha * 0.20)

    gloss_y = (py - 118) / 274
    if 0.0 <= gloss_y <= 1.0:
        gloss_width = 318 * math.sqrt(max(0.0, 1.0 - ((gloss_y - 0.54) / 0.58) ** 2))
        if gloss_width > 0.0 and abs(px - 512) < gloss_width:
            gloss_alpha = (1.0 - abs(px - 512) / gloss_width) * 0.055
            result = over(result, (1.0, 1.0, 1.0), gloss_alpha)

    shackle_center_y = 470
    shackle_radius = 125
    shackle_thickness = 42
    shackle = abs(circle_sdf(px, py, 512, shackle_center_y, shackle_radius)) - shackle_thickness / 2
    if py <= shackle_center_y + 4:
        lock_shadow = coverage_from_sdf(shackle + 4, feather=16.0)
        result = over(result, (0.005, 0.018, 0.05), lock_shadow * 0.26)

        shackle_coverage = coverage_from_sdf(shackle)
        if shackle_coverage > 0.0:
            vertical_gloss = clamp((510 - py) / 200)
            color = mix((0.82, 0.93, 1.0), (1.0, 1.0, 1.0), vertical_gloss)
            result = over(result, color, shackle_coverage * 0.94)

        shackle_inner = abs(circle_sdf(px, py, 512, shackle_center_y, shackle_radius))
        shackle_edge = math.exp(-((shackle_inner - (shackle_radius - shackle_thickness / 2)) ** 2) / 10.0)
        result = over(result, (1.0, 1.0, 1.0), shackle_edge * 0.32)

    body = rounded_box_sdf(px, py, 512, 603, 178, 126, 56)
    if body < 18:
        lock_shadow = math.exp(-max(body, 0.0) / 17.0) * 0.32
        result = over(result, (0.004, 0.013, 0.035), lock_shadow)

    body_coverage = coverage_from_sdf(body)
    if body_coverage > 0.0:
        color = lock_color(px, py)
        depth = clamp(-body / 126)
        color = tuple(channel * (0.88 + depth * 0.12) for channel in color)
        result = over(result, color, body_coverage * 0.97)

    body_edge = math.exp(-(body * body) / (2 * 1.8 * 1.8))
    result = over(result, (1.0, 1.0, 1.0), body_edge * 0.55)

    highlight = rounded_box_sdf(px, py, 512, 530, 139, 27, 27)
    highlight_alpha = coverage_from_sdf(highlight) * 0.055
    result = over(result, (1.0, 1.0, 1.0), highlight_alpha)

    keyhole_circle = circle_sdf(px, py, 512, 584, 27)
    keyhole_slot = rounded_box_sdf(px, py, 512, 635, 11, 38, 11)
    keyhole = min(keyhole_circle, keyhole_slot)
    keyhole_alpha = coverage_from_sdf(keyhole)
    if keyhole_alpha > 0.0:
        result = over(result, (0.035, 0.105, 0.20), keyhole_alpha * 0.92)

    keyhole_rim = abs(keyhole) - 2.2
    rim_alpha = coverage_from_sdf(keyhole_rim, feather=1.0)
    result = over(result, (0.70, 0.88, 1.0), rim_alpha * 0.26)

    for index in range(6):
        dot_x = 512 + (index - 2.5) * 31
        dot = circle_sdf(px, py, dot_x, 790, 5.3)
        dot_alpha = coverage_from_sdf(dot)
        if dot_alpha > 0.0:
            result = over(result, (0.83, 0.94, 1.0), dot_alpha * 0.58)

    return result


def png_chunk(tag, payload):
    return (
        struct.pack(">I", len(payload))
        + tag
        + payload
        + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
    )


def write_png(path):
    raw = bytearray()
    for y in range(SIZE):
        raw.append(0)
        for x in range(SIZE):
            red, green, blue, alpha = render_pixel(x, y)
            raw.extend(
                (
                    int(round(clamp(red) * 255)),
                    int(round(clamp(green) * 255)),
                    int(round(clamp(blue) * 255)),
                    int(round(clamp(alpha) * 255)),
                )
            )

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", header)
        + png_chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + png_chunk(b"IEND", b"")
    )
    path.write_bytes(png)


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: generate_icon.py OUTPUT.png")

    output = Path(sys.argv[1])
    output.parent.mkdir(parents=True, exist_ok=True)
    write_png(output)


if __name__ == "__main__":
    main()

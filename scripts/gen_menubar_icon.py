#!/usr/bin/env python3
"""
Generate pixel-perfect SmartEnglish menu bar icons.
18x18 (1x) and 36x36 (2x) — no font rendering, fully hand-drawn.
"""
import os
import subprocess
from PIL import Image, ImageDraw

BLUE  = (59, 130, 246, 255)
WHITE = (255, 255, 255, 255)

# "E" pixel map: 10 wide × 12 tall (1x units)
# Designed to center cleanly in 18×18 (4px margin L/R, 3px margin T/B)
E_MAP = [
    [1,1,1,1,1,1,1,1,1,1],  # top bar
    [1,1,1,1,1,1,1,1,1,1],
    [1,1,0,0,0,0,0,0,0,0],  # left stem
    [1,1,0,0,0,0,0,0,0,0],
    [1,1,0,0,0,0,0,0,0,0],
    [1,1,1,1,1,1,1,0,0,0],  # middle bar (7 wide)
    [1,1,1,1,1,1,1,0,0,0],
    [1,1,0,0,0,0,0,0,0,0],  # left stem
    [1,1,0,0,0,0,0,0,0,0],
    [1,1,0,0,0,0,0,0,0,0],
    [1,1,1,1,1,1,1,1,1,1],  # bottom bar
    [1,1,1,1,1,1,1,1,1,1],
]
E_W, E_H = 10, 12
BASE = 18  # logical base size


def draw_icon(size: int) -> Image.Image:
    scale = size // BASE
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Rounded rectangle background (PIL geometry, no font involved)
    radius = 3 * scale
    draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=BLUE)

    # Place "E" pixels (scaled)
    ox = (BASE - E_W) // 2 * scale   # 4 * scale
    oy = (BASE - E_H) // 2 * scale   # 3 * scale
    pixels = img.load()

    for ri, row in enumerate(E_MAP):
        for ci, val in enumerate(row):
            if not val:
                continue
            for dy in range(scale):
                for dx in range(scale):
                    x, y = ox + ci * scale + dx, oy + ri * scale + dy
                    if 0 <= x < size and 0 <= y < size and pixels[x, y][3] > 0:
                        pixels[x, y] = WHITE

    return img


def main():
    out_dir = os.path.join(os.path.dirname(__file__),
                           "..", "SmartEnglish_Icons")
    res_dir = os.path.join(os.path.dirname(__file__),
                           "..", "SmartEnglish", "Resources")

    os.makedirs(out_dir, exist_ok=True)

    icon_1x = draw_icon(18)
    icon_2x = draw_icon(36)

    path_1x = os.path.join(out_dir, "menubar_18x18.png")
    path_2x = os.path.join(out_dir, "menubar_18x18@2x.png")
    icon_1x.save(path_1x)
    icon_2x.save(path_2x)
    print(f"Saved {path_1x}")
    print(f"Saved {path_2x}")

    # Also update Resources/main.png (1x) and Resources/main.tiff (multi-res)
    main_png = os.path.join(res_dir, "main.png")
    icon_1x.save(main_png)
    print(f"Saved {main_png}")

    # Build Retina TIFF using macOS tiffutil
    main_tiff = os.path.join(res_dir, "main.tiff")
    result = subprocess.run(
        ["tiffutil", "-cathidpicheck", path_1x, path_2x, "-out", main_tiff],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        print(f"Saved {main_tiff}  (multi-res Retina TIFF)")
    else:
        print(f"tiffutil failed: {result.stderr}")
        # Fallback: save single-image TIFF
        icon_1x.save(main_tiff)
        print(f"Saved {main_tiff}  (fallback single-res)")


if __name__ == "__main__":
    main()

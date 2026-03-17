#!/usr/bin/env python3
"""Replace white border with pink on the app icon. Run from this directory."""
import os

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Install Pillow: pip install Pillow")
    raise

ICON_PATH = os.path.join(os.path.dirname(__file__), "AppIcon.png")
BORDER_PX = 48   # Width of pink border from each edge
PINK = (233, 28, 140)  # #E91E8C - vibrant pink
# Consider "white" if R,G,B are all above this (0-255)
WHITE_THRESHOLD = 240

def main():
    if not os.path.isfile(ICON_PATH):
        print("AppIcon.png not found in this folder. Add a 1024x1024 AppIcon.png first.")
        return 1
    im = Image.open(ICON_PATH).convert("RGBA")
    w, h = im.size
    pixels = im.load()
    pink_rgba = (*PINK, 255)

    # 1) Replace white/near-white pixels in the border area with pink
    for y in range(h):
        for x in range(w):
            if x < BORDER_PX or x >= w - BORDER_PX or y < BORDER_PX or y >= h - BORDER_PX:
                r, g, b, a = pixels[x, y]
                if r >= WHITE_THRESHOLD and g >= WHITE_THRESHOLD and b >= WHITE_THRESHOLD:
                    pixels[x, y] = pink_rgba

    # 2) Draw solid pink on the outer border so edges are definitely pink
    draw = ImageDraw.Draw(im)
    draw.rectangle([0, 0, w, BORDER_PX], fill=pink_rgba)
    draw.rectangle([0, h - BORDER_PX, w, h], fill=pink_rgba)
    draw.rectangle([0, 0, BORDER_PX, h], fill=pink_rgba)
    draw.rectangle([w - BORDER_PX, 0, w, h], fill=pink_rgba)

    im.save(ICON_PATH, "PNG")
    print("Saved AppIcon.png with pink border (no white).")
    return 0

if __name__ == "__main__":
    exit(main())

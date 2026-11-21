#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成輸入法圖示。

注意：macOS 輸入法選單會將圖示當 **template image**——只用 alpha 做遮罩，
再用系統顏色上色。所以一定要「透明底 + 純黑字形」，
唔可以畫有色底／白字（會變成一個實心方塊）。
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(BASE, "build", "icons")

FONTS = [
    "/System/Library/Fonts/PingFang.ttc",
    "/System/Library/Fonts/STHeiti Medium.ttc",
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
]


def font(size):
    for path in FONTS:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()


def render(px, text="筆"):
    scale = 10
    s = px * scale
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    size = int(s * 0.96)
    f = font(size)
    box = d.textbbox((0, 0), text, font=f)
    w, h = box[2] - box[0], box[3] - box[1]

    # 縮到剛好填滿（留少少邊，16px 都要認得到）
    if w > s * 0.96 or h > s * 0.96:
        ratio = min(s * 0.96 / max(w, 1), s * 0.96 / max(h, 1))
        f = font(int(size * ratio))
        box = d.textbbox((0, 0), text, font=f)
        w, h = box[2] - box[0], box[3] - box[1]

    d.text(((s - w) / 2 - box[0], (s - h) / 2 - box[1]), text,
           font=f, fill=(0, 0, 0, 255))

    return img.resize((px, px), Image.LANCZOS)


def save_tiff(name, sizes=(16, 32)):
    frames = [render(n) for n in sizes]
    path = os.path.join(OUT, name + ".tiff")
    frames[-1].save(path, format="TIFF", save_all=True, append_images=frames[:-1])
    frames[-1].save(os.path.join(OUT, name + ".png"))
    print("  %s.tiff (%s)" % (name, "+".join(str(n) for n in sizes)))


def main():
    os.makedirs(OUT, exist_ok=True)
    for name in ("menu", "palette", "icon"):
        save_tiff(name)
    return 0


if __name__ == "__main__":
    sys.exit(main())

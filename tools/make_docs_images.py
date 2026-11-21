#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
產生 README 用嘅示意圖。

刻意用同 CandidateCanvas.swift 一樣嘅尺寸／顏色／字型比例，
所以出嚟嘅樣同實際輸入法一致（唔係求其畫）。
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(BASE, "docs")

SCALE = 2
FONT_SIZE = 24
CELL_W = FONT_SIZE + 18
CELL_H = FONT_SIZE + 22
PAD = 6

FONT_CANDIDATES = [
    "/System/Library/Fonts/STHeiti Medium.ttc",
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/System/Library/Fonts/PingFang.ttc",
]


def font(size):
    for p in FONT_CANDIDATES:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                continue
    return ImageFont.load_default()


def bar(chars, keys, selected=0, page="2/7", has_prev=False, has_next=True):
    """畫候選窗，回傳 RGBA image"""
    n = len(chars)
    w = PAD * 2 + n * CELL_W + 34 + (26 if has_prev else 0)
    h = CELL_H + 8
    img = Image.new("RGBA", (w * SCALE, h * SCALE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def S(v):
        return int(v * SCALE)

    # 背景
    d.rounded_rectangle([S(0.5), S(0.5), S(w) - S(0.5), S(h) - S(0.5)],
                        radius=S(9), fill=(253, 253, 253, 250),
                        outline=(189, 189, 189, 255), width=max(1, S(0.7)))

    x = PAD + (26 if has_prev else 0)
    cf = font(int(FONT_SIZE * SCALE))
    kf = font(int(max(9, FONT_SIZE * 0.40) * SCALE))
    pf = font(int(max(8, FONT_SIZE * 0.34) * SCALE))
    nf = font(int(max(9, FONT_SIZE * 0.42) * SCALE))

    if has_prev:
        d.text((S(PAD + 6), S(12)), "◀", font=nf, fill=(115, 115, 115))
        d.text((S(PAD + 7), S(30)), "y", font=nf, fill=(115, 115, 115))

    for i, ch in enumerate(chars):
        cx, cy = x + i * CELL_W, 4
        if i == selected:
            d.rounded_rectangle([S(cx), S(cy), S(cx + CELL_W - 2), S(cy + CELL_H - 2)],
                                radius=S(6), fill=(10, 132, 255, 224))
        colour = (255, 255, 255) if i == selected else (26, 26, 26)
        bb = d.textbbox((0, 0), ch, font=cf)
        tw, th = bb[2] - bb[0], bb[3] - bb[1]
        d.text((S(cx + (CELL_W - 2) / 2) - tw // 2 - S(bb[0] / SCALE),
                S(cy + (CELL_H - 2) / 2) - th // 2 - S(bb[1] / SCALE) + S(2)),
               ch, font=cf, fill=colour)
        d.text((S(cx + 4), S(cy + 1)), keys[i], font=kf,
               fill=(255, 255, 255) if i == selected else (140, 140, 140))

    infox = x + n * CELL_W + 2
    if page:
        bb = d.textbbox((0, 0), page, font=pf)
        d.text((S(infox + 15) - (bb[2] - bb[0]) // 2, S(3)), page, font=pf,
               fill=(115, 115, 115))
    if has_next:
        d.text((S(infox + 10), S(19)), "▶", font=nf, fill=(115, 115, 115))
        d.text((S(infox + 12), S(35)), "n", font=nf, fill=(115, 115, 115))

    return img


def doc(width, height, text_lines, bars, scale=SCALE):
    """文件背景 + 文字 + 貼上候選窗"""
    img = Image.new("RGBA", (width * scale, height * scale), (255, 255, 255, 255))
    d = ImageDraw.Draw(img)
    f = font(int(26 * scale))
    y = 26 * scale
    for line in text_lines:
        d.text((30 * scale, y), line, font=f, fill=(28, 28, 30))
        y += 44 * scale

    for b, bx, by in bars:
        img.alpha_composite(b, (int(bx * scale), int(by * scale)))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    keys10 = list("qwertzxcvb")

    # 1. 打緊字：預輸入 + 候選
    composing = bar(list("中由同衕跟路雖跑世且"), keys10, selected=0,
                    page="1/9", has_prev=False, has_next=True)
    img1 = doc(580, 190,
               ["打「中」：s g a s  →  丨乛一丨"],
               [(composing, 24, 100)])
    img1.save(os.path.join(OUT, "screenshot-composing.png"))

    # 2. 聯想
    sug = bar(list("國心央學間部共原華期"), keys10, selected=-1,
              page="聯", has_prev=False, has_next=False)
    img2 = doc(580, 190,
               ["打完「中」→ 自動建議下一個字"],
               [(sug, 24, 100)])
    img2.save(os.path.join(OUT, "screenshot-suggestion.png"))
    print("已生成 docs/screenshot-composing.png 同 docs/screenshot-suggestion.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())

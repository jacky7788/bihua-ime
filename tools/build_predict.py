#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
由 jieba 詞典抽出「字 -> 下一個字」嘅聯想表。

做法：所有兩字詞（例如「我們」「時候」）就係一條 a->b 嘅轉移，
      權重 = 該詞喺語料嘅出現次數。再轉成繁體輸出。
"""

import json
import os
import sys
from collections import defaultdict

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(BASE, "data")
BUILD = os.path.join(BASE, "build")

# jieba 詞典路徑：可以喺 command line 傳入，或者裝好 jieba 之後用預設位置
DEFAULT_DICT = "/tmp/jb/jieba/dict.txt"
DICT = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("JIEBA_DICT", DEFAULT_DICT)
TOP_PER_CHAR = 12
MIN_WEIGHT = 60


def load_st(path):
    st = {}
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            p = line.split("\t")
            if len(p) < 2:
                continue
            vals = [v for v in p[1].split(" ") if v]
            if len(p[0]) == 1 and vals:
                st[p[0]] = vals
    return st


def is_cjk(ch):
    return 0x3400 <= ord(ch) <= 0x9FFF or 0xF900 <= ord(ch) <= 0xFAFF


def main():
    if not os.path.exists(DICT):
        print("搵唔到 jieba dict.txt")
        return 1

    st = load_st(os.path.join(DATA, "STCharacters.txt"))
    prim = {}

    def trad(ch):
        if ch in prim:
            return prim[ch]
        vals = st.get(ch)
        out = vals[0] if vals else ch
        prim[ch] = out
        return out

    weight = defaultdict(int)
    pairs = 0
    with open(DICT, "r", encoding="utf-8") as f:
        for line in f:
            parts = line.split()
            if len(parts) < 2:
                continue
            w = parts[0]
            if len(w) != 2:
                continue
            a, b = w[0], w[1]
            if not (is_cjk(a) and is_cjk(b)):
                continue
            try:
                fq = int(parts[1])
            except ValueError:
                continue
            if fq < 2:
                continue
            weight[(trad(a), trad(b))] += fq
            pairs += 1

    print("兩字詞 %d，轉移 %d 條" % (pairs, len(weight)))

    table = defaultdict(list)
    for (a, b), w in weight.items():
        if w >= MIN_WEIGHT:
            table[a].append((w, b))

    out = {}
    for a, lst in table.items():
        lst.sort(key=lambda x: (-x[0], x[1]))
        out[a] = [b for _, b in lst[:TOP_PER_CHAR]]

    total = sum(len(v) for v in out.values())
    print("聯想：%d 個起首字，%d 條" % (len(out), total))

    payload = {"version": 1, "note": "字 -> 下一個字（按語料次數）", "map": out}
    path = os.path.join(BUILD, "predict.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, separators=(",", ":"))
    print("寫出 %s (%.1f KB)" % (path, os.path.getsize(path) / 1024.0))

    for probe in ("中", "我", "你", "好", "時", "不"):
        print("  %s → %s" % (probe, "".join(out.get(probe, [])[:8])))
    return 0


if __name__ == "__main__":
    sys.exit(main())

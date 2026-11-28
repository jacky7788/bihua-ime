#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
建立五筆畫編碼表（v2）。

資料來源：
  data/cnchar-5stroke.json  官方筆順名稱 -> 五筆碼（6939 個簡體/通用字）
  data/STCharacters.txt     OpenCC 簡 -> 繁對照

規則：用「簡體字嘅筆順」做索引，輸出「繁體字」。
"""

import json
import os
import sys
from collections import defaultdict

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(BASE, "data")
BUILD = os.path.join(BASE, "build")

# 五筆碼 -> 顯示用符號（預輸入顯示）
SYMBOLS = {"1": "一", "2": "丨", "3": "丿", "4": "丶", "5": "乛"}


def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def load_table(path):
    """OpenCC 對照表：key -> [value...]"""
    out = {}
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) < 2:
                continue
            key = parts[0].strip()
            vals = [v for v in parts[1].split(" ") if v]
            if len(key) == 1 and vals:
                out[key] = vals
    return out


def is_cjk_basic(ch):
    return 0x4E00 <= ord(ch) <= 0x9FFF


def load_freq():
    path = os.path.join(DATA, "char-freq.json")
    if not os.path.exists(path):
        return {}
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def gb_level(ch):
    """0 = GB2312 一級字（最常用），1 = 二級，2 = 唔喺 GB2312"""
    try:
        b = ch.encode("gb2312")
    except UnicodeEncodeError:
        return 2
    if len(b) != 2:
        return 2
    if 0xB0 <= b[0] <= 0xD7:
        return 0
    return 1


def main():
    os.makedirs(BUILD, exist_ok=True)
    stroke = load_json(os.path.join(DATA, "cnchar-5stroke.json"))
    st = load_table(os.path.join(DATA, "STCharacters.txt"))
    freq = load_freq()
    ts_path = os.path.join(DATA, "TSCharacters.txt")
    ts = load_table(ts_path) if os.path.exists(ts_path) else {}
    print("字頻: %d 個" % len(freq))
    print("筆順字數: %d  簡繁條目: %d" % (len(stroke), len(st)))

    table = defaultdict(list)
    produced = set()

    for simp, code in stroke.items():
        f = freq.get(simp, 0)
        if simp in st:
            for i, trad in enumerate(st[simp]):
                table[code].append((f, 0 if i == 0 else 1, gb_level(trad), trad))
                produced.add(trad)
        else:
            table[code].append((f, 0, gb_level(simp), simp))
            produced.add(simp)

    # 異體補充：OpenCC 嘅 ST 表每組只出一個寫法（为→爲），但「為」一樣常用。
    # 用反向表（繁→簡）補齊：任何繁體字，只要佢嘅簡體來源有碼，就用同一個碼。
    variant = 0
    skipped = 0
    for t, simps in ts.items():
        if t in produced:
            continue
        if not is_cjk_basic(t):
            skipped += 1
            continue
        for simp in simps:
            if simp in stroke:
                table[stroke[simp]].append((freq.get(simp, 0), 2, gb_level(t), t))
                produced.add(t)
                variant += 1
                break
    print("異體補充: %d 個（另有 %d 個非基本區，略過）" % (variant, skipped))

    # 排序：主要繁體寫法 -> 常用字 -> 碼位
    entries = []
    freq_of = {}
    for code, lst in table.items():
        best = {}
        for f, rank, gb, ch in lst:
            key = (f, rank, gb)
            if ch not in best or key > best[ch]:
                best[ch] = key
        # 常見度優先（高到低），再主要繁體寫法、GB 級別、碼位
        ordered = sorted(best.items(), key=lambda kv: (-kv[1][0], kv[1][1], kv[1][2], kv[0]))
        entries.append((code, [ch for ch, _ in ordered]))
        for ch, key in best.items():
            freq_of[ch] = key[0]

    entries.sort(key=lambda e: (len(e[0]), e[0]))

    pairs = sum(len(v) for _, v in entries)
    print("碼數: %d  可輸出字: %d  組合: %d" % (len(entries), len(produced), pairs))

    # 覆蓋率檢查：OpenCC 所有繁體目標字
    all_trad = set()
    for vals in st.values():
        all_trad.update(vals)
    missing = sorted(t for t in all_trad if t not in produced)
    print("繁體目標字: %d，未覆蓋: %d" % (len(all_trad), len(missing)))
    if missing:
        print("  例子:", "".join(missing[:40]))

    # 單字/短碼檢查
    for probe in ("2512", "34", "134", "551", "3121534"):
        print("  %s -> %s" % (probe, "".join(next((v for c, v in entries if c == probe), []))))

    payload = {
        "version": 2,
        "source": "cnchar-order (筆順名稱) + OpenCC STCharacters",
        "note": "以簡體筆順編碼，輸出繁體字",
        "symbols": SYMBOLS,
        "entries": [[c, "".join(chars)] for c, chars in entries],
        "freq": [[freq_of.get(ch, 0) for ch in chars] for _, chars in entries],
    }
    out = os.path.join(BUILD, "codes.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, separators=(",", ":"))
    print("寫出 %s  (%.1f KB)" % (out, os.path.getsize(out) / 1024.0))

    with open(os.path.join(BUILD, "codes.txt"), "w", encoding="utf-8") as f:
        for code, chars in entries:
            f.write("%s\t%s\n" % (code, "".join(chars)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

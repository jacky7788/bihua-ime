# Bihua IME — a stroke input method for macOS

[中文說明](README.md) · English

A Nokia-style five-stroke Chinese input method for macOS. You type the **stroke
order of the simplified form** and it commits the **traditional** character.

```
马 (simplified, 3 strokes)  →  551  →  馬
国                          →  251121  →  國
```

Built as a real system input method (InputMethodKit), so it works in every app —
Safari, Word, Excel, Terminal, chat apps — not just one.

## What it looks like

Typing 中 — `s` `g` `a` `s` (丨乛一丨), ten candidates per page:

![Composing](docs/screenshot-composing.png)

After committing 中, the bar turns into next-character suggestions (the 聯
marker on the right):

![Suggestions](docs/screenshot-suggestion.png)

> These are illustrations drawn from the same geometry, colours and font sizes
> as `CandidateCanvas.swift`, not screen captures. On your machine the bar
> appears just below the caret.

## Download

**[⬇ Latest release](https://github.com/jacky7788/bihua-ime/releases/latest)** —
unzip, drop `BihuaIME.app` into `~/Library/Input Methods/`, then **log out and back
in once**. The app is ad-hoc signed: on first launch use right-click → Open, or
`xattr -dr com.apple.quarantine ~/Library/Input\ Methods/BihuaIME.app`.

Prefer to build from source? See [Install](#install).

## Why

macOS ships a stroke IME, but it is keyboard-only, has no frequency ranking, no
next-character suggestions, and no custom key mapping. This one:

- **Frequency-ranked candidates** — type two or three strokes and the most common
  characters come first (`251` → 口 是 中 時 日 …).
- **Next-character suggestion** — after committing a character it offers the most
  likely next one (`時` → 間, `我` → 們). Chainable: 中 → 國 → 家.
- **Fully rebindable** — strokes and candidate keys are plain JSON config.
- **Paging** — `y` / `n` turn candidate pages, ten per page.
- **Offline** — the whole code table is a ~190 KB JSON loaded at launch.

## Install

```bash
./build.sh      # compiles and ad-hoc signs build/BihuaIME.app
./install.sh    # copies it to ~/Library/Input Methods
./use.sh        # switches the active input source to 筆畫
```

Requires Xcode command line tools (Swift 5.9+). Tested on macOS 27 (Apple
silicon); should work on macOS 13+.

Then pick **筆畫** from the input menu (or `⌃⌥Space`). If the menu does not list
it yet, log out and back in once — macOS builds the input-source menu at login.

## Keys

| Key | Action |
|---|---|
| `a` `s` `d` `f` `g` | 一 丨 丿 丶 乛 (horizontal / vertical / left-falling / dot / turning) |
| `q` `w` `e` `r` `t` `z` `x` `c` `v` `b` | pick candidate 1–10 |
| `y` / `n` | previous / next candidate page |
| `space` / `enter` | commit the highlighted candidate |
| `backspace` / `esc` | delete one stroke / cancel |
| `←` `→` `↑` `↓` / `tab` | move the highlight inside the page |

Hold **Caps Lock** to type plain English without switching input sources.

Everything above is configurable in `~/Library/Application Support/BihuaIME/config.json`:

```json
{
  "strokeKeys": ["a", "s", "d", "f", "g"],
  "selectKeys": ["q", "w", "e", "r", "t", "z", "x", "c", "v", "b"],
  "prevKey": "y",
  "nextKey": "n",
  "fontSize": 24,
  "pageSize": 10,
  "showPreedit": true,
  "predict": true
}
```

Run `./reload.sh` after editing.

## How it works

```
stroke names (cnchar)  →  5-stroke code  →  code table  →  candidates
        +                    │                 │             │
  OpenCC S→T   ─────────────┘                 │        frequency (jieba)
  jieba 2-char words  ────────────────────────┴──────►  next-char suggestion
```

1. `tools/build_codes.py` turns each simplified character's stroke names into a
   five-stroke code (横=1 竖=2 撇=3 点=4 折=5, with 提→1, 捺→4, 竖钩→2), maps it
   to its traditional form, and ranks the bucket by corpus frequency.
2. `tools/build_predict.py` extracts character→character transitions from jieba's
   two-character words to build the suggestion table.
3. `Sources/` is a small Swift package-less app: `IMKServer` + `IMKInputController`
   + a floating `NSPanel` for candidates.

## Tests

```bash
./test.sh
```

24 checks: code-table lookups, commit/backspace/cancel, paging, numpad, custom
keys, Caps Lock pass-through, frequency ordering, and suggestion chaining.

## Gotcha: what a bundle identifier may look like

Measured on macOS 27, by swapping only the identifier on a byte-identical
bundle and re-signing:

| Identifier | Registered? |
|---|---|
| `com.bihua.inputmethod` (3 segments) | no |
| `com.bihua.inputmethod.stroke` (4) | yes |
| `com.jacky7788.inputmethod.bihua` (4) | yes |
| `io.github.jacky7788.bihua` (4) | no — never appears in TIS at all, even after a reboot |

So: use at least four segments and keep a `com.*` prefix. After changing it you
must log out and back in before the input source list is rebuilt.

## Credits

Stroke data from [cnchar](https://github.com/theajack/cnchar) (MIT), simplified↔
traditional mapping from [OpenCC](https://github.com/BYVoid/OpenCC) (Apache-2.0),
character frequency and word list from [jieba](https://github.com/fxsjy/jieba)
(MIT). See [CREDITS.md](CREDITS.md).

## License

MIT — see [LICENSE](LICENSE).

Not affiliated with Apple. The app is ad-hoc signed; if you distribute it publicly
you will want to sign and notarise it with your own Developer ID.

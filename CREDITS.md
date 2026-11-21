# 資料來源與授權

呢個輸入法嘅字表全部係離線生成，冇 runtime 網絡請求。以下係用咗嘅第三方資料：

| 資料 | 用途 | 授權 | 出處 |
|---|---|---|---|
| **cnchar-order** | 漢字筆順名稱（6939 字）→ 五筆碼 | MIT | [theajack/cnchar](https://github.com/theajack/cnchar) |
| **OpenCC `STCharacters.txt`** | 簡 → 繁對照 | Apache-2.0 | [BYVoid/OpenCC](https://github.com/BYVoid/OpenCC) |
| **jieba `dict.txt`** | 單字頻率、兩字詞（聯想） | MIT | [fxsjy/jieba](https://github.com/fxsjy/jieba) |

`data/` 內嘅 `cnchar-5stroke.json`、`char-freq.json`、`predict.json` 係由上述資料**衍生**出嚟嘅中間產物，同樣按原授權提供。

程式碼（`Sources/`、`tools/`）本身係 MIT，見 [LICENSE](LICENSE)。

早期研究階段曾經試過用 [makemeahanzi](https://github.com/skishore/makemeahanzi) 嘅筆順座標自行分類筆形（Arphic Public License），但準確度不足，最終冇採用，相關檔案亦已從專案移除。

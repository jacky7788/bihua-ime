#!/bin/bash
# 安裝／更新 筆畫 輸入法
set -euo pipefail
cd "$(dirname "$0")"

DEST="$HOME/Library/Input Methods"
APP="build/BihuaIME.app"

if [ ! -d "$APP" ]; then
  echo "搵唔到 $APP，先執行 ./build.sh"
  exit 1
fi

echo "== 停止舊版本 =="
killall BihuaIME 2>/dev/null || true
sleep 0.5

echo "== 複製到 ~/Library/Input Methods =="
mkdir -p "$DEST"
rm -rf "$DEST/BihuaIME.app"
cp -R "$APP" "$DEST/"
codesign --verify --deep "$DEST/BihuaIME.app" >/dev/null 2>&1 \
  && echo "   簽名正常" || echo "   ⚠️ 簽名有問題"

echo "== 確認系統認得 =="
cat > /tmp/bihua_check.swift <<'EOF'
import Carbon
import Foundation
let list = TISCreateInputSourceList(nil, true)?.takeRetainedValue() as? [TISInputSource] ?? []
var n = 0
for s in list {
    guard let p = TISGetInputSourceProperty(s, kTISPropertyInputSourceID) else { continue }
    let id = "\(Unmanaged<CFTypeRef>.fromOpaque(p).takeUnretainedValue())"
    if id == "com.jacky7788.inputmethod.bihua" { n += 1 }
}
print(n > 0 ? "   ✓ 系統已登記（\(n) 個項目）" : "   ⚠️ 系統未登記，可能要登出再登入")
EOF
swiftc -O /tmp/bihua_check.swift -o /tmp/bihua_check 2>/dev/null && /tmp/bihua_check

echo
echo "安裝完成。"
echo "用 ⌃⌥Space 或者選單列輸入法圖示揀「筆畫」試吓。"

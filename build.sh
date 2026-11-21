#!/bin/bash
# 建立 筆畫.app
set -euo pipefail
cd "$(dirname "$0")"

APP="build/BihuaIME.app"
PY="${PYTHON:-python3}"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "== 1/4 編碼表 =="
if [ ! -f build/codes.json ]; then
  "$PY" tools/build_codes.py
fi
cp build/codes.json "$APP/Contents/Resources/codes.json"
if [ ! -f build/predict.json ] && [ -f data/predict.json ]; then
  cp data/predict.json build/predict.json
fi
[ -f build/predict.json ] && cp build/predict.json "$APP/Contents/Resources/predict.json"
ls -lh "$APP/Contents/Resources/codes.json" | awk '{print "   " $5, $9}'

echo "== 2/4 Info.plist =="
cp Resources/Info.plist "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null && echo "   plist OK"

echo "== 3/4 圖示 =="
if [ ! -f build/icons/icon.tiff ]; then
  "$PY" tools/make_icons.py || echo "   (略過圖示)"
fi
cp build/icons/*.tiff "$APP/Contents/Resources/" 2>/dev/null || true
cp Resources/InfoPlist.loctable "$APP/Contents/Resources/" 2>/dev/null || true

echo "== 4/4 編譯 =="
swiftc -O -swift-version 5 \
  -target arm64-apple-macos13.0 \
  -o "$APP/Contents/MacOS/BihuaIME" \
  Sources/*.swift \
  -framework Cocoa -framework InputMethodKit
echo "   編譯完成"

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 \
  && echo "   ad-hoc 簽名 OK" || echo "   ⚠️ 簽名失敗"

codesign --verify --deep "$APP" >/dev/null 2>&1 \
  && echo "   簽名驗證 OK" || echo "   ⚠️ 簽名驗證失敗"

echo
echo "完成：$APP"
du -sh "$APP" | awk '{print "   大小 " $1}'

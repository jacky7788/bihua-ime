#!/bin/bash
# 切去「筆畫」輸入法；再執行一次就切返原本嗰個
set -eu
cd "$(dirname "$0")"
IM=./tools/imctl
CUR=$($IM --get)
if [ "$CUR" = "com.bihua.inputmethod.stroke" ]; then
  PREV=$(cat /tmp/bihua-prev.txt 2>/dev/null || echo com.apple.keylayout.ABC)
  $IM "$PREV" >/dev/null 2>&1 || true
  echo "switched back to: $PREV"
else
  echo "$CUR" > /tmp/bihua-prev.txt
  $IM com.bihua.inputmethod.stroke >/dev/null 2>&1 || true
  echo "switched to Bihua (was: $CUR)"
fi
echo "now: $($IM --get)"

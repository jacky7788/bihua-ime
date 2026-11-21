#!/bin/bash
# 跑全部測試
set -euo pipefail
cd "$(dirname "$0")"
echo "== 引擎測試 =="
./build/BihuaIME.app/Contents/MacOS/BihuaIME --selftest
echo
echo "== 輸入流程測試 =="
BIHUA_HEADLESS=1 swiftc -swift-version 5 -target arm64-apple-macos13.0 \
  -o build/ctest Sources/BihuaEngine.swift Sources/BihuaConfig.swift \
  Sources/CandidatePanel.swift Sources/BihuaInputController.swift Test/main.swift \
  -framework Cocoa -framework InputMethodKit
BIHUA_HEADLESS=1 ./build/ctest

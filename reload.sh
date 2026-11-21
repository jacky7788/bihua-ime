#!/bin/bash
# 改完 config.json 或者更新版本之後，重載輸入法
set -euo pipefail
killall BihuaIME 2>/dev/null && echo "已重載（下次打字會自動再起）" || echo "輸入法未運行，無需重載"

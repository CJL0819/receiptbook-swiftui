#!/bin/sh
# 按模拟器名字精确解析 UDID；找不到时输出空。
# 用法：sh scripts/sim-udid.sh "iPhone 15 Pro"
xcrun simctl list devices available 2>/dev/null \
  | grep -F "  $1 (" \
  | head -1 \
  | sed -E 's/.*\(([0-9A-F0-9-]{36})\).*/\1/'

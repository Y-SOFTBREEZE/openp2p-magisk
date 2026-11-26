#!/usr/bin/env bash
# 从官方接口取最新版本号与下载地址
# 输出两行: VER / URL
set -euo pipefail

API="https://api.openp2p.cn:27183/api/v1/update"

resp=$(curl -fsSLk --retry 3 --retry-delay 2 \
    "$API?fromver=0&os=android&arch=arm64&user=&node=") || {
    echo "更新接口不可达" >&2
    exit 1
}

url=$(printf '%s' "$resp" | sed -n 's/.*"url":"\([^"]*\)".*/\1/p')
ver=$(printf '%s' "$url" | sed -n 's#.*/openp2p-\([0-9][0-9.]*\)\.android-arm64\.tar\.gz#\1#p')

if [ -z "$ver" ]; then
    echo "解析版本失败，接口返回: $resp" >&2
    exit 1
fi

echo "$ver"
echo "$url"

#!/usr/bin/env bash
# 打包模块 zip
# 用法: scripts/build.sh <版本号> <openp2p 二进制> [输出路径]
set -euo pipefail

VER="${1:?用法: build.sh <版本号> <二进制> [输出zip]}"
BIN="${2:?缺少二进制路径}"
OUT="${3:-openp2p-$VER.zip}"
HERE=$(cd "$(dirname "$0")/.." && pwd)

[ -f "$BIN" ] || { echo "找不到 $BIN"; exit 1; }
[ -f "$HERE/module/webroot/index.html" ] || { echo "缺少 module/webroot/index.html"; exit 1; }

magic=$(od -An -tx1 -N4 "$BIN" | tr -d ' \n')
[ "$magic" = "7f454c46" ] || { echo "$BIN 不是 ELF"; exit 1; }
machine=$(od -An -tu1 -j18 -N1 "$BIN" | tr -d ' ')
[ "$machine" = "183" ] || { echo "$BIN 不是 aarch64 (e_machine=$machine)"; exit 1; }

WORK="$HERE/.build"
rm -rf "$WORK"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

cp -R "$HERE/module/." "$WORK/"
rm -f "$WORK/rev"   # 修订号只给打包用，不用进 zip
mkdir -p "$WORK/bin"
cp "$BIN" "$WORK/bin/openp2p"

VCODE=$(printf '%s' "$VER" | awk -F. '{printf "%d%02d%02d", $1, $2, $3}')
# 模块自身的修订号（改了脚本或界面就 +1）：上游版本没变也要能发出新包
REV=$(tr -dc '0-9' < "$HERE/module/rev" 2>/dev/null)
REV=${REV:-1}
VCODE=$((VCODE * 100 + REV))
sed -i "s/^version=.*/version=$VER-r$REV/; s/^versionCode=.*/versionCode=$VCODE/" "$WORK/module.prop"

for f in "$WORK/customize.sh" "$WORK/service.sh" "$WORK/uninstall.sh" "$WORK/action.sh" \
         "$WORK/daemon.sh" "$WORK/post-fs-data.sh" "$WORK/o2p" "$WORK/bin/openp2p" \
         "$WORK/system/bin/o2p" "$WORK/META-INF/com/google/android/update-binary"; do
    chmod 755 "$f"
done
chmod 644 "$WORK/module.prop" "$WORK/config.default.json" "$WORK/system/etc/resolv.conf" \
          "$WORK/META-INF/com/google/android/updater-script" "$WORK/webroot/index.html"
chmod 755 "$WORK/webroot"

OUT_ABS=$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")
(cd "$WORK" && zip -r -9 -q -X "$OUT_ABS" . -x '.*' -x '__MACOSX/*')

echo "生成 $OUT_ABS ($(du -h "$OUT_ABS" | cut -f1))，版本 $VER-r$REV / code $VCODE"

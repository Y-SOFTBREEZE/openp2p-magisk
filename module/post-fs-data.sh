#!/system/bin/sh
# 模块挂载后、service.sh 之前执行。
# 有些安装方式（手动解压 zip、某些第三方安装器）会丢掉可执行位，
# 这里无条件修一遍，免得 service.sh 因为找不到可执行文件而什么都不做。

MODDIR=${0%/*}

chmod 755 "$MODDIR" 2>/dev/null
for f in "$MODDIR/o2p" "$MODDIR"/*.sh "$MODDIR/bin/openp2p" "$MODDIR/system/bin/o2p"; do
    [ -f "$f" ] && chmod 755 "$f" 2>/dev/null
done

exit 0

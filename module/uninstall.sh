#!/system/bin/sh

DATA=/data/adb/openp2p
PIDF=$DATA/run/supervisord.pid

[ -f "$PIDF" ] && kill "$(cat "$PIDF")" 2>/dev/null
rm -f "$PIDF"

for p in $(pidof openp2p); do
    kill "$p" 2>/dev/null
done

sleep 1

# 模块文件会被删，运行数据（config.json）保留，方便重装后接着用
rm -f "$DATA/openp2p" "$DATA/o2p"

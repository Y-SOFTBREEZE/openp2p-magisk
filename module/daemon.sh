#!/system/bin/sh
# OpenP2P 守护循环。service.sh 开机调用，WebUI / o2p start 也调用同一份。
# openp2p 自己的 -d 模式依赖 openp2p-cn/service 装 systemd 服务，Android 上没有。

DATA=/data/adb/openp2p
PIDF=$DATA/run/supervisord.pid
STOPF=$DATA/run/stopped
SUPLOG=$DATA/log/service.log

mkdir -p "$DATA/log" "$DATA/run"

# 谁启动守护，谁就清掉上次的停止标记
rm -f "$STOPF"
echo $$ > "$PIDF"

while [ ! -f "$STOPF" ]; do
    cd "$DATA" || exit 1
    ./openp2p -nv >> "$SUPLOG" 2>&1
    [ -f "$STOPF" ] && break
    echo "$(date '+%F %T') openp2p 退出，20 秒后拉起" >> "$SUPLOG"
    sleep 20
done

rm -f "$PIDF"
echo "$(date '+%F %T') 守护循环结束" >> "$SUPLOG"

#!/system/bin/sh
# OpenP2P 模块：开机启动
# 由 Magisk / KernelSU 在 late_start service 阶段以 root 执行

MODDIR=${0%/*}
DATA=/data/adb/openp2p
BIN=$DATA/openp2p
CFG=$DATA/config.json
SUPLOG=$DATA/log/service.log
PIDF=$DATA/run/supervisord.pid

mkdir -p "$DATA/log" "$DATA/run"

# 二进制软链（模块升级后路径不变，配置留在 /data/adb/openp2p）
[ -e "$BIN" ] || ln -sf "$MODDIR/bin/openp2p" "$BIN"

# 已经在跑就不重复拉起
[ -n "$(pidof openp2p)" ] && exit 0

# 等开机完成，避免和系统初始化抢网络
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 180 ]; do
    sleep 1
    i=$((i + 1))
done

# 节点名为空时生成 android-xxxxxx，否则客户端会用 localhost，多台设备撞名
[ -x "$DATA/o2p" ] && "$DATA/o2p" ensure-node >/dev/null 2>&1

# 没配 token 就不启动，避免无意义的重试把日志刷满
token=$(sed -n 's/.*"Token"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$CFG" 2>/dev/null | head -n1)
if [ -z "$token" ] || [ "$token" = "0" ]; then
    echo "$(date '+%F %T') 未配置 token，跳过启动。执行 o2p token <TOKEN>" >> "$SUPLOG"
    exit 0
fi

echo "$(date '+%F %T') supervisor 启动" >> "$SUPLOG"

# 守护循环：openp2p 自己不做进程守护（-d 依赖 systemd，Android 没有）
(
    while true; do
        cd "$DATA" || exit 1
        ./openp2p -nv
        sleep 20
    done
) >> "$SUPLOG" 2>&1 &

echo $! > "$PIDF"

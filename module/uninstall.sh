#!/system/bin/sh
# 模块卸载时执行。KernelSU 的 prune_modules / Magisk 的启动清理都会在删模块目录前调用它，
# 且是「等脚本结束」的方式，所以这里不能无限等。
#
# 目标：卸载后不留任何东西——进程全停，配置、日志、pid、软链一起删。

DATA=/data/adb/openp2p
PIDF=$DATA/run/supervisord.pid

# 卸载后没重启就装了同一模块（modules_update 里有新版本）：这是覆盖重装，别动配置和进程
if [ -d /data/adb/modules_update/openp2p ]; then
    exit 0
fi

# 1. 先立停止标记，守护循环看到它就不再拉起客户端
[ -d "$DATA" ] && mkdir -p "$DATA/run" && touch "$DATA/run/stopped"

# 2. 停守护循环：pid 文件 + 命令行匹配双重保险（可能有旧版本遗留的循环）
[ -f "$PIDF" ] && kill "$(cat "$PIDF")" 2>/dev/null
pkill -f "openp2p/daemon.sh" 2>/dev/null

# 3. 停客户端
for p in $(pidof openp2p); do
    kill "$p" 2>/dev/null
done

# 4. 等进程退干净，最多 5 秒，还不走就强杀
i=0
while [ $i -lt 5 ]; do
    [ -z "$(pidof openp2p)" ] && break
    sleep 1
    i=$((i + 1))
done
for p in $(pidof openp2p); do
    kill -9 "$p" 2>/dev/null
done
pkill -9 -f "openp2p/daemon.sh" 2>/dev/null

# 5. SD-WAN 模式会建 OPSDWAN 链，安卓上 TUN 是桩走不到，留着也清一遍
iptables -t nat -D POSTROUTING -j OPSDWAN 2>/dev/null
iptables -t nat -F OPSDWAN 2>/dev/null
iptables -t nat -X OPSDWAN 2>/dev/null

# 6. 整棵数据目录：config.json（含 token）、log/、run/、o2p 与 openp2p 软链
rm -rf "$DATA"

echo "openp2p 已清理：进程停止，$DATA 已删除"

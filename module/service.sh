#!/system/bin/sh
# OpenP2P 模块：开机启动
# 由 Magisk / KernelSU 在 late_start service 阶段以 root 执行

MODDIR=$(cd "${0%/*}" 2>/dev/null && pwd)
DATA=/data/adb/openp2p
BIN=$DATA/openp2p
CFG=$DATA/config.json
SUPLOG=$DATA/log/service.log
PIDF=$DATA/run/supervisord.pid
AUTO=$DATA/autostart

mkdir -p "$DATA/log" "$DATA/run"

# 版本号留一份在数据目录，界面读 module.prop 失败时兜底
sed -n 's/^version=//p' "$MODDIR/module.prop" 2>/dev/null | head -n1 > "$DATA/ver"

# 二进制与脚本软链，无条件重建：
# 安装时 $MODPATH 可能是 /data/adb/modules_update/openp2p，重启后那个路径就没了，
# 只判断「存在」会让软链一直是断的，界面里所有按钮都会失灵。$MODDIR 是启动时的真实模块目录。
rm -f "$BIN" "$DATA/o2p" "$DATA/daemon.sh"
ln -sf "$MODDIR/bin/openp2p" "$BIN"
ln -sf "$MODDIR/o2p" "$DATA/o2p"
ln -sf "$MODDIR/daemon.sh" "$DATA/daemon.sh"

# 守护已在跑就不重复拉起
[ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null && exit 0

# 等开机完成，避免和系统初始化抢网络
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$i" -lt 180 ]; do
    sleep 1
    i=$((i + 1))
done

# 节点名为空时按机型命名（Xiaomi 14），否则客户端会用 localhost，多台设备撞名
[ -x "$DATA/o2p" ] && "$DATA/o2p" ensure-node >/dev/null 2>&1

# 用户把「开机自启」关了
skip() {
    echo "$(date '+%F %T') $1" >> "$SUPLOG"
    [ -x "$DATA/o2p" ] && "$DATA/o2p" refresh-desc >/dev/null 2>&1
    exit 0
}

if [ "$(cat "$AUTO" 2>/dev/null)" = "off" ]; then
    skip "开机自启已关闭，跳过启动"
fi

# 上一次是用户手动点的「停止」，开机不强行拉起
if [ -f "$DATA/run/stopped" ]; then
    skip "上次手动停止，跳过自启"
fi

# 没配 token 就不启动，避免无意义的重试把日志刷满
token=$(sed -n 's/.*"Token"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$CFG" 2>/dev/null | head -n1)
if [ -z "$token" ] || [ "$token" = "0" ]; then
    skip "未配置 token，跳过启动。在模块界面填 token"
fi

# 守护循环在 daemon.sh 里：openp2p 自己的 -d 依赖 systemd，Android 没有
nohup sh "$DATA/daemon.sh" >/dev/null 2>&1 &
sleep 2
echo "$(date '+%F %T') 守护已启动 (pid $(cat "$PIDF" 2>/dev/null))" >> "$SUPLOG"

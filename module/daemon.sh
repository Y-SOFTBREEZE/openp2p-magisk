#!/system/bin/sh
# OpenP2P 守护循环。service.sh 开机调用，WebUI / o2p start 也调用同一份。
# openp2p 自己的 -d 模式依赖 openp2p-cn/service 装 systemd 服务，Android 上没有。

DATA=/data/adb/openp2p
CFG=$DATA/config.json
PIDF=$DATA/run/supervisord.pid
STOPF=$DATA/run/stopped
SUPLOG=$DATA/log/service.log

mkdir -p "$DATA/log" "$DATA/run"

MODDIR=
for d in /data/adb/modules/openp2p /data/adb/modules_update/openp2p; do
    [ -f "$d/module.prop" ] && { MODDIR=$d; break; }
done

desc() {
    [ -n "$MODDIR" ] && sh "$MODDIR/o2p" refresh-desc >/dev/null 2>&1
}

# 老配置没有这一项，补上；不补的话 -insecure 传不进去，登录会失败
ensure_cfg() {
    [ -f "$CFG" ] || return 0
    grep -q '"TLSInsecureSkipVerify"' "$CFG" && return 0
    grep -q '^[[:space:]]*{' "$CFG" || return 0
    sed -i '1s/{/{\n  "TLSInsecureSkipVerify": true,/' "$CFG"
}

ensure_cfg

field() {
    [ -f "$CFG" ] || return 0
    grep -o "\"$1\"[[:space:]]*:[[:space:]]*[^,}]*" "$CFG" 2>/dev/null \
        | head -n1 | sed 's/^[^:]*:[[:space:]]*//' | tr -d '"'
}

# 参数全部从 config.json 读出来显式传给客户端。
# 走命令行而不是指望它自己解析 config.json：
#   1. 命令行参数的优先级最高（源码 parseParams 里 fset.Visit 会覆盖配置文件的值），
#      配置里哪个键名写歪了都不影响启动；
#   2. -insecure 只能在命令行给。Android 上 x509.SystemCertPool() 找不到系统根证书
#      （/etc/ssl/certs 不存在），只能靠二进制里内置的那几个根，证书链对不上就
#      login 失败、控制台永远看不到设备。
build_args() {
    A="-nv"
    t=$(field Token)
    [ -n "$t" ] && [ "$t" != "0" ] && A="$A -token $t"
    n=$(field Node)
    [ -n "$n" ] && A="$A -node $n"
    h=$(field ServerHost)
    [ -n "$h" ] && A="$A -serverhost $h"
    p=$(field ServerPort)
    [ -n "$p" ] && A="$A -serverport $p"
    b=$(field ShareBandwidth)
    [ -n "$b" ] && A="$A -sharebandwidth $b"
    l=$(field LogLevel)
    [ -n "$l" ] && A="$A -loglevel $l"
    [ "$(field TLSInsecureSkipVerify)" = "true" ] && A="$A -insecure"
    ARGS=$A
}

# 谁启动守护，谁就清掉上次的停止标记
rm -f "$STOPF"
echo $$ > "$PIDF"

while [ ! -f "$STOPF" ]; do
    cd "$DATA" || exit 1
    # 软链没建好就别空转刷日志（正常情况下 service.sh 会先修好）
    [ -x ./openp2p ] || { echo "$(date '+%F %T') 找不到 openp2p 二进制，守护退出" >> "$SUPLOG"; exit 1; }

    build_args
    echo "$(date '+%F %T') 启动: ./openp2p $ARGS" >> "$SUPLOG"
    # 起来 8 秒后再刷一次模块列表的状态行（那时 pidof 才看得见）
    ( sleep 8; desc ) &
    ./openp2p $ARGS
    rc=$?

    [ -f "$STOPF" ] && break
    echo "$(date '+%F %T') openp2p 退出（code $rc），20 秒后拉起" >> "$SUPLOG"
    desc
    sleep 20
done

rm -f "$PIDF"
echo "$(date '+%F %T') 守护循环结束" >> "$SUPLOG"

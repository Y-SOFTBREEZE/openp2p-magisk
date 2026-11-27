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

# 连接健康检查交给 o2p link（读 /proc/net/tcp 的 ESTABLISHED）。查不了就当通着，
# 别因为脚本缺失把一个好进程杀掉。
O2P=
for d in /data/adb/openp2p/o2p /data/adb/modules/openp2p/o2p; do
    [ -x "$d" ] && { O2P=$d; break; }
done

OFFF=$DATA/run/offline_since

link_up() {
    [ -n "$O2P" ] || return 0
    "$O2P" link >/dev/null 2>&1
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
# 手机内存吃紧时 LMK 会挑 oom_score 高的先杀。客户端是常驻的，被静默 SIGKILL 掉
# 日志里什么都不留（09-27 那次就是：17:47:59 还在 init，下一秒进程没了，20 秒后才被拉起）。
# -1000 = 不参与评分，root 才有权限。
echo -1000 > /proc/$$/oom_score_adj 2>/dev/null

while [ ! -f "$STOPF" ]; do
    cd "$DATA" || exit 1
    # 软链没建好就别空转刷日志（正常情况下 service.sh 会先修好）
    [ -x ./openp2p ] || { echo "$(date '+%F %T') 找不到 openp2p 二进制，守护退出" >> "$SUPLOG"; exit 1; }

    build_args
    echo "$(date '+%F %T') 启动: ./openp2p $ARGS" >> "$SUPLOG"
    # 起来 8 秒后再刷一次模块列表的状态行（那时 pidof 才看得见）
    ( sleep 8; desc ) &
    ./openp2p $ARGS &
    CPID=$!
    echo -1000 > "/proc/$CPID/oom_score_adj" 2>/dev/null

    # 进程活着 ≠ 连着。每 10 秒看一眼有没有到服务端的 ESTABLISHED 连接；
    # 客户端自己 60 秒读超时会重连，但卡在重连循环里时它不会退出，pidof 也看不出来
    # （控制台一直离线、界面一直「运行中」）。连续 3 分钟没连接就整只重启。
    down=0
    up=1
    while kill -0 "$CPID" 2>/dev/null; do
        sleep 10
        kill -0 "$CPID" 2>/dev/null || break
        if link_up; then
            down=0
            rm -f "$OFFF"
            if [ "$up" = 0 ]; then
                up=1
                desc
            fi
        else
            if [ "$up" = 1 ]; then
                up=0
                date +%s > "$OFFF"
                desc
            fi
            down=$((down + 1))
            if [ "$down" -ge 18 ]; then
                echo "$(date '+%F %T') 连续 $((down * 10)) 秒没有到服务端的连接，重启客户端" >> "$SUPLOG"
                kill "$CPID" 2>/dev/null
                sleep 3
                kill -9 "$CPID" 2>/dev/null
                break
            fi
        fi
    done
    wait "$CPID"
    rc=$?

    [ -f "$STOPF" ] && break
    echo "$(date '+%F %T') openp2p 退出（code $rc），5 秒后拉起" >> "$SUPLOG"
    desc
    sleep 5
done

rm -f "$PIDF" "$OFFF"
echo "$(date '+%F %T') 守护循环结束" >> "$SUPLOG"

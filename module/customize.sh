#!/system/bin/sh
# 安装时执行。Magisk 与 KernelSU 都会调用。

DATA=/data/adb/openp2p

ui_print "- OpenP2P 无 App 客户端"

case "$(uname -m)" in
    aarch64|arm64) ;;
    *) abort "! 只支持 arm64 设备，当前 $(uname -m)" ;;
esac

ui_print "- 准备数据目录 $DATA"
mkdir -p "$DATA/log" "$DATA/run"

chmod 755 "$MODPATH/bin/openp2p"
chmod 755 "$MODPATH/o2p" "$MODPATH/service.sh" "$MODPATH/action.sh" "$MODPATH/uninstall.sh" "$MODPATH/daemon.sh"
chmod 755 "$MODPATH/system/bin/o2p"

ln -sf "$MODPATH/bin/openp2p" "$DATA/openp2p"
ln -sf "$MODPATH/o2p" "$DATA/o2p"
ln -sf "$MODPATH/daemon.sh" "$DATA/daemon.sh"

if [ -f "$DATA/config.json" ]; then
    ui_print "- 保留已有配置 $DATA/config.json"
else
    cp "$MODPATH/config.default.json" "$DATA/config.json"
    ui_print "- 已创建 $DATA/config.json"
fi

chown -R 0:0 "$DATA"
chmod 700 "$DATA"
chmod 600 "$DATA/config.json"

"$DATA/o2p" ensure-node >/dev/null 2>&1
ui_print "- 节点名：$(sed -n 's/.*"Node"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$DATA/config.json")"

VER=$(sed -n 's/^version=//p' "$MODPATH/module.prop")
ui_print "- 版本 $VER"

if [ "$(sed -n 's/.*"Token"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$DATA/config.json" | head -n1)" = "0" ] || \
   [ -z "$(sed -n 's/.*"Token"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$DATA/config.json" | head -n1)" ]; then
    ui_print "- 还没配置 token，进 KernelSU 模块页点「打开」填"
    ui_print "  （或命令行： su -c o2p token <控制台里的 TOKEN>）"
fi
ui_print "- 重启后自动启动，规则在 console.openp2p.cn 上配置"

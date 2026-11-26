#!/system/bin/sh
# 模块「操作」按钮：点一下看状态。
# 图形界面（填 token、启停、看日志、开管理页）走模块页的「打开」按钮，那是 WebUI。

DATA=/data/adb/openp2p

if [ -x "$DATA/o2p" ]; then
    "$DATA/o2p" status
else
    echo "模块还没初始化，先重启一次"
fi
echo
echo "提示：点模块页的「打开」进图形界面，那里能填 token"

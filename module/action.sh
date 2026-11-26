#!/system/bin/sh
# 模块「操作」按钮：点一下看状态。完整命令用 su -c o2p <命令>

DATA=/data/adb/openp2p

if [ -x "$DATA/o2p" ]; then
    "$DATA/o2p" status
else
    echo "模块还没初始化，先重启一次"
fi

# openp2p-magisk

把 openp2p 官方 Android 客户端做成 Magisk / KernelSU 模块。刷入即用，不用装官方 App，也不用打开任何界面。

## 它到底装了什么

官方分发包里的 `openp2p-<ver>.android-arm64.tar.gz` 就是一个 Go 静态二进制（`GOOS=android`、`GOARCH=arm64`、`CGO_ENABLED=0`，10 MB），P2P 打通、握手、转发全在这个二进制里。官方 APK 只是 Kotlin 外壳加 gomobile 绑定，界面只有登录页。

模块把二进制放进模块目录，`/data/adb/openp2p/openp2p` 软链过去，开机由 `service.sh` 拉起，进程挂了 20 秒后重启。配置只有一件事要做：填 token。转发规则在 [console.openp2p.cn](https://console.openp2p.cn) 网页端按节点配置，客户端登录后服务器自动下发，这也是官方 App 唯一起作用的地方。

## 支持范围

| 项 | 情况 |
| --- | --- |
| 端口转发 / 内网穿透（TCP、UDP） | 支持。手机上的端口可被其他节点访问，也可以反过来访问别的节点 |
| 架构 | 只支持 arm64（arm64-v8a） |
| 系统 | Android 8 及以上（更低的没测） |
| SD-WAN 组网（网络模式） | 不支持 |

网络模式不支持是编译期决定的：`core/optun_android.go` 里 TUN 的 `Start/Read/Write` 全是桩，读写靠 Java 侧 `VpnService` 喂包。命令行方式没有 VpnService，改配置也换不出来。要组网只能用官方 App。

## 安装

1. 从 [Releases](../../releases) 下载 `openp2p-<ver>-module.zip`
2. Magisk 或 KernelSU 的模块页，从本地安装，重启
3. 填 token（在 console.openp2p.cn 的「我的」页面复制）
   ```sh
   su -c o2p token 14970667620017705323
   ```
4. 看状态
   ```sh
   su -c o2p status
   ```

首次开机模块会生成 `android-xxxxxx` 作为节点名，出现在控制台的设备列表里。要换就 `su -c o2p node <8-31 个字符>`。

## 命令

| 命令 | 作用 |
| --- | --- |
| `o2p` / `o2p status` | 版本、节点名、token、进程状态、本地规则条数 |
| `o2p token <TOKEN>` | 写入 token 并重启服务 |
| `o2p node <名字>` | 固定节点名（8-31 字符） |
| `o2p start` / `o2p stop` / `o2p restart` | 手动控制 |
| `o2p log [行数]` | 看日志，默认 30 行 |
| `o2p config` | 打印 config.json |

模块页的「操作」按钮等同于 `o2p status`。某些 ROM 上 `/system/bin` 被写保护导致 `o2p` 找不到，直接用 `/data/adb/openp2p/o2p status`。

共享带宽默认 10 Mbps（`ShareBandwidth`），只在私有网络用就把 `config.json` 里改成 0，改完 `o2p restart`。

## 文件位置

```
/data/adb/modules/openp2p/      模块本体，升级时整体替换
/data/adb/openp2p/config.json   配置，升级不丢
/data/adb/openp2p/log/          openp2p.log（客户端日志）、service.log（守护进程日志）
```

## 三个实现上的坑

**DNS。** 这个二进制用 Go 内置解析器（`CGO_ENABLED=0`），读 `/etc/resolv.conf`。Android 上没有这个文件，官方 App 能上网是因为 gomobile 编译时开了 cgo，走 bionic。模块通过 overlay 提供 `system/etc/resolv.conf`（223.5.5.5 / 119.29.29.29 / 114.114.114.114）。所在网络这几个 DNS 不通，就改模块目录里这个文件再重启。

**不用 `-d`。** 官方 daemon 模式依赖 `openp2p-cn/service` 注册系统服务，Android 没有 systemd，跑起来是空转。所以用模块自带的一个 `while` 循环守护。

**配置不在模块目录。** `core.Run()` 一进来就 `os.Chdir(filepath.Dir(os.Args[0]))`，配置跟着二进制走。模块升级会替换整个模块目录，所以二进制留在模块里，配置放在 `/data/adb/openp2p`，靠软链让 chdir 落到配置目录。

**节点名要自己给。** `core/common.go` 的 `defaultNodeName()` 用 `os.Hostname()`，Android 上这个值固定是 `localhost`，几台设备刷同一个模块就会撞名。模块首次启动时生成 `android-<6 位随机>` 写进配置。

## 自动构建

`.github/workflows/build.yml` 每天 19:00 UTC（北京 03:00）跑一次：

1. 调 `https://api.openp2p.cn:27183/api/v1/update?fromver=0&os=android&arch=arm64`，返回的 URL 里带版本号
2. 跟已有 Release 比，同版本直接跳过
3. 有新版本就下载 tar.gz、解出二进制、用 `scripts/build.sh` 打成模块 zip
4. 发 Release（tag `v<版本>`），同时上传 Actions artifact

手动跑：Actions → build-module → Run workflow，可以填版本号。改了模块脚本想重新发同一版本，先删掉对应 Release 再触发。

本地构建：

```sh
bash scripts/latest.sh              # 打印 VER / URL
curl -fsSLk -o pkg.tar.gz "<URL>"
tar xzf pkg.tar.gz
bash scripts/build.sh 3.25.14 openp2p openp2p-3.25.14-module.zip
```

## 关于版本号

GitHub 上的官方 release 停在 `v3.25.11`，新版本只在官方分发服务器（`console.openp2p.cn/download/v1/`）上发，控制台页面登录后从 `/api/v1/devices` 拿到 `latestVer` 再拼下载地址。这个仓库跟分发服务器走，写这份文档时是 `3.25.14`。

用的接口是控制台自己也在用的公开端点，不需要登录。哪天 openp2p 改了接口，`scripts/latest.sh` 会直接报错退出，不会悄悄打出旧版本。

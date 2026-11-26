# openp2p-magisk

把 openp2p 官方 Android 客户端做成 Magisk / KernelSU 模块。刷入即开机自启，模块页里自带一个配置界面，不用装官方 App。

## 在手机里配置

模块带 WebUI。KernelSU 管理器里进入 模块 → OpenP2P → 「打开」，就是这个界面：

- 状态、机型名、共享带宽；右上角是**开机自启开关**（默认开）
- 网络信息：内网 IP、公网 IPv4、IPv6（跟控制台设备页显示的是同一份数据，取自客户端日志里的 `publicIP:` / `IPv6:`），**点一下复制**
- 启动 / 停止 / 重启，带图标和配色，当前状态下用不了的那个自动置灰
- 设置卡两行：**节点名**（直接改，改完点保存就重启生效，等于在控制台换一台设备）、**Token**（密码框，圆点显示；已配置过时占位符写「token 已配置」，页面任何地方都不再露出 token）
- 「管理页」整行跳系统浏览器打开 console.openp2p.cn
- 「运行日志」默认折叠，折叠时露一行最新日志；展开后有刷新 / 清空 / 诊断 / 导出

模块列表里那一行描述会跟着状态变：`[运行中] Xiaomi 14 · v3.25.14`、`[已停止]`、`[未配置 Token]`，不用点进去也知道跑没跑。

**入口依赖管理器版本。** KernelSU 官方管理器要较新的版本才认模块里的 `webroot`（模块页出现「打开」按钮就是支持）。Magisk 官方 App 没有 WebUI，需要装 [MMRL](https://github.com/MMRLApp/MMRL) 或 KsuWebUIStandalone 才能打开同一个页面。

没有 WebUI 也不影响使用，命令行完全等效，见下面的命令表。

## 它到底装了什么

官方分发包里的 `openp2p-<ver>.android-arm64.tar.gz` 就是一个 Go 静态二进制（`GOOS=android`、`GOARCH=arm64`、`CGO_ENABLED=0`，10 MB），P2P 打通、握手、转发全在这个二进制里。官方 APK 只是 Kotlin 外壳加 gomobile 绑定，界面只有登录页。

模块把二进制放进模块目录，`/data/adb/openp2p/openp2p` 软链过去，开机由 `service.sh` 拉起，`daemon.sh` 负责挂了 5 秒重拉。配置只有一件事要做：填 token。转发规则在 [console.openp2p.cn](https://console.openp2p.cn) 网页端按节点配置，客户端登录后服务器自动下发，这也是官方 App 唯一起作用的地方。

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
3. 进模块页点「打开」，把 token 填进去（在 console.openp2p.cn 的「我的」页面复制），点「保存并启动」
4. 回到控制台，设备列表里应该出现这台机器

命令行版本：

```sh
su -c o2p token 14970667620017705323
su -c o2p status
```

节点名自动取机型名（`ro.product.marketname`，例如 `Xiaomi 14`），它就是控制台设备列表里显示的名字。控制台本身不给改这个名字（只能改备注），要换就直接在模块界面的「节点名」那一行改，或者 `su -c o2p node <8-31 个字符>`。名字里带空格没问题（`Xiaomi 14` 就是带空格的），8–31 字节。

**改节点名 = 在控制台换一台设备。** 服务端是按节点名做设备标识的（`core/config.go` 里的 `NodeNameToID`），名字一变就是新设备：旧设备留在列表里变成离线，挂在它下面的转发规则不会跟过来。所以老版本留下的 `android-xxxxxx` 被自动改成机型名之后，去控制台把旧的那台删掉就行。

反过来也成立：把名字改回原来的 `android-xxxxxx`，认回来的就是控制台里那台旧设备，它的转发规则、备注都还在。

```sh
su -c o2p node android-e06696   # 认回旧设备（这个名字是锁定状态，开机不会再被改成机型名）
su -c o2p node auto             # 解锁，恢复按机型自动命名
```

`o2p node` 会写一个 `node_locked` 标记，之后开机不再自动改名字。

## 命令

| 命令 | 作用 |
| --- | --- |
| `o2p` / `o2p status` | 版本、节点名、token、进程状态、开机自启、本地规则条数 |
| `o2p token <TOKEN>` | 写入 token 并重启服务 |
| `o2p node <名字>` | 固定节点名（8-31 字符），并锁住不让开机自动改名；`o2p node auto` 解锁 |
| `o2p start` / `o2p stop` / `o2p restart` | 手动控制 |
| `o2p autostart on` / `off` | 开机自启开关（界面里也有同一个开关） |
| `o2p log [行数]` | 看日志，默认 60 行 |
| `o2p clearlog` | 清空两份日志（客户端 + 守护） |
| `o2p diag` | 环境、进程、DNS、最近日志，一眼看出卡在哪 |
| `o2p export` | 诊断包写到 `Download/openp2p-<时间>.txt`，可直接发给别人看 |
| `o2p config` | 打印 config.json |

模块页的「操作」按钮等同于 `o2p status`。某些 ROM 上 `/system/bin` 被写保护导致 `o2p` 找不到，直接用 `/data/adb/openp2p/o2p status`。

`o2p stop` 会写一个停止标记，之后开机不会自启；`o2p start` 清掉标记，恢复自启。想让机器重启后不自动跑、但又不想手动停，用 `o2p autostart off`（或界面上的开关）——它只影响下次开机的行为。

## 会不会被系统杀掉 / 会不会掉线

**划掉 KernelSU 的后台不影响它。** 从模块页点「启动」时，命令是 `ksu.exec` 起的，那个 shell 属于管理器的进程组；Android 划掉最近任务会 `kill(-pgid)`，`nohup` 只挡 `SIGHUP`，挡不住整组收到的 `SIGKILL`，客户端就跟着一起死。现在 `o2p start` 和 `service.sh` 都用 `setsid` 起守护（`pgid` 等于自己的 pid，自成会话），管理器怎么退、`magiskd` 怎么重启都跟它没关系。核对：

```sh
ps -o PID,PGID,SID,NAME -p $(pidof openp2p)   # PGID / SID 都等于它自己的 PID 才对
```

**会被 LMK 杀掉，但拉得回来。** 实测过一次：客户端在 `P2PNetwork init` 中间直接消失，日志里连一行错误都没有（被 `SIGKILL` 只能是这样），守护 20 秒后才把它拉起来。所以现在 `daemon.sh` 给守护自己和客户端都写 `oom_score_adj = -1000`（root 才有权限，等于不参与 LMK 打分），重启间隔也从 20 秒缩到 5 秒。

**客户端自己也会周期性断开重连，这是它本来的行为。** `core/p2pnetwork.go` 的 `readLoop` 里超时是硬编码的：60 秒收不到服务器任何消息就 `close` + 重连。日志长这样：

```
ERROR ReadMessage timeout after 1m0s
INFO  got restart channel
INFO  P2PNetwork init start
INFO  login ok. user=softbreeze, node=...
```

从断到重新登录大约 15–20 秒（还要重做一遍 NAT 探测），**这段时间控制台就是「离线」**。运营商 CGNAT 会改映射、空闲连接被中间设备回收，都会触发；判断是不是走了代理，看日志里 DNS 解析出来的地址——`198.18.x.x` 是 Clash 的 fake-ip，真地址是 `124.221.80.223`。

所以控制台偶尔闪一下离线是正常的。要是长时间回不来：

```sh
su -c o2p status   # 进程在不在
su -c o2p log 100  # 是不是卡在 ReadMessage timeout 循环，还是根本没 login ok
```

真要看是不是活着：`o2p status` 里那一行「进程 : 运行中 (pid …)」，`o2p diag` 还会顺带打出 `oom_score_adj`。

唯一会让它停下的：模块被禁用/卸载、`o2p stop`、或把「开机自启」关掉后重启。

共享带宽默认 10 Mbps（`ShareBandwidth`），只在私有网络用就把 `config.json` 里改成 0，改完 `o2p restart`。

## 文件位置

```
/data/adb/modules/openp2p/      模块本体，升级时整体替换
/data/adb/openp2p/config.json   配置，升级不丢
/data/adb/openp2p/autostart     开机自启开关（on / off）
/data/adb/openp2p/log/          openp2p.log（客户端日志）、service.log（守护进程日志）
```

## 卸载

模块页点卸载（Magisk 是删除模块），**然后重启**。KernelSU 的 `prune_modules` 和 Magisk 的启动清理都是在下次开机时才跑 `uninstall.sh`、再删模块目录。

`uninstall.sh` 按顺序做这几件事：

1. 写 `run/stopped` 停止标记，守护循环不会再把客户端拉起来
2. `pkill` 守护循环 + `kill` 客户端，5 秒还不退就 `kill -9`
3. 清 `OPSDWAN` iptables 链（SD-WAN 专用，安卓上 TUN 是桩走不到，留着也清一遍）
4. `rm -rf /data/adb/openp2p`，配置、token、日志、pid、软链整棵删掉

**所以卸载后 token 也没了**，重装要重新填。想留着就先备份 `/data/adb/openp2p/config.json`，重装后拷回去再重启。

重启之前 `su -c o2p` 还能敲（软链指向已删目录会报错），`/system/bin/o2p` 这个 overlay 也要等重启才消失。想立刻停掉客户端又不想重启，用界面上的「停止」。

覆盖安装（同 id 装新版本）不会执行 `uninstall.sh`，配置保留。唯一例外是「先卸载、没重启就直接装新版」——这时 `/data/adb/modules_update/openp2p` 存在，脚本判断为覆盖重装，跳过清理。

## 几个实现上的坑

**TLS 必须跳过校验，否则登录不上。** Go 的 `x509.SystemCertPool()` 只认 `/etc/ssl/certs/ca-certificates.crt` 那一串 Debian/Alpine 路径，Android 上都不存在（系统证书在 `/system/etc/security/cacerts/`，还是散列目录）。二进制里只内置了三张根证书，服务器的自签证书链对不上就 `login error`，控制台永远看不到这台设备。所以配置里默认 `"TLSInsecureSkipVerify": true`，`daemon.sh` 把它翻成 `-insecure` 传给客户端。要严格校验证书就把这一项改成 `false`，但很可能就登不上了。

**参数走命令行，不完全指望 config.json。** `core/config.go` 的 `parseParams` 里，命令行参数优先级最高（`fset.Visit` 会覆盖配置文件的值），而且 `flag.ExitOnError` 遇到不认识的参数会直接退出。所以 `daemon.sh` 把 token / node / serverhost / port / bandwidth / loglevel / insecure 全部从 `config.json` 读出来显式传过去，配置里哪个键名写歪了都不影响启动。日志里能看到实际使用的完整命令行。

**DNS。** 这个二进制用 Go 内置解析器（`CGO_ENABLED=0`），读 `/etc/resolv.conf`。Android 上没有这个文件，官方 App 能上网是因为 gomobile 编译时开了 cgo，走 bionic。模块通过 overlay 提供 `system/etc/resolv.conf`（223.5.5.5 / 119.29.29.29 / 114.114.114.114）。就算 overlay 没生效也有兜底：客户端自己会再拿 119.29.29.29 解析一次（`core/common.go` 的 `lookupWithCustomDNS`）。所以 DNS 通常不是卡点，`o2p diag` 里能看到实际解析结果。

**不用 `-d`。** 官方 daemon 模式依赖 `openp2p-cn/service` 注册系统服务，Android 没有 systemd，跑起来是空转。所以用模块自带的 `daemon.sh` 守护。

**配置不在模块目录。** `core.Run()` 一进来就 `os.Chdir(filepath.Dir(os.Args[0]))`，配置跟着二进制走。模块升级会替换整个模块目录，所以二进制留在模块里，配置放在 `/data/adb/openp2p`，靠软链让 chdir 落到配置目录。

**节点名要自己给。** `core/common.go` 的 `defaultNodeName()` 用 `os.Hostname()`，Android 上这个值固定是 `localhost`，几台设备刷同一个模块就会撞名。模块按 `ro.product.marketname` → `ro.product.model` → `ro.product.device` 的顺序取机型名写进配置，空着或还是老版本生成的 `android-xxxxxx` 才改；名字会被清洗成 `[A-Za-z0-9 ._+-]`（要塞进 JSON 和 sed 替换串，引号、`&` 会破坏配置），不足 8 字符补随机后缀，超 31 字符截断。

**从 WebUI 启动的进程不能挂在管理器 shell 上。** `ksu.exec` 每执行一次开一个 root shell，命令返回就关。所以启动走 `nohup sh daemon.sh &`，让守护循环脱离那个 shell，关掉管理器也不会掉线。

## WebUI 用到的接口

- `ksu.exec(cmd, optionsJson, 回调名)`：回调 `(code, stdout, stderr)`。老管理器只有两参形式，页面里做了回退，再不行 20 秒超时；返回值统一成数字和字符串（有的管理器给的是字符串码或行数组）。
- `ksu_download.openExternal(url)`：跳系统浏览器打开管理页，没有这个接口就退回 `am start`。
- 页面里的命令不依赖 PATH，也不依赖软链：依次探测 `/data/adb/openp2p/o2p`、`/data/adb/modules/openp2p/o2p`、`/data/adb/modules_update/openp2p/o2p`，挑第一个真实存在的。状态读不出来时页面会顺带打印这三个路径和进程号，用来区分「脚本不在」和「脚本在但执行失败」。

## 自动构建

`.github/workflows/build.yml` 每天 19:00 UTC（北京 03:00）跑一次：

1. 调 `https://api.openp2p.cn:27183/api/v1/update?fromver=0&os=android&arch=arm64`，返回的 URL 里带版本号
2. 跟已有 Release 比，同版本同修订号直接跳过
3. 有新版本就下载 tar.gz、解出二进制、用 `scripts/build.sh` 打成模块 zip
4. 发 Release（tag `v<版本>-r<修订号>`），同时上传 Actions artifact

**模块修订号。** 上游版本不动、只改了脚本或界面时，光推代码发不出新包（第 2 步会跳过）。所以模块有自己的一套修订号，写在 `module/rev` 里（纯数字）：**改完模块内容把它加 1 再推**，tag 就变成 `v3.25.14-r3`，`module.prop` 里的 `version` 也会带上 `-r3`，装到手机上能看出刷的是哪一版。`versionCode` = `版本号压成 6 位 × 100 + 修订号`。

手动跑：Actions → build-module → Run workflow，可以填版本号（修订号仍从 `module/rev` 读）。

本地构建：

```sh
bash scripts/latest.sh              # 打印 VER / URL
curl -fsSLk -o pkg.tar.gz "<URL>"
tar xzf pkg.tar.gz
bash scripts/build.sh 3.25.14 openp2p openp2p-3.25.14-module.zip
```

Windows 上用 Git Bash 打出来的 zip 里文件权限是 0，只适合看结构，真机刷入请用 CI 产物或 WSL / Linux 上打包。

## 关于版本号

GitHub 上的官方 release 停在 `v3.25.11`，新版本只在官方分发服务器（`console.openp2p.cn/download/v1/`）上发，控制台页面登录后从 `/api/v1/devices` 拿到 `latestVer` 再拼下载地址。这个仓库跟分发服务器走，写这份文档时是 `3.25.14`。

用的接口是控制台自己也在用的公开端点，不需要登录。哪天 openp2p 改了接口，`scripts/latest.sh` 会直接报错退出，不会悄悄打出旧版本。

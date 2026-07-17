# Tenda AX300 W311MI AIC8800DC Linux 驱动

[English](README.md) | [简体中文](README.zh-CN.md)

[![build](https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI/actions/workflows/build.yml/badge.svg)](https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI/actions/workflows/build.yml)

适用于采用 AIC8800DC 和 AIC8800D80 系列芯片的 Tenda USB 无线网卡的
Linux 外置驱动。本仓库将 SherkeyXD 基于 Tenda 1.0.13 官方驱动整理的驱动与
固件，同原有 AIC8800DC 社区修补版的 DKMS、Debian 打包、CI 和 Release
自动化能力合并。

项目支持 DKMS，Linux 内核升级后会自动为新内核重新编译驱动模块。

## 支持的硬件

部分 Tenda 网卡插入后首先表现为 USB 虚拟光盘。弹出虚拟光盘后，设备会重新
枚举为无线网卡：

| 模式 | USB ID | 说明 |
| --- | --- | --- |
| 虚拟光盘模式 | `a69c:5721` | `aicsemi Aic MSC` |
| Wi-Fi 模式 | `2604:0013` | Tenda AIC8800DC / W311MI |
| Wi-Fi 模式 | `2604:0014` | Tenda AIC8800DC 变体 |
| Wi-Fi 模式 | `2604:001f` | Tenda U11 / AIC8800D80 |
| Wi-Fi 模式 | `2604:0020` | Tenda U11 Pro / AIC8800D80 |

这些 Tenda ID 已加入 USB 设备表。驱动 probe 时，`2604:0013` 和
`2604:0014` 会映射为 `PRODUCT_ID_AIC8800DC`。

对于 `2604:0013`，驱动会选择 W311 专用配置
`aic_userconfig_8800dw_w311.txt`；`2604:0014` 使用对应的 U2 配置。软件包
同时包含 U11 系列所需的 AIC8800D80 固件。

## 合并方案

- 使用 Tenda 1.0.13 驱动核心、设备表、固件、私有命令、厂商扩展、TCP ACK
  优化和新内核兼容修复。
- 为 W311MI 和 U2 使用专用射频配置，而不是把所有 Tenda PID 当作通用
  AIC8800DC 处理。
- 使用 DKMS 注册驱动，在发行版安装新内核后自动重新编译模块。
- 保留标准 debhelper 打包、GitHub Actions 多内核构建、静态分析、Release
  文件和校验和生成能力。

导入的上游 Git 历史使用 `sherkey` remote 管理。后续可先执行
`git fetch sherkey` 审查上游变化，再决定是否合并。固件为上游提供的二进制
文件，不能像源代码一样进行完整审计。

## 实机测试

已使用 `2604:0013` 在 Ubuntu 24.04、x86_64、内核
`6.17.0-35-generic` 上完成测试：

- 成功绑定 `aic8800_fdrv` 并创建 `wlx...` 无线接口。
- NetworkManager 成功扫描和连接 WPA2 网络。
- 成功获得 IPv4 和 IPv6 地址。
- 指定无线接口进行 IPv4 ping，丢包率为 0%。
- 指定无线接口进行 IPv4 和 IPv6 HTTPS 请求，均返回 HTTP 200。
- 安装 `dkms2` 软件包时保持现有无线连接，没有主动卸载运行中的模块。
- 有线 IPv4 默认路由保持不变，无线连接不会自动抢占有线默认入口。

测试时，网卡通过 KVM/USB Hub 连接曾反复出现 xHCI `error -71`，该错误发生
在驱动 probe 之前。改为直接连接主机 USB 端口后，设备正常枚举和工作。

> 本项目是社区驱动，不是 Ubuntu、Tenda、AIC 或 Linux 主线内核的官方组成
> 部分。用于生产环境前，请测试实际内核版本和网卡硬件版本。

## 安装

安装依赖：

```bash
# Debian / Ubuntu
sudo apt install git dkms build-essential linux-headers-$(uname -r) eject usb-modeswitch

# Arch Linux
sudo pacman -S git dkms linux-headers base-devel eject usb_modeswitch

# Fedora
sudo dnf install git dkms kernel-devel kernel-headers eject usb_modeswitch
```

克隆并安装：

```bash
git clone git@github.com:lihaicheng7003/aic8800dc-linux-tenda-W311MI.git
cd aic8800dc-linux-tenda-W311MI
sudo bash ./install.sh
sudo bash ./test.sh   # 可选的基本检查
```

没有配置 GitHub SSH 密钥时，可以使用 HTTPS：

```bash
git clone https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI.git
```

### 安装 Debian 软件包

GitHub Releases 提供适用于 Debian/Ubuntu 的 `all` 架构 DKMS 软件包：

```bash
sudo apt install ./aic8800dc-tenda-dkms_1.0.13+dkms2_all.deb
```

软件包会安装驱动源码、DC/D80 固件、udev 规则和模块自动加载配置。
`postinst` 会注册 DKMS，并为当前已安装的内核编译模块。

升级软件包时会替换源码和 DKMS 注册，但不会主动卸载正在运行的模块。升级后
建议重启；也可以先拔掉网卡，确认无线接口消失后再手动重新加载模块。在活动
接口执行 cfg80211 注销期间强行卸载部分厂商驱动，可能阻塞 NetworkManager、
`ip` 等网络进程。

Debian 内部版本使用 epoch `1:`，保证新 `1.0.13` 软件包在版本排序上高于旧
`6.4.3.0` 软件包；epoch 不会出现在 `.deb` 文件名中。

本地构建软件包：

```bash
sudo apt install build-essential debhelper devscripts dkms
dpkg-buildpackage --no-sign -b
```

生成的 `.deb` 位于仓库的上一级目录。推送版本标签后，Release workflow 会
自动构建软件包、生成 `SHA256SUMS` 并上传 Release 文件：

```bash
git tag -a v1.0.13-dkms2 -m 'Release v1.0.13-dkms2'
git push origin v1.0.13-dkms2
```

## USB 模式切换

安装程序会添加 udev 规则，自动弹出网卡的虚拟光盘。手动切换命令如下：

```bash
sudo usb_modeswitch -KQ -v a69c -p 5721
sleep 2
lsusb
```

切换成功后，`lsusb` 应显示 `2604:0013` 或 `2604:0014`。

## 验证驱动

```bash
dkms status
lsmod | grep -E 'aic|cfg80211'
modinfo aic8800_fdrv | grep -Ei '2604.*0013|2604.*0014'
lsusb -t
ip -brief link
nmcli device status
```

正常情况下应看到：

- `aic_load_fw` 和 `aic8800_fdrv` 两个模块。
- USB 拓扑中的 `Driver=aic8800_fdrv`。
- 名称为 `wlan0` 或 `wlx...` 的无线接口。

连接 Wi-Fi：

```bash
nmcli device wifi list
sudo nmcli device wifi connect 'luolaoshi' password '请替换为实际密码'
nmcli device status
```

检查地址、默认路由和网络连通性：

```bash
ip -brief address
ip route show default
ip -6 route show default
ping -c 3 1.1.1.1
curl --noproxy '*' -4 -I https://www.cloudflare.com/
curl --noproxy '*' -6 -I https://www.cloudflare.com/
```

如果需要保持有线为 IPv4 默认入口，可将无线连接设为不提供默认路由：

```bash
sudo nmcli connection modify 'luolaoshi' ipv4.never-default yes
sudo nmcli connection up 'luolaoshi'
ip route show default
```

## 更新

以普通用户执行，不要给脚本加 `sudo`：

```bash
./update.sh
```

脚本会从当前仓库配置的 `origin` 拉取更新并重新安装。更新前可检查 remote：

```bash
git remote -v
```

## 卸载

```bash
sudo bash ./uninstall.sh
```

## 故障排查

### 驱动加载后没有无线接口

首先检查设备是否仍停留在虚拟光盘模式：

```bash
lsusb
```

如果显示 `a69c:5721`，执行：

```bash
sudo apt install usb-modeswitch
sudo usb_modeswitch -v a69c -p 5721 -KQ
sleep 2
lsusb
ip link show
sudo dmesg | tail -30
```

`tools/aic.rules` 中的 udev 规则会调用 `eject` 自动完成该操作。如果没有安装
`eject`，或者虚拟光盘以 `sr0` 而不是 `sd*` 出现，自动规则可能不生效。

### 已显示 Wi-Fi ID，但没有绑定驱动

如果 `lsusb` 显示 `2604:0013` 或 `2604:0014`，但 `lsusb -t` 显示
`Driver=[none]`，检查模块 alias：

```bash
modinfo aic8800_fdrv | grep -Ei '2604.*0013|2604.*0014'
```

没有输出时，应使用本仓库重新构建 DKMS 模块，而不是安装未包含 Tenda ID 的
原始上游源码。

### USB `error -71` 或 `Cannot enable`

以下错误发生在 USB 枚举阶段，早于无线驱动 probe：

```text
Cannot enable. Maybe the USB cable is bad?
device not accepting address, error -71
unable to enumerate USB device
```

建议完全拔掉网卡并等待 30 秒，然后直接连接主机 USB 2.0 端口，避免无源 Hub、
KVM 或质量较差的延长线。必要时在另一台机器测试网卡。

### Secure Boot

开启 Secure Boot 时，内核模块必须签名，且签名密钥必须被系统信任。请按照
发行版的 MOK 注册流程导入 DKMS 密钥，或在适当情况下关闭 Secure Boot。

### 升级或卸载驱动时网络命令阻塞

不要在无线接口仍活动时直接执行 `modprobe -r aic8800_fdrv`。先断开连接并拔掉
网卡，确认 `wlx...` 接口消失，再卸载模块。若已经出现 cfg80211 内核死锁，
拔掉网卡可能也无法解除已有的不可中断任务，此时需要重启系统。

### 内核卡住或安装后无法启动

驱动主要面向 x86_64 和 arm64。ARMv7 32 位、单核或特殊嵌入式平台可能在
固件下载或 USB 初始化期间出现问题。提交问题时请提供串口日志，或提供：

```bash
sudo journalctl -k -b -1
```

## 手动编译

```bash
cd drivers/aic8800
make
sudo make install
sudo depmod -a
sudo modprobe aic_load_fw aic8800_fdrv
```

Rockchip、Allwinner 或 Amlogic 平台需要在
`drivers/aic8800/Makefile` 中设置对应的平台变量。

## 为其他内核编译

```bash
sudo dkms build -m aic8800dc -v 1.0.13-tenda.2 -k <内核版本>
dkms status
```

Ubuntu 20.04、内核 5.15 示例：

```bash
sudo apt update
sudo apt install dkms build-essential linux-headers-$(uname -r) eject usb-modeswitch
sudo bash ./install.sh
dkms status
```

## 上游来源

本仓库合并了以下项目的能力：

```text
https://github.com/Kiborgik/aic8800dc-linux-patched
https://github.com/SherkeyXD/Tenda-AIC8800DC-Driver
```

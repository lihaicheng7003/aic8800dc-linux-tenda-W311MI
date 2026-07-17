# Tenda AIC8800DC / AIC8800D80 Linux 驱动

[English](README.md) | [简体中文](README.zh-CN.md)

[![build](https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI/actions/workflows/build.yml/badge.svg)](https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI/actions/workflows/build.yml)

适用于采用 AIC8800DC 或 AIC8800D80 芯片的 Tenda USB 无线网卡，包括
AX300 W311MI 和 U11 系列。

安装程序使用 DKMS。系统升级内核后，DKMS 会自动为新内核重新编译驱动；安装
程序还会安装固件和 udev 规则，用于将支持的网卡从虚拟光盘模式切换到 Wi-Fi
模式。

> 这是社区维护的驱动，不是 Tenda、AIC、Linux 发行版或主线内核的官方驱动。
> 用于重要环境前，请先测试实际使用的网卡和内核版本。

## 确认网卡型号

插入网卡后执行：

```bash
lsusb
```

本仓库支持以下 USB ID：

| USB ID | 状态或型号 |
| --- | --- |
| `a69c:5721` | 模式切换前的虚拟光盘 |
| `2604:0013` | Tenda W311MI / AIC8800DC |
| `2604:0014` | Tenda AIC8800DC 变体 |
| `2604:001f` | Tenda U11 / AIC8800D80 |
| `2604:0020` | Tenda U11 Pro / AIC8800D80 |

网卡刚插入时显示 `a69c:5721` 属于正常现象。安装程序会配置自动模式切换；切换
完成后，`lsusb` 应显示上表中的某个 `2604:....` ID。

驱动会自动选择对应的射频配置。其中 `2604:0013` 使用 W311 配置，
`2604:0014` 使用 U2 配置。

## 安装

### 1. 安装依赖

```bash
# Debian / Ubuntu
sudo apt install git dkms build-essential linux-headers-$(uname -r) eject usb-modeswitch

# Arch Linux
sudo pacman -S git dkms linux-headers base-devel eject usb_modeswitch

# Fedora
sudo dnf install git dkms kernel-devel kernel-headers eject usb-modeswitch
```

### 2. 下载并安装驱动

```bash
git clone https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI.git
cd aic8800dc-linux-tenda-W311MI
sudo bash ./install.sh
```

安装后可以运行仓库自带的基本检查：

```bash
sudo bash ./test.sh
```

安装完成后重新插拔网卡。如果旧驱动已经加载，或者无线接口仍未出现，请重启
系统。

### 使用 Debian / Ubuntu 软件包

除了从源码目录安装，也可以从
[GitHub Releases](https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI/releases)
下载 `.deb` 软件包：

```bash
sudo apt install ./aic8800dc-tenda-dkms_1.0.13+dkms2_all.deb
```

软件包会安装源码、固件、udev 规则和 DKMS 配置。升级软件包后请重启系统或
重新插拔网卡；安装程序不会强制卸载正在使用的无线驱动。

## 验证安装结果

检查 USB 设备、驱动模块和网络接口：

```bash
lsusb
lsusb -t
dkms status
lsmod | grep -E 'aic_load_fw|aic8800_fdrv'
ip -brief link
```

正常情况下应看到：

- `2604:0013` 等 Wi-Fi USB ID；
- `lsusb -t` 中的 `Driver=aic8800_fdrv`；
- 已加载的 `aic_load_fw` 和 `aic8800_fdrv`；
- 名称为 `wlan0` 或 `wlx...` 的无线接口。

使用 NetworkManager 连接 Wi-Fi：

```bash
nmcli device wifi list
sudo nmcli device wifi connect '你的Wi-Fi名称' password '你的Wi-Fi密码'
nmcli device status
ip -brief address
```

如果需要让有线网络继续作为 IPv4 默认路由：

```bash
sudo nmcli connection modify '你的Wi-Fi名称' ipv4.never-default yes
sudo nmcli connection up '你的Wi-Fi名称'
```

## 故障排查

### 网卡仍处于虚拟光盘模式

如果 `lsusb` 仍显示 `a69c:5721`，请手动切换：

```bash
sudo usb_modeswitch -KQ -v a69c -p 5721
sleep 2
lsusb
```

如果手动切换有效、自动切换无效，请确认已安装 `eject`，并检查
`tools/aic.rules` 和 udev 日志。

### 已显示 Wi-Fi USB ID，但没有绑定驱动

如果 `lsusb` 显示支持的 `2604:....` ID，而 `lsusb -t` 显示
`Driver=[none]`，请确认当前模块包含对应的设备 ID：

```bash
modinfo aic8800_fdrv | grep -Ei '2604.*(0013|0014|001f|0020)'
```

如果没有输出，系统通常安装了其他版本的 AIC8800 驱动。请重新安装本仓库的
DKMS 模块并重启。

### Secure Boot 阻止模块加载

Secure Boot 只允许加载由受信任密钥签名的内核模块。请按照发行版的 MOK 流程
导入 DKMS 签名密钥，或者在适合当前环境的情况下关闭 Secure Boot。签名问题
通常会在内核日志中显示 `Key was rejected by service`。

### 卸载驱动时网络命令卡住

不要在无线接口仍活动时运行 `modprobe -r aic8800_fdrv`。先断开 Wi-Fi、拔掉
网卡，并等待 `wlan...` 接口消失后再卸载模块。如果 cfg80211 注销过程已经
卡住，请重启系统。

### 收集诊断信息

报告问题时请附上以下输出：

```bash
uname -a
lsusb
lsusb -t
dkms status
sudo dmesg | grep -Ei 'aic|firmware|usb|cfg80211' | tail -100
```

驱动主要在 x86_64 和 arm64 上测试。ARMv7、单核和特殊嵌入式平台可能需要
额外适配。

## 更新和卸载

请以普通用户运行更新脚本。脚本会在需要时自行执行带权限的安装步骤：

```bash
./update.sh
```

卸载驱动：

```bash
sudo bash ./uninstall.sh
```

## 手动编译

普通安装建议使用 DKMS。开发或测试时可以手动编译：

```bash
cd drivers/aic8800
make
sudo make install
sudo depmod -a
sudo modprobe aic_load_fw aic8800_fdrv
```

Rockchip、Allwinner 和 Amlogic 平台可能需要先修改
`drivers/aic8800/Makefile` 中的平台变量。

通过 DKMS 为另一个已安装的内核编译：

```bash
sudo dkms build -m aic8800dc -v 1.0.13-tenda.2 -k <内核版本>
dkms status
```

## 打包和开发

在本地构建 Debian 软件包：

```bash
sudo apt install build-essential debhelper devscripts dkms
dpkg-buildpackage --no-sign -b
```

生成的软件包位于仓库的上一级目录。CI 会检查受支持的内核，并将较新的内核
作为提前发现兼容性问题的参考。

本仓库整合了以下项目的工作：

- <https://github.com/Kiborgik/aic8800dc-linux-patched>
- <https://github.com/SherkeyXD/Tenda-AIC8800DC-Driver>

固件文件来自上游驱动，无法像源代码一样进行完整审计。

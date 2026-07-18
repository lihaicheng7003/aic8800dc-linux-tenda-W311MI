# Tenda AIC8800DC / AIC8800D80 Linux 驱动

[English](README.md) | 简体中文

[![build](https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI/actions/workflows/build.yml/badge.svg)](https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI/actions/workflows/build.yml)

适用于 Tenda W311MI、U11 等采用 AIC8800DC / AIC8800D80 芯片的 USB
无线网卡。项目提供驱动源码、固件、USB 模式切换规则和 DKMS 集成；升级内核后
DKMS 会自动为新内核重建驱动。

> 这是社区维护的驱动，并非 Tenda、AIC 或 Linux 内核官方项目。用于重要环境前，
> 请先在实际网卡和内核版本上测试。

## 支持的设备

用 `lsusb` 查看 USB ID：

| USB ID | 设备或状态 |
| --- | --- |
| `a69c:5721` | 切换前的虚拟光盘模式 |
| `2604:0013` | Tenda W311MI / AIC8800DC |
| `2604:0014` | Tenda AIC8800DC 变体 |
| `2604:001f` | Tenda U11 / AIC8800D80 |
| `2604:0020` | Tenda U11 Pro / AIC8800D80 |

刚插入时短暂显示 `a69c:5721` 属于正常现象。udev 规则会将设备切换到
`2604:....` Wi-Fi 模式，并自动选择对应的射频配置。

## 安装

### Debian / Ubuntu：推荐使用软件包

从 [GitHub Releases](https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI/releases)
下载最新 `.deb`，然后执行：

```bash
sudo apt install ./aic8800dc-tenda-dkms_1.0.13+dkms5_all.deb
```

软件包会安装所需依赖、固件、udev 规则和 DKMS 源码，并为所有已安装且具备
头文件的内核构建模块。安装或升级后重新插拔网卡；如仍加载旧模块，请重启。

### 从源码安装

先安装当前内核的头文件和构建工具：

```bash
# Debian / Ubuntu
sudo apt install git dkms build-essential linux-headers-$(uname -r) eject usb-modeswitch

# Arch Linux
sudo pacman -S git dkms linux-headers base-devel eject usb_modeswitch

# Fedora
sudo dnf install git dkms kernel-devel kernel-headers eject usb-modeswitch
```

再安装驱动：

```bash
git clone https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI.git
cd aic8800dc-linux-tenda-W311MI
sudo ./install.sh
```

## 验证与连接

运行项目自带检查：

```bash
sudo ./test.sh
```

或手动确认关键状态：

```bash
lsusb -t
dkms status
ip -brief link
```

正常结果应同时满足：

- `lsusb -t` 显示 `Driver=aic8800_fdrv`；
- `dkms status` 显示驱动已安装到当前 `uname -r` 内核；
- 存在 `wlan0` 或 `wlx...` 无线接口。

使用 NetworkManager 连接：

```bash
nmcli device wifi list
sudo nmcli device wifi connect 'Wi-Fi 名称' password 'Wi-Fi 密码'
nmcli device status
```

## 故障排查

先执行以下命令，然后根据结果定位：

```bash
uname -r
lsusb
lsusb -t
dkms status
```

| 现象 | 原因 | 处理方法 |
| --- | --- | --- |
| `lsusb` 始终为 `a69c:5721` | 设备仍在虚拟光盘模式 | 执行 `sudo usb_modeswitch -KQ -v a69c -p 5721`，并确认已安装 `eject` 和 `usb-modeswitch` |
| 已显示 `2604:....`，但 `Driver=[none]` | 当前内核没有可用模块 | 按下方“内核升级后无 Wi-Fi”步骤重建 DKMS 模块 |
| 模块存在但无法加载 | 常见于 Secure Boot 拒绝签名 | 检查 `sudo dmesg | grep -Ei 'key|secure|aic'`，按发行版 MOK 流程导入 DKMS 密钥 |
| 有无线接口但搜不到网络 | 固件、射频或监管域问题 | 收集下方诊断信息并提交 Issue |

### 内核升级后无 Wi-Fi

`dkms status` 必须包含当前 `uname -r`。如果只显示旧内核，执行：

```bash
sudo dkms autoinstall -m aic8800dc -v 1.0.13-tenda.4 -k "$(uname -r)"
sudo modprobe aic_load_fw
sudo modprobe aic8800_fdrv
```

如果构建失败，请先确认 `/lib/modules/$(uname -r)/build` 存在；否则安装当前内核
的 headers 后重试。

### 收集诊断信息

提交 Issue 时请附上完整输出：

```bash
uname -a
lsusb
lsusb -t
dkms status
ip -brief link
sudo dmesg | grep -Ei 'aic|firmware|usb|cfg80211|secure|key' | tail -100
```

主要测试平台为 x86_64 和 arm64。ARMv7、单核及特殊嵌入式平台可能需要额外适配。

## 更新与卸载

```bash
./update.sh                 # 更新源码并重新安装
sudo ./uninstall.sh         # 完整卸载
```

不要在无线接口仍活动时强制执行 `modprobe -r aic8800_fdrv`。需要卸载模块时，
先断开 Wi-Fi、拔出网卡，并等待无线接口消失。

## 开发

手动编译仅用于开发和兼容性测试，普通用户应使用 DKMS：

```bash
make -C drivers/aic8800 KDIR=/lib/modules/$(uname -r)/build
```

构建 Debian 软件包：

```bash
sudo apt install build-essential debhelper devscripts dkms
dpkg-buildpackage --no-sign -b
```

生成的包位于仓库上一级目录。CI 覆盖多个 Ubuntu GA/HWE 内核，并使用较新内核
提前发现 API 兼容性问题。

## 来源与许可

本项目整合了以下社区项目的工作：

- <https://github.com/Kiborgik/aic8800dc-linux-patched>
- <https://github.com/SherkeyXD/Tenda-AIC8800DC-Driver>

源代码按仓库许可证发布。固件来自上游驱动，无法像源代码一样进行完整审计。

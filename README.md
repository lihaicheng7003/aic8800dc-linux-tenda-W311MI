# Tenda AIC8800DC / AIC8800D80 Linux Driver

[English](README.md) | [简体中文](README.zh-CN.md)

[![build](https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI/actions/workflows/build.yml/badge.svg)](https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI/actions/workflows/build.yml)

Community Linux driver for Tenda USB Wi-Fi adapters based on the AIC8800DC
and AIC8800D80 chipsets, including the AX300 W311MI and U11 series.

The installer uses DKMS, so the driver is rebuilt automatically after a kernel
upgrade. It also installs the firmware and a udev rule that switches supported
adapters from virtual CD-ROM mode to Wi-Fi mode.

> This is not an official Tenda, AIC, distribution, or mainline Linux driver.
> Test it with your exact adapter and kernel before using it in production.

## Check your adapter

Run:

```bash
lsusb
```

This repository supports the following USB IDs:

| USB ID | State or model |
| --- | --- |
| `a69c:5721` | Virtual CD-ROM mode before switching |
| `2604:0013` | Tenda W311MI / AIC8800DC |
| `2604:0014` | Tenda AIC8800DC variant |
| `2604:001f` | Tenda U11 / AIC8800D80 |
| `2604:0020` | Tenda U11 Pro / AIC8800D80 |

Seeing `a69c:5721` is normal immediately after plugging in the adapter. The
installer configures automatic mode switching. After the switch, `lsusb`
should show one of the `2604:....` IDs above.

Device-specific radio configuration is selected automatically. In particular,
`2604:0013` uses the W311 configuration and `2604:0014` uses the U2
configuration.

## Install

### 1. Install dependencies

```bash
# Debian / Ubuntu
sudo apt install git dkms build-essential linux-headers-$(uname -r) eject usb-modeswitch

# Arch Linux
sudo pacman -S git dkms linux-headers base-devel eject usb_modeswitch

# Fedora
sudo dnf install git dkms kernel-devel kernel-headers eject usb_modeswitch
```

### 2. Download and install the driver

```bash
git clone https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI.git
cd aic8800dc-linux-tenda-W311MI
sudo bash ./install.sh
```

Optionally run the included sanity check:

```bash
sudo bash ./test.sh
```

Unplug and reconnect the adapter after installation. Reboot if the old module
is already loaded or the wireless interface does not appear.

### Debian / Ubuntu package

As an alternative to installing from the source tree, download the `.deb` from
[GitHub Releases](https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI/releases)
and install it with:

```bash
sudo apt install ./aic8800dc-tenda-dkms_1.0.13+dkms2_all.deb
```

The package installs the source, firmware, udev rule, and DKMS configuration.
After upgrading the package, reboot or reconnect the adapter. The package does
not forcibly unload an active wireless driver.

## Verify the installation

Check the device, modules, and network interface:

```bash
lsusb
lsusb -t
dkms status
lsmod | grep -E 'aic_load_fw|aic8800_fdrv'
ip -brief link
```

A working installation normally shows:

- a Wi-Fi USB ID such as `2604:0013`;
- `Driver=aic8800_fdrv` in `lsusb -t`;
- both `aic_load_fw` and `aic8800_fdrv` loaded; and
- a wireless interface named `wlan0` or `wlx...`.

Connect using NetworkManager:

```bash
nmcli device wifi list
sudo nmcli device wifi connect 'YOUR_SSID' password 'YOUR_PASSWORD'
nmcli device status
ip -brief address
```

If Ethernet should remain the default IPv4 route:

```bash
sudo nmcli connection modify 'YOUR_SSID' ipv4.never-default yes
sudo nmcli connection up 'YOUR_SSID'
```

## Troubleshooting

### The adapter remains in CD-ROM mode

If `lsusb` still shows `a69c:5721`, switch it manually:

```bash
sudo usb_modeswitch -KQ -v a69c -p 5721
sleep 2
lsusb
```

If this works manually but not automatically, confirm that `eject` is
installed and inspect `tools/aic.rules` and the udev logs.

### A Wi-Fi USB ID appears, but no driver is attached

If `lsusb` shows a supported `2604:....` ID while `lsusb -t` shows
`Driver=[none]`, confirm that the installed module contains the device alias:

```bash
modinfo aic8800_fdrv | grep -Ei '2604.*(0013|0014|001f|0020)'
```

No output usually means a different AIC8800 driver is installed. Reinstall the
DKMS module from this repository and reboot.

### Secure Boot blocks the module

Secure Boot only loads kernel modules signed by a trusted key. Enroll the DKMS
signing key through your distribution's MOK process, or disable Secure Boot if
that is appropriate for your system. Kernel logs usually contain `Key was
rejected by service` when signing is the problem.

### Network commands hang while unloading the driver

Do not run `modprobe -r aic8800_fdrv` while its interface is active. Disconnect
Wi-Fi, unplug the adapter, and wait for the `wlan...` interface to disappear
before unloading modules. Reboot if cfg80211 teardown is already stuck.

### Collect diagnostic information

Include the following output when reporting a problem:

```bash
uname -a
lsusb
lsusb -t
dkms status
sudo dmesg | grep -Ei 'aic|firmware|usb|cfg80211' | tail -100
```

The driver is primarily tested on x86_64 and arm64. ARMv7, single-core, and
unusual embedded platforms may require additional platform work.

## Update or uninstall

Run the update script as your normal user; it invokes privileged installation
steps when needed:

```bash
./update.sh
```

To uninstall:

```bash
sudo bash ./uninstall.sh
```

## Build manually

DKMS is recommended for normal installations. For development or testing:

```bash
cd drivers/aic8800
make
sudo make install
sudo depmod -a
sudo modprobe aic_load_fw aic8800_fdrv
```

Rockchip, Allwinner, and Amlogic builds may require platform variables in
`drivers/aic8800/Makefile`.

To build through DKMS for another installed kernel:

```bash
sudo dkms build -m aic8800dc -v 1.0.13-tenda.2 -k <kernel-version>
dkms status
```

## Packaging and development

Build a Debian package locally with:

```bash
sudo apt install build-essential debhelper devscripts dkms
dpkg-buildpackage --no-sign -b
```

The package is written to the parent directory. CI checks supported kernels and
also tests newer kernels as an early compatibility signal.

This repository combines work from:

- <https://github.com/Kiborgik/aic8800dc-linux-patched>
- <https://github.com/SherkeyXD/Tenda-AIC8800DC-Driver>

Firmware files are redistributed from the upstream driver and cannot be
audited in the same way as source code.

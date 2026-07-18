# Tenda AIC8800DC / AIC8800D80 Linux Driver

English | [简体中文](README.zh-CN.md)

[![build](https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI/actions/workflows/build.yml/badge.svg)](https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI/actions/workflows/build.yml)

Community Linux driver for Tenda USB Wi-Fi adapters based on the AIC8800DC
and AIC8800D80 chipsets, including the W311MI and U11 series. The project
provides the driver, firmware, USB mode-switch rule, and DKMS integration for
automatic rebuilds after kernel upgrades.

> This is not an official Tenda, AIC, distribution, or mainline Linux driver.
> Test it with your exact adapter and kernel before production use.

## Supported devices

Use `lsusb` to identify the adapter:

| USB ID | Device or state |
| --- | --- |
| `a69c:5721` | Virtual CD-ROM mode before switching |
| `2604:0013` | Tenda W311MI / AIC8800DC |
| `2604:0014` | Tenda AIC8800DC variant |
| `2604:001f` | Tenda U11 / AIC8800D80 |
| `2604:0020` | Tenda U11 Pro / AIC8800D80 |

Seeing `a69c:5721` briefly after plugging in the adapter is normal. The udev
rule switches it to a `2604:....` Wi-Fi ID and the driver selects the matching
radio configuration automatically.

## Installation

### Debian / Ubuntu package (recommended)

Download the latest `.deb` from [GitHub Releases](https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI/releases),
then install it:

```bash
sudo apt install ./aic8800dc-tenda-dkms_1.0.13+dkms5_all.deb
```

The package installs its dependencies, firmware, udev rule, and DKMS source,
then builds modules for every installed kernel with headers. Reconnect the
adapter after installation or upgrade; reboot if an older module remains loaded.

### Install from source

Install build tools and headers for the running kernel:

```bash
# Debian / Ubuntu
sudo apt install git dkms build-essential linux-headers-$(uname -r) eject usb-modeswitch

# Arch Linux
sudo pacman -S git dkms linux-headers base-devel eject usb_modeswitch

# Fedora
sudo dnf install git dkms kernel-devel kernel-headers eject usb_modeswitch
```

Install the driver:

```bash
git clone https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI.git
cd aic8800dc-linux-tenda-W311MI
sudo ./install.sh
```

## Verify and connect

Run the included system check:

```bash
sudo ./test.sh
```

Or inspect the essential state directly:

```bash
lsusb -t
dkms status
ip -brief link
```

A working installation has all three of the following:

- `Driver=aic8800_fdrv` in `lsusb -t`;
- an `installed` DKMS entry for the current `uname -r`; and
- a wireless interface named `wlan0` or `wlx...`.

Connect with NetworkManager:

```bash
nmcli device wifi list
sudo nmcli device wifi connect 'YOUR_SSID' password 'YOUR_PASSWORD'
nmcli device status
```

## Troubleshooting

Start with these four commands:

```bash
uname -r
lsusb
lsusb -t
dkms status
```

| Symptom | Likely cause | Resolution |
| --- | --- | --- |
| `lsusb` remains at `a69c:5721` | Adapter is still in virtual CD-ROM mode | Run `sudo usb_modeswitch -KQ -v a69c -p 5721`; ensure `eject` and `usb-modeswitch` are installed |
| A `2604:....` ID appears but the driver is `[none]` | No module is installed for the running kernel | Rebuild DKMS for the current kernel as shown below |
| The module exists but will not load | Secure Boot commonly rejected its signature | Check `sudo dmesg | grep -Ei 'key|secure|aic'` and enroll the DKMS key through your distribution's MOK flow |
| A wireless interface exists but finds no networks | Firmware, radio configuration, or regulatory issue | Collect the diagnostics below and open an issue |

### No Wi-Fi after a kernel upgrade

`dkms status` must include the current `uname -r`. If it lists only an older
kernel, run:

```bash
sudo dkms autoinstall -m aic8800dc -v 1.0.13-tenda.4 -k "$(uname -r)"
sudo modprobe aic_load_fw
sudo modprobe aic8800_fdrv
```

If the build fails, ensure `/lib/modules/$(uname -r)/build` exists. Otherwise,
install headers for the running kernel and retry.

### Diagnostic report

Include the complete output below when opening an issue:

```bash
uname -a
lsusb
lsusb -t
dkms status
ip -brief link
sudo dmesg | grep -Ei 'aic|firmware|usb|cfg80211|secure|key' | tail -100
```

The primary test platforms are x86_64 and arm64. ARMv7, single-core, and
unusual embedded targets may need additional platform work.

## Update and uninstall

```bash
./update.sh                 # update the source and reinstall
sudo ./uninstall.sh         # remove the driver completely
```

Do not force `modprobe -r aic8800_fdrv` while its interface is active. Before
unloading modules, disconnect Wi-Fi, unplug the adapter, and wait for the
wireless interface to disappear.

## Development

Manual builds are intended for development and compatibility testing. Normal
installations should use DKMS.

```bash
make -C drivers/aic8800 KDIR=/lib/modules/$(uname -r)/build
```

Build the Debian package locally:

```bash
sudo apt install build-essential debhelper devscripts dkms
dpkg-buildpackage --no-sign -b
```

The package is written to the parent directory. CI covers multiple Ubuntu
GA/HWE kernels and newer kernels as an early compatibility signal.

## Sources and licensing

This repository incorporates work from:

- <https://github.com/Kiborgik/aic8800dc-linux-patched>
- <https://github.com/SherkeyXD/Tenda-AIC8800DC-Driver>

Source code is distributed under the repository license. Firmware comes from
the upstream driver and cannot be audited in the same way as source code.

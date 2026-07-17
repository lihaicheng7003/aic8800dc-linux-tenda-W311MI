# Tenda AX300 W311MI AIC8800DC Linux Driver

[English](README.md) | [简体中文](README.zh-CN.md)

[![build](https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI/actions/workflows/build.yml/badge.svg)](https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI/actions/workflows/build.yml)

Out-of-tree Linux driver for Tenda USB Wi-Fi adapters using AIC8800DC and
AIC8800D80-family chipsets. It combines the Tenda 1.0.13 driver and firmware
from SherkeyXD with the DKMS, Debian packaging, CI, and release automation
originally built around the patched AIC8800DC community driver.

DKMS support is included so the modules are rebuilt automatically when
the Linux kernel is upgraded.

## Supported hardware

The Tenda adapter initially appears as a USB mass-storage device and
changes its USB ID after the virtual disk is ejected:

| Mode | USB ID | Description |
| --- | --- | --- |
| Mass-storage mode | `a69c:5721` | `aicsemi Aic MSC` |
| Wi-Fi mode | `2604:0013` | Tenda AIC8800DC / W311MI |
| Wi-Fi mode | `2604:0014` | Tenda AIC8800DC variant |
| Wi-Fi mode | `2604:001f` | Tenda U11 / AIC8800D80 |
| Wi-Fi mode | `2604:0020` | Tenda U11 Pro / AIC8800D80 |

The Tenda IDs are explicitly included in the USB device table and are
mapped to `PRODUCT_ID_AIC8800DC` during probe.

For `2604:0013`, the driver selects the W311-specific
`aic_userconfig_8800dw_w311.txt`; `2604:0014` uses the corresponding U2
configuration. The package also carries the D80 firmware needed by the U11
variants.

## Combined design

- Tenda 1.0.13 driver core, device tables, firmware, private commands, vendor
  extensions, TCP ACK optimization, and current-kernel compatibility changes.
- Dedicated W311MI and U2 radio configuration instead of treating every Tenda
  PID as a generic AIC8800DC device.
- DKMS registration so modules are rebuilt when a distribution installs a new
  kernel.
- Standard debhelper packaging, reproducible GitHub Actions builds, static
  analysis, release artifacts, and checksums.

The imported driver is maintained as an upstream Git history named `sherkey`;
future upstream updates can be reviewed with `git fetch sherkey` before they
are merged. Firmware binaries are redistributed from the upstream driver and
cannot be audited like source code.

This fork was installed and tested with `2604:0013` on Ubuntu 24.04,
x86_64, kernel `6.17.0-35-generic`. It successfully created a wireless
interface, scanned access points, connected to a WPA2 network, and
passed IPv4, IPv6, DNS, and HTTPS connectivity tests.

The merged Tenda 1.0.13 driver was subsequently tested on the same machine
and adapter. It bound to `2604:0013`, selected the W311 configuration,
connected through NetworkManager, obtained IPv4 and IPv6 addresses, and
passed interface-bound IPv4 ping plus IPv4/IPv6 HTTPS tests.

> This is a community driver, not an official Ubuntu, Tenda, AIC, or
> mainline Linux kernel driver. Test each kernel and adapter revision
> before relying on it in production.

## Install

Install dependencies:

```bash
# Debian / Ubuntu
sudo apt install git dkms build-essential linux-headers-$(uname -r) eject usb-modeswitch

# Arch
sudo pacman -S git dkms linux-headers base-devel eject usb_modeswitch

# Fedora
sudo dnf install git dkms kernel-devel kernel-headers eject usb_modeswitch
```

Clone and install:

```bash
git clone git@github.com:lihaicheng7003/aic8800dc-linux-tenda-W311MI.git
cd aic8800dc-linux-tenda-W311MI
sudo bash ./install.sh
sudo bash ./test.sh   # optional sanity check
```

If SSH access to GitHub is not configured, clone over HTTPS instead:

```bash
git clone https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI.git
```

### Install the Debian package

GitHub Releases provide an `all` architecture DKMS package for Debian
and Ubuntu. Download the package for the release and install it with:

```bash
sudo apt install ./aic8800dc-tenda-dkms_1.0.13+dkms2_all.deb
```

The package installs the driver source, firmware, udev rule, and module
auto-load configuration. Its `postinst` registers the source with DKMS
and builds the modules for the installed kernel.

Package upgrades replace the files and DKMS registration but deliberately do
not unload an active module. Reboot after upgrading, or disconnect the adapter
and unload the modules only after the wireless interface has disappeared.
Unloading a driver while cfg80211 is tearing down an active interface can
block network-management processes on affected vendor-driver versions.

The Debian package uses epoch `1:` internally so upgrades from the older
`6.4.3.0` package are ordered correctly. Debian omits the epoch from the `.deb`
filename.

Build the package locally with:

```bash
sudo apt install build-essential debhelper devscripts dkms
dpkg-buildpackage --no-sign -b
```

The `.deb` is written to the parent directory. To create a GitHub
Release, push a version tag; the release workflow builds the package,
generates `SHA256SUMS`, and attaches both files to the release:

```bash
git tag -a v1.0.13-dkms2 -m 'Release v1.0.13-dkms2'
git push origin v1.0.13-dkms2
```

## USB mode switching

The installer adds a udev rule that ejects the adapter's virtual disk.
To switch it manually:

```bash
sudo usb_modeswitch -KQ -v a69c -p 5721
sleep 2
lsusb
```

After switching, `lsusb` should report `2604:0013` or `2604:0014`.

## Verify

```bash
dkms status
lsmod | grep -E 'aic|cfg80211'
modinfo aic8800_fdrv | grep -Ei '2604.*0013|2604.*0014'
lsusb -t
ip -brief link
nmcli device status
```

A working installation should show both `aic_load_fw` and
`aic8800_fdrv`, `Driver=aic8800_fdrv` in the USB tree, and a `wlan0` or
`wlx...` network interface.

Connect with NetworkManager and inspect routing:

```bash
nmcli device wifi list
sudo nmcli device wifi connect 'your-ssid' password 'your-password'
ip -brief address
ip route show default
ip -6 route show default
```

To keep Ethernet as the IPv4 default path:

```bash
sudo nmcli connection modify 'your-ssid' ipv4.never-default yes
sudo nmcli connection up 'your-ssid'
```

## Update

`git pull` and reinstall in one step. Run it as the normal user, not
with `sudo`:

```bash
./update.sh
```

The script pulls from the repository's configured `origin`. Confirm the
remote before updating:

```bash
git remote -v
```

## Uninstall

```bash
sudo bash ./uninstall.sh
```

## Troubleshooting

### Driver loads but no wireless interface appears

First check whether the dongle is still in USB mass-storage mode
(`a69c:5721`). The udev rule in `tools/aic.rules` runs `eject` to flip
it into Wi-Fi mode. If `eject` is not installed or the dongle
enumerates as a CD-ROM (`sr0` instead of `sd*`), switch it manually:

```bash
sudo apt install usb-modeswitch
sudo usb_modeswitch -v a69c -p 5721 -KQ
sleep 2
lsusb
ip link show
dmesg | tail -30
```

### Wi-Fi mode is visible but no driver is bound

If `lsusb` shows `2604:0013` or `2604:0014` but `lsusb -t` shows
`Driver=[none]`, verify that the installed module contains the Tenda
aliases:

```bash
modinfo aic8800_fdrv | grep -Ei '2604.*0013|2604.*0014'
```

If no alias is printed, rebuild and reinstall the DKMS module from this
fork rather than an unmodified upstream source tree.

### Network commands block while removing the driver

Do not run `modprobe -r aic8800_fdrv` while its wireless interface is active.
Disconnect and physically remove the adapter, confirm the `wlx...` interface
has disappeared, and only then unload the modules. If cfg80211 teardown is
already deadlocked, removing the adapter may not release existing
uninterruptible tasks and a reboot will be required.

### Secure Boot

The kernel modules must be signed and their key trusted for Secure Boot
to load them. Follow the distribution's MOK (Machine Owner Key)
enrollment procedure, or disable Secure Boot where appropriate.

### Kernel hang or no boot after install

The base driver is tested on x86_64 and arm64. Untested platforms such
as ARMv7 32-bit, single-core, or unusual embedded boards may hang during
firmware download or USB enumeration. Capture logs over a serial
console or with `journalctl -k -b -1` when reporting an issue.

## Manual build

```bash
cd drivers/aic8800
make
sudo make install
sudo depmod -a
sudo modprobe aic_load_fw aic8800_fdrv
```

For Rockchip, Allwinner, or Amlogic, set the platform variables in
`drivers/aic8800/Makefile` before building.

## Build for another kernel

```bash
sudo dkms build -m aic8800dc -v 1.0.13-tenda.2 -k <other-version>
dkms status
```

CI gates releases on Linux 6.12 LTS and 6.19. The current Arch kernel is also
built as an experimental compatibility signal; failures caused by unreleased
or newly changed kernel APIs are reported without failing the supported-kernel
build gate.

## Upstream

This repository combines:

```text
https://github.com/Kiborgik/aic8800dc-linux-patched
https://github.com/SherkeyXD/Tenda-AIC8800DC-Driver
```

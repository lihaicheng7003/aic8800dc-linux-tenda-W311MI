# Tenda AX300 W311MI AIC8800DC Linux Driver

[![build](https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI/actions/workflows/build.yml/badge.svg)](https://github.com/lihaicheng7003/aic8800dc-linux-tenda-W311MI/actions/workflows/build.yml)

Out-of-tree Linux driver for the Tenda AX300 W311MI USB Wi-Fi adapter
using the AIC8800DC chipset. This fork is based on the AIC8800DC
6.4.3.0 community driver and adds the Tenda USB IDs and chip mapping
required for the adapter to bind to `aic8800_fdrv`.

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

The Tenda IDs are explicitly included in the USB device table and are
mapped to `PRODUCT_ID_AIC8800DC` during probe.

This fork was installed and tested with `2604:0013` on Ubuntu 24.04,
x86_64, kernel `6.17.0-35-generic`. It successfully created a wireless
interface, scanned access points, connected to a WPA2 network, and
passed IPv4, IPv6, DNS, and HTTPS connectivity tests.

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
sudo apt install ./aic8800dc-tenda-dkms_6.4.3.0+patched5+tenda1_all.deb
```

The package installs the driver source, firmware, udev rule, and module
auto-load configuration. Its `postinst` registers the source with DKMS
and builds the modules for the installed kernel.

Build the package locally with:

```bash
sudo apt install build-essential debhelper devscripts dkms
dpkg-buildpackage --no-sign -b
```

The `.deb` is written to the parent directory. To create a GitHub
Release, push a version tag; the release workflow builds the package,
generates `SHA256SUMS`, and attaches both files to the release:

```bash
git tag -a v6.4.3.0-tenda1 -m 'Release v6.4.3.0-tenda1'
git push origin v6.4.3.0-tenda1
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
sudo dkms build -m aic8800dc -v 6.4.3.0-patched.5 -k <other-version>
dkms status
```

## Upstream

This fork is based on:

```text
https://github.com/Kiborgik/aic8800dc-linux-patched
```

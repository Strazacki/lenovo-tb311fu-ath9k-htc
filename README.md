# Lenovo TB311FU ath9k_htc / AR9271 support

[![License: GPL v2](https://img.shields.io/badge/License-GPL_v2-blue.svg)](LICENSE)
[![Kernel: GKI 6.6](https://img.shields.io/badge/GKI-6.6.57-green.svg)](COMPATIBILITY.md)
[![Arch: aarch64](https://img.shields.io/badge/Arch-aarch64-lightgrey.svg)](COMPATIBILITY.md)
[![ABI: 168/168 Match](https://img.shields.io/badge/KMI_CRC-168%2F168_Match-brightgreen.svg)](docs/BUILD-REPORT.md)

Atheros AR9271 / ath9k_htc USB Wi-Fi support for Lenovo Tab TB311FU running stock Android 15 GKI 6.6, including the cfg80211 wiphy registration compatibility patch and tooling for module verification.

---

## Hardware & Environment Overview

| Parameter | Value |
|---|---|
| **Device** | Lenovo Tab TB311FU (Lenovo Tab M11, codename: `poplar`) |
| **Android** | Android 15 (Stock ZUI 17) |
| **Kernel** | `6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k` |
| **Architecture** | `aarch64` (ARM64, 4KB page size GKI 2.0) |
| **Adapter** | Qualcomm Atheros AR9271 802.11b/g/n USB Adapter |
| **USB ID** | `0cf3:9271` |
| **Driver** | `ath9k_htc` |
| **Firmware** | `ath9k_htc/htc_9271-1.4.0.fw` (Version 1.4, 51,008 bytes) |
| **Root** | Magisk (tested on v30.7) |
| **Compiler** | Android Clang `r510928` / LLVM 18.0.0 |

---

## Status

| Stage / Feature | Status | Notes |
|---|---|---|
| **USB enumeration** | **CONFIRMED** | Device `0cf3:9271` detected cleanly over USB OTG |
| **Firmware upload** | **CONFIRMED** | 51,008 bytes streamed via bulk OUT endpoint |
| **Firmware 1.4** | **CONFIRMED** | Target reports FW Version: 1.4, FW RMW support: On |
| **HTC initialization** | **CONFIRMED** | HTC handshake established with 33 credits |
| **EEPROM/regdomain** | **CONFIRMED** | Calibration parameters and regdomain 0x64 read |
| **ath9k_htc module loading** | **CONFIRMED** | Base driver loaded without symbol or vermagic errors |
| **cfg80211 registration bug** | **CONFIRMED** | Unpatched driver fails at `wiphy_register()` with `-EINVAL` |
| **Patched module build & ABI** | **CONFIRMED / TESTED** | 168/168 matching CRCs, disassembly verified |
| **Patched wiphy registration** | **NOT YET VERIFIED** | Awaiting device runtime `insmod` confirmation |
| **phy1 interface** | **NOT YET VERIFIED** | Pending physical device test |
| **Monitor mode** | **NOT YET VERIFIED** | Pending physical device test |
| **Packet injection** | **NOT YET VERIFIED** | Pending physical device test |

> [!NOTE]
> The internal tablet Wi-Fi driver (`wlan_drv_gen4m_6768`, registering `phy0`) does **not** support monitor mode. External USB Wi-Fi via `ath9k_htc` (`phy1`) is intended to bring monitor mode capability to this tablet.

---

## Problem

When attaching an Atheros AR9271 adapter to the Lenovo Tab TB311FU running Android 15 GKI 6.6, USB transport and firmware initialization succeed completely:

```text
ath9k_htc: Firmware ath9k_htc/htc_9271-1.4.0.fw requested
ath9k_htc 1-1:1.0: ath9k_htc: Transferred FW: ath9k_htc/htc_9271-1.4.0.fw, size: 51008
ath9k_htc 1-1:1.0: HTC initialized with 33 credits
ath9k_htc 1-1:1.0: FW Version: 1.4
ath9k_htc 1-1:1.0: FW RMW support: On
ath: EEPROM regdomain: 0x64
```

However, initialization fails immediately afterward during wireless physical device registration.

### Failure Call Chain

```text
ath9k_hif_usb_firmware_cb()
        ↓
ath9k_htc_hw_init()
        ↓
ath9k_htc_probe_device()
        ↓
ieee80211_register_hw()
        ↓
wiphy_register()
```

In `net/wireless/core.c` within `wiphy_register()`, the vendor `cfg80211` module validates interface combinations declared by the driver:

```c
if (WARN_ON((wiphy->interface_modes & types) != types))
    return -EINVAL;
```

This validation triggers a kernel warning backtrace and causes `wiphy_register()` to return `-EINVAL` (-22). Consequently:
- `ath9k_htc` probe aborts with error `-22`.
- No secondary wireless physical device (`phy1`) is created.
- Only the built-in MediaTek `phy0` remains active.

---

## Why this patch exists

The patch modifies `drivers/net/wireless/ath/ath9k/htc_drv_init.c`:

```diff
--- a/drivers/net/wireless/ath/ath9k/htc_drv_init.c
+++ b/drivers/net/wireless/ath/ath9k/htc_drv_init.c
@@ -739,8 +739,8 @@ static void ath9k_set_hw_capab(struct ath9k_htc_priv *priv,
         BIT(NL80211_IFTYPE_MESH_POINT) |
         BIT(NL80211_IFTYPE_OCB);

-    hw->wiphy->iface_combinations = &if_comb;
-    hw->wiphy->n_iface_combinations = 1;
+    hw->wiphy->iface_combinations = NULL;
+    hw->wiphy->n_iface_combinations = 0;

     hw->wiphy->flags &= ~WIPHY_FLAG_PS_ON_BY_DEFAULT;
```

### Clarification
- This patch is **not** an upstream Linux kernel bugfix; it is a **device- and vendor-specific compatibility workaround**.
- The vendor `cfg80211.ko` shipped in the tablet's stock Android 15 firmware rejects the interface combinations structure declared by `ath9k_htc`.
- Setting `iface_combinations = NULL` and `n_iface_combinations = 0` bypasses the failing validation loop in `wiphy_register()` while keeping all individual supported interface modes in `hw->wiphy->interface_modes` intact.

---

## Compatibility

### Exact Target
- **Device**: Lenovo Tab TB311FU (`poplar`)
- **OS**: Stock Android 15 (ZUI 17)
- **Kernel Release**: `6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k`
- **Adapter**: Qualcomm Atheros AR9271 (`0cf3:9271`)

> [!WARNING]
> Linux kernel modules built with `CONFIG_MODVERSIONS` are strictly coupled to this exact kernel release and compiler symbol CRC table. Do not attempt to load these precompiled `.ko` files on unrelated devices or differing kernel builds.

---

## Installation

### Method 1: Building from Source Patch
Apply the patch directly to an Android Common Kernel `android15-6.6.57_r00` tree:
```bash
git apply patches/0001-wifi-ath9k_htc-disable-iface-combinations-on-TB311FU.patch
```
See [BUILDING.md](BUILDING.md) for full compilation steps and toolchain requirements.

### Method 2: Manual Loading for Testing
1. Download official firmware `htc_9271-1.4.0.fw` (see [release-assets/README.md](release-assets/README.md)) to `/data/local/tmp/ath9271/ath9k_htc/`.
2. Configure dynamic firmware search path:
   ```bash
   su
   echo -n "/data/local/tmp/ath9271" > /sys/module/firmware_class/parameters/path
   ```
3. Load the modules in strict dependency order:
   ```bash
   cd /data/local/tmp/ath9271
   insmod ath.ko
   insmod ath9k_hw.ko
   insmod ath9k_common.ko
   insmod ath9k_htc.ko
   ```

### Method 3: Magisk Persistence (Systemless Autoload)
To automatically load the drivers at boot without touching system partitions, use the Magisk module template provided in `magisk/`:
- See [magisk/README.md](magisk/README.md) for packaging and installation details.

---

## Verification

After inserting the modules and plugging in the AR9271 adapter via USB-OTG, verify system state:

```bash
# 1. Check kernel release
uname -r

# 2. Check module vermagic and dependencies
modinfo /path/to/ath9k_htc.ko

# 3. Check physical wireless chips (expect phy0 and phy1)
iw phy

# 4. Check wireless interfaces
iw dev

# 5. Inspect kernel initialization log
dmesg | grep -iE "(ath|htc|0cf3|wiphy)"
```

---

## Monitor Mode

Once `phy1` appears in `iw phy`, monitor mode can be configured:

```bash
# 1. Inspect supported modes on phy1
iw phy phy1 info

# 2. Add monitor interface
iw phy phy1 interface add mon1 type monitor

# 3. Bring interface UP
ip link set mon1 up

# 4. Verify link status
ip link show mon1
```

> [!IMPORTANT]
> Packet injection capability has **NOT YET BEEN VERIFIED** on physical hardware. Testing is ongoing.

---

## Repository Structure

```text
lenovo-tb311fu-ath9k-htc/
├── README.md               # Main project documentation
├── LICENSE                 # GNU General Public License v2.0
├── .gitignore              # Repository exclusion rules
├── COMPATIBILITY.md        # Hardware and kernel compatibility details
├── BUILDING.md             # Compilation instructions and KMI requirements
├── TROUBLESHOOTING.md      # Common failure cases and solutions
├── CHANGELOG.md            # Release and milestone tracking
├── CONTRIBUTING.md         # Contribution and hardware testing guidelines
├── patches/
│   └── 0001-wifi-ath9k_htc-disable-iface-combinations-on-TB311FU.patch
├── scripts/
│   ├── verify-module.sh    # Automated vermagic & 168-symbol CRC validator
│   ├── collect-device-info.sh # Read-only device diagnostic collector
│   └── package-release.sh  # Release packaging helper
├── config/
│   ├── device-info.txt
│   ├── kernel-release.txt
│   ├── expected-vermagic.txt
│   └── reference-symvers-ath9k_htc.txt
├── docs/
│   ├── TECHNICAL-NOTES.md  # Deep dive into GKI 2.0 and Kbuild isolation
│   ├── DEBUGGING.md        # Step-by-step diagnostic checklist
│   ├── BUILD-REPORT.md     # Static ABI and disassembly validation audit
│   └── DMESG-ANALYSIS.md   # Chronological log analysis of failure mode
├── magisk/
│   ├── README.md
│   ├── module.prop.example
│   └── service.sh.example
└── release-assets/
    └── README.md           # Instructions for binary downloads and packaging
```

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

### CONFIRMED (Hardware & Runtime on Lenovo TB311FU)
| Operation / Check | Status | Details |
|---|---|---|
| **USB 0cf3:9271 enumeration** | **CONFIRMED** | Atheros AR9271 detected cleanly over USB OTG |
| **Firmware request** | **CONFIRMED** | Driver requested `ath9k_htc/htc_9271-1.4.0.fw` |
| **Firmware transfer size 51008** | **CONFIRMED** | 51,008 bytes streamed via bulk OUT endpoint |
| **FW Version 1.4** | **CONFIRMED** | Target reports FW Version: 1.4, FW RMW support: On |
| **HTC initialized with 33 credits** | **CONFIRMED** | Host-Target Communication credit handshake established |
| **EEPROM/regulatory initialization** | **CONFIRMED** | EEPROM regdomain 0x0 read; mapped to regdmn/regpair 0x3a (US) |
| **Base module loading** | **CONFIRMED** | `ath.ko`, `ath9k_hw.ko`, `ath9k_common.ko` loaded successfully |
| **Original wiphy_register failure** | **CONFIRMED** | Stock driver failed at `wiphy_register()` with `-EINVAL` (-22) |
| **Patched ath9k_htc module loading** | **CONFIRMED** | Patched module loaded successfully on physical TB311FU |
| **Patched wiphy registration** | **CONFIRMED** | `wiphy_register()` completed successfully with patched driver |
| **External PHY** | **CONFIRMED** | External PHY registered cleanly (observed as `phy2` during tested session; PHY numbering is dynamic) |
| **Monitor mode** | **CONFIRMED** | `iw phy` reported monitor mode support; interface switched to monitor mode on channel 6 (2437 MHz) |
| **Passive packet capture** | **CONFIRMED** | Captured 20 IEEE802_11_RADIO packets via `tcpdump` (beacons, ACKs, data; 203 received by filter, 0 dropped) |

### STATICALLY VERIFIED (Build & ABI Validation)
| Property / Metric | Status | Details |
|---|---|---|
| **Patched ath9k_htc.ko build** | **STATICALLY VERIFIED** | Built cleanly via isolated Kbuild |
| **Exact vermagic** | **STATICALLY VERIFIED** | Matches `6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k SMP preempt mod_unload modversions aarch64` |
| **r510928 compiler** | **STATICALLY VERIFIED** | Android Clang r510928 (LLVM 18.0.0) |
| **168 reference imports** | **STATICALLY VERIFIED** | Exactly 168 imported symbols in `__versions` |
| **168 CRC matches** | **STATICALLY VERIFIED** | 168/168 (100%) symbol CRCs match reference table |
| **0 mismatch** | **STATICALLY VERIFIED** | 0 symbol CRC mismatches |
| **0 missing** | **STATICALLY VERIFIED** | 0 missing symbols |
| **Patch present in object/module** | **STATICALLY VERIFIED** | Disassembly proves `str xzr` and `str wzr` zeroing `iface_combinations` |

### NOT YET VERIFIED ON DEVICE (Runtime Device Validation)
| Operation / Feature | Status | Details |
|---|---|---|
| **Packet injection** | **NOT YET VERIFIED** | Pending verification with injection tools (attempted `aircrack-ng` installation failed due to unavailable Termux mirrors) |

> [!NOTE]
> The internal tablet Wi-Fi driver (`wlan_drv_gen4m_6768`, registering `phy0`) does **not** support monitor mode. External USB Wi-Fi via `ath9k_htc` brings confirmed monitor mode capability to this tablet.

---

## Problem

When attaching an Atheros AR9271 adapter to the Lenovo Tab TB311FU running Android 15 GKI 6.6, USB transport and firmware initialization succeed completely:

```text
ath9k_htc: Firmware ath9k_htc/htc_9271-1.4.0.fw requested
ath9k_htc 1-1:1.0: ath9k_htc: Transferred FW: ath9k_htc/htc_9271-1.4.0.fw, size: 51008
ath9k_htc 1-1:1.0: HTC initialized with 33 credits
ath9k_htc 1-1:1.0: FW Version: 1.4
ath9k_htc 1-1:1.0: FW RMW support: On
ath: EEPROM regdomain: 0x0
ath: EEPROM indicates default country code should be used
ath: country maps to regdmn code: 0x3a
ath: Country alpha2 being used: US
ath: Regpair used: 0x3a
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
- No external wireless physical device was registered prior to applying the patch.
- Only the built-in MediaTek `phy0` remained active.

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

### Firmware Installation (Confirmed Method on TB311FU)

> [!IMPORTANT]
> On the Lenovo Tab TB311FU, writing to `/sys/module/firmware_class/parameters/path` **DID NOT WORK**, even after setting SELinux to permissive mode. Do not rely on dynamic runtime firmware path redirection for this tablet.
>
> The **confirmed working method** on the physical TB311FU device is using a **Magisk vendor overlay**:
> ```text
> /vendor/firmware/ath9k_htc/htc_9271-1.4.0.fw
> ```
> By deploying the firmware blob through a Magisk module overlay (e.g. placed at `$MODDIR/system/vendor/firmware/ath9k_htc/htc_9271-1.4.0.fw`), the file appears at `/vendor/firmware/ath9k_htc/htc_9271-1.4.0.fw` upon boot. The kernel's standard firmware loader immediately locates it, and `ath9k_htc` successfully streams the 51,008-byte v1.4 firmware to the adapter.

### Method 1: Building from Source Patch
Apply the patch directly to an Android Common Kernel `android15-6.6.57_r00` tree:
```bash
git apply patches/0001-wifi-ath9k_htc-disable-iface-combinations-on-TB311FU.patch
```
See [BUILDING.md](BUILDING.md) for full compilation steps and toolchain requirements.

### Method 2: Manual Loading for Testing
1. Ensure the firmware image `htc_9271-1.4.0.fw` is available in `/vendor/firmware/ath9k_htc/` (via Magisk overlay).
2. Transfer the 4 compiled `.ko` files to the tablet (e.g. `/data/local/tmp/ath9271/`).
3. In a root shell (`su`), insert the modules in strict dependency order:
   ```bash
   cd /data/local/tmp/ath9271
   insmod ath.ko
   insmod ath9k_hw.ko
   insmod ath9k_common.ko
   insmod ath9k_htc.ko
   ```
*(Note: `/sys/module/firmware_class/parameters/path` is a generic desktop Linux fallback; on tested TB311FU it is **NOT WORKING / NOT TESTED AS WORKING**).*

### Method 3: Magisk Persistence (Systemless Autoload)
To automatically load the drivers at boot without touching system partitions and to provide the `/vendor/firmware` overlay, use the Magisk module template in `magisk/`:
- See [magisk/README.md](magisk/README.md) for packaging and installation details.

---

## Verification

After inserting the modules and plugging in the AR9271 adapter via USB-OTG, verify system state:

```bash
# 1. Check kernel release
uname -r

# 2. Check module vermagic and dependencies
modinfo /path/to/ath9k_htc.ko

# 3. Check physical wireless chips (expect phy0 and external PHY, e.g. phy2)
iw phy

# 4. Check wireless interfaces
iw dev

# 5. Inspect kernel initialization log
dmesg | grep -iE "(ath|htc|0cf3|wiphy)"
```

---

## Monitor Mode

Once the external PHY appears in `iw phy` (observed as `phy2` during the tested session; PHY numbering is dynamic and not fixed), monitor mode can be configured on the interface (observed as `wlan1` during testing; interface naming is dynamic):

```bash
# 1. Inspect supported modes on external PHY
iw phy <phyname> info

# 2. Switch interface to monitor mode
ip link set <ifname> down
iw dev <ifname> set type monitor
ip link set <ifname> up

# 3. Set channel (e.g. channel 6 / 2437 MHz)
iw dev <ifname> set channel 6

# 4. Verify link status
ip link show <ifname>
```

### Runtime verification example

Observed during the successful device test:

```text
phy2
└── wlan1
    type monitor
    channel 6 (2437 MHz)
```

tcpdump result:

```text
20 packets captured
203 packets received by filter
0 packets dropped
```

During this test, passive packet capture was performed with `adb shell su -c 'tcpdump -i wlan1 -e -s 256 -c 20'`, capturing 20 `IEEE802_11_RADIO` packets (frame types included beacons, acknowledgments, and data).

> [!IMPORTANT]
> Packet injection capability is **NOT YET VERIFIED**. An attempt to install `aircrack-ng` could not proceed due to unavailable Termux package mirrors, leaving packet injection unverified during this test session.

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

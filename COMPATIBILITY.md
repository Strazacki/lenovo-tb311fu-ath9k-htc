# Compatibility Matrix: Lenovo Tab TB311FU

This document details device, kernel, toolchain, and hardware compatibility for running the `ath9k_htc` driver on the Lenovo Tab TB311FU.

---

## 1. Target Device Specifications

| Specification | Value | Notes |
|---|---|---|
| **Device Model** | Lenovo Tab TB311FU | Also marketed as Lenovo Tab M11 |
| **Codename** | `poplar` | `POPLAR_ROW_WIFI` |
| **SoC** | MediaTek Helio G85 | MT8786V/N (2x Cortex-A75 + 6x Cortex-A55) |
| **Architecture** | `aarch64` (ARM64) | 4KB memory page size (`-4k` GKI variant) |
| **Android Version** | 15 | Stock Lenovo ZUI 17 |
| **Root Solution** | Magisk | Tested with Magisk v30.7 |

---

## 2. Kernel & KMI Specifications

| Parameter | Exact Value |
|---|---|
| **Kernel Release** | `6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k` |
| **GKI Standard** | Android GKI 2.0 (Generic Kernel Image 6.6) |
| **Required Vermagic** | `6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k SMP preempt mod_unload modversions aarch64` |
| **Official Compiler** | Android Clang `r510928` / LLVM 18.0.0 (`clang version 18.0.0 477610d4d0d988e69dbc3fae4fe86bff3f07f2b5`) |
| **Module Versioning** | `CONFIG_MODVERSIONS=y` (strict CRC check for all 168 imported symbols) |
| **Module Signatures** | `CONFIG_MODULE_SIG=y`, `CONFIG_MODULE_SIG_FORCE` is **not set** |

> [!WARNING]
> Precompiled kernel modules are strictly coupled to the exact kernel release string, vermagic, and compiler ABI. Loading them on different kernel versions or custom ROMs with differing kernel releases will cause `insmod` to fail with `Exec format error` or `Unknown symbol in module`.

---

## 3. Wi-Fi Hardware Specifications

### Built-in Tablet Wi-Fi
- **Driver**: `wlan_drv_gen4m_6768` (MediaTek proprietary vendor DLKM)
- **PHY Identifier**: `phy0`
- **Supported Modes**: Managed (station), AP, P2P
- **Monitor Mode**: **NOT supported** by the vendor driver or hardware stack.

### Target USB Wi-Fi Adapter
- **Chipset**: Qualcomm Atheros AR9271 (802.11b/g/n, 2.4 GHz)
- **USB Vendor & Product ID**: `0cf3:9271`
- **Common Adapters**:
  - Alfa AWUS036NHA (AR9271 chipset)
  - TP-Link TL-WN722N **v1 only** (v2 and v3 use Realtek RTL8188EUS/EU chipsets and are incompatible with ath9k_htc)
- **Driver**: `ath9k_htc` (requires dependency stack: `ath`, `ath9k_hw`, `ath9k_common`, `cfg80211`, `mac80211`, `rfkill`)
- **Firmware**: `ath9k_htc/htc_9271-1.4.0.fw` (Version 1.4, 51,008 bytes; deployed via Magisk overlay at `/vendor/firmware/ath9k_htc/htc_9271-1.4.0.fw`)
- **Target PHY Identifier**: External PHY (observed as `phy2` during the tested session; PHY numbering is dynamically assigned by the kernel)
- **Observed Interface**: `wlan1` (observed during testing; interface naming is dynamic)

---

## 4. Feature Status Matrix

### CONFIRMED (Hardware & Runtime on Lenovo TB311FU)
| Operation / Check | Status | Details |
|---|---|---|
| **USB 0cf3:9271 enumeration** | **CONFIRMED** | Device `0cf3:9271` enumerated cleanly over USB-OTG |
| **Firmware request** | **CONFIRMED** | Driver requested `ath9k_htc/htc_9271-1.4.0.fw` |
| **Firmware transfer size 51008** | **CONFIRMED** | 51,008 bytes streamed to device via bulk OUT endpoint |
| **FW Version 1.4** | **CONFIRMED** | Target responded with FW Version 1.4 and RMW support ON |
| **HTC initialized with 33 credits** | **CONFIRMED** | HTC credit handshake established |
| **EEPROM/regulatory initialization** | **CONFIRMED** | EEPROM regdomain 0x0 read; mapped to regdmn/regpair 0x3a (US) |
| **Base module loading** | **CONFIRMED** | `ath.ko`, `ath9k_hw.ko`, `ath9k_common.ko` loaded cleanly |
| **Original wiphy_register failure** | **CONFIRMED** | Stock `ath9k_htc` failed at `wiphy_register()` with `-EINVAL` (-22) |
| **Patched ath9k_htc module loading** | **CONFIRMED** | Patched module loaded cleanly on physical hardware |
| **Patched wiphy registration** | **CONFIRMED** | `wiphy_register()` completed successfully with patched driver |
| **External PHY** | **CONFIRMED** | External PHY registered cleanly (observed as `phy2` during tested session; PHY numbering is dynamic) |
| **Monitor mode** | **CONFIRMED** | `iw phy` reported monitor mode support; interface (`wlan1`) configured into monitor mode on channel 6 (2437 MHz) |
| **Passive packet capture** | **CONFIRMED** | Captured 20 IEEE802_11_RADIO packets (beacons, ACKs, data) via `tcpdump`; 203 packets received by filter, 0 dropped |

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

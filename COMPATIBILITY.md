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
- **Firmware**: `ath9k_htc/htc_9271-1.4.0.fw` (Version 1.4, 51,008 bytes)
- **Target PHY Identifier**: `phy1` (registered once `ath9k_htc` successfully probes)

---

## 4. Feature Status Matrix

| Component / Feature | Validation Status | Evidence / Notes |
|---|---|---|
| **USB Enumeration** | **CONFIRMED** | Device `0cf3:9271` enumerated cleanly over USB-OTG |
| **Firmware Request & Transfer** | **CONFIRMED** | 51,008 bytes streamed to device via bulk OUT endpoint |
| **Firmware v1.4 Execution** | **CONFIRMED** | Target responded with FW Version 1.4 and RMW support ON |
| **HTC Protocol Initialization** | **CONFIRMED** | HTC initialized with 33 credits |
| **EEPROM / Regdomain Read** | **CONFIRMED** | Read regpair `0x64` from adapter EEPROM |
| **ath9k_htc Module Loading** | **CONFIRMED** | Loaded cleanly with matching vermagic and symbol CRCs |
| **Original cfg80211 Registration Bug**| **CONFIRMED** | Stock `ath9k_htc` failed at `wiphy_register()` with `-EINVAL` |
| **Workaround Patch Build & ABI** | **CONFIRMED / TESTED** | Clean Kbuild, 168/168 matching CRCs, disassembly verified |
| **Patched wiphy Registration** | **NOT YET VERIFIED** | Awaiting device runtime `insmod` verification |
| **phy1 Interface Appearance** | **NOT YET VERIFIED** | Awaiting device runtime verification |
| **Monitor Mode (`mon1`)** | **NOT YET VERIFIED** | Awaiting device runtime verification |
| **Packet Injection** | **NOT YET VERIFIED** | Awaiting device runtime verification |

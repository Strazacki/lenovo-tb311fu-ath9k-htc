# Changelog

All notable changes and milestones for this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0-rc1] - 2026-09-12

### Added
- **Compatibility Patch**: `patches/0001-wifi-ath9k_htc-disable-iface-combinations-on-TB311FU.patch` disabling `iface_combinations` registration to bypass `wiphy_register()` rejection on Lenovo TB311FU vendor wireless stack.
- **Verification Tool**: `scripts/verify-module.sh` for automated static verification of kernel module vermagic, compiler comment metadata, and symbol-by-symbol `CONFIG_MODVERSIONS` CRCs.
- **Device Diagnostic Tool**: `scripts/collect-device-info.sh` for read-only system and wireless environment reporting.
- **Release Packaging Tool**: `scripts/package-release.sh` for packaging verified `.ko` binaries with `SHA256SUMS` and `BUILD-INFO.txt`.
- **Magisk Autoload Template**: Sample `module.prop` and `service.sh` for systemless early-boot module loading and dynamic firmware path registration.
- **Technical Documentation**:
  - `docs/TECHNICAL-NOTES.md`: Deep dive into GKI 2.0 KMI, `struct modversion_info`, and isolated Kbuild.
  - `docs/BUILD-REPORT.md`: Comprehensive static build verification report and disassembly audit.
  - `docs/DMESG-ANALYSIS.md`: Chronological breakdown of initialization stages and failure point.
  - `docs/DEBUGGING.md`: Practical step-by-step troubleshooting checklist.
  - `COMPATIBILITY.md`: Hardware, Android 15, and kernel version support matrix.

### Confirmed Milestones (CONFIRMED)
- **USB 0cf3:9271 enumeration**: Confirmed working for Atheros AR9271 (`0cf3:9271`).
- **Firmware request**: Confirmed requested `ath9k_htc/htc_9271-1.4.0.fw`.
- **Firmware transfer size 51008**: Confirmed 51,008 bytes streamed to device via Magisk overlay `/vendor/firmware/ath9k_htc/htc_9271-1.4.0.fw`.
- **FW Version 1.4**: Confirmed target responded with FW Version 1.4 and RMW support ON.
- **HTC initialization**: Confirmed working with 33 communication credits.
- **EEPROM/regulatory initialization**: Confirmed reading EEPROM regdomain `0x0`, mapping default country code to regdmn/regpair `0x3a` (US).
- **Base module loading**: Confirmed clean loading of `ath.ko`, `ath9k_hw.ko`, `ath9k_common.ko`.
- **Original wiphy_register failure**: Confirmed stock driver failed at `wiphy_register()` with `-EINVAL` (-22).

### Statically Verified Milestones (STATICALLY VERIFIED)
- **Patched ath9k_htc.ko build**: Built cleanly via isolated Kbuild.
- **Exact vermagic**: Matches `6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k SMP preempt mod_unload modversions aarch64`.
- **r510928 compiler**: Android Clang r510928 (LLVM 18.0.0).
- **Symbol versions**: 168 reference imports, 168 CRC matches, 0 mismatch, 0 missing.
- **Patch present in object/module**: Disassembly confirms `str xzr` and `str wzr` zeroing `iface_combinations`.

### Pending Verification (NOT YET VERIFIED ON DEVICE)
- Runtime verification of `wiphy_register()` success on physical tablet hardware with the patched driver.
- Detection and activation of `phy1`.
- Monitor mode interface creation (`mon1`).
- Raw packet injection.

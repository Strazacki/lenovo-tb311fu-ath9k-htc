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

### Confirmed Milestones
- **USB Enumeration**: Confirmed working for Atheros AR9271 (`0cf3:9271`).
- **Firmware Upload**: Confirmed working with open firmware `htc_9271-1.4.0.fw` (51,008 bytes).
- **HTC Initialization**: Confirmed working with 33 communication credits.
- **EEPROM / Calibration**: Confirmed reading regdomain `0x64`.
- **Base Module Stack**: Confirmed clean loading of `ath.ko`, `ath9k_hw.ko`, `ath9k_common.ko`.
- **Workaround Patch ABI Compliance**: 168/168 matching symbol CRCs, 0 mismatches, 0 missing.

### Pending Verification
- Runtime verification of `wiphy_register()` success on physical tablet hardware with the patched driver.
- Detection and activation of `phy1`.
- Monitor mode interface creation (`mon1`) and raw packet capture/injection.

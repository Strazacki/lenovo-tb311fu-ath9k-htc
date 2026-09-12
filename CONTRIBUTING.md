# Contributing Guidelines

Thank you for your interest in improving Atheros AR9271 / `ath9k_htc` support on the Lenovo Tab TB311FU and Android GKI devices!

---

## 1. How You Can Help

Currently, the most valuable contribution is **hardware runtime testing**:
- Flashing / test-loading the patched `ath9k_htc.ko` on the TB311FU.
- Verifying whether `wiphy_register()` completes and `phy1` appears in `iw phy`.
- Testing monitor mode creation and packet capture tools (tcpdump, airodump-ng).
- Testing packet injection capabilities.

---

## 2. Reporting Test Results

When submitting a hardware test report, please run our non-destructive diagnostic script:

```bash
# On device (root terminal or via adb shell):
sh ./scripts/collect-device-info.sh > device-report.txt
```

Include the generated report and the relevant section of `dmesg`:

```bash
dmesg | grep -iE "(ath|htc|wiphy|cfg80211|mac80211)"
```

---

## 3. Pull Request Guidelines

1. **Strict Upstream Alignment**: Changes should target compatibility with Android Common Kernel (ACK) branches.
2. **KMI & Vermagic Integrity**: Patches must not bypass security checks, fake vermagic, or strip `CONFIG_MODVERSIONS`.
3. **No Binary Commits**:
   - Do **NOT** commit compiled `.ko` binaries.
   - Do **NOT** commit binary firmware files (`.fw`).
4. **License Compliance**: All kernel patch contributions must be licensed under **GPL-2.0-only** or compatible open-source licenses.

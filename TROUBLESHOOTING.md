# Troubleshooting Guide

This guide addresses common errors and issues encountered when loading and using `ath9k_htc` on the Lenovo Tab TB311FU running Android 15 GKI 6.6.

---

## 1. Module Loading Issues

### Issue: `insmod: failed to load <module>.ko: Exec format error`
- **Error Code**: `-ENOEXEC` (-8)
- **Root Cause**:
  1. Module vermagic does not match the running kernel's exact vermagic string.
  2. Architecture mismatch (e.g. compiled for `x86_64` instead of `aarch64`).
- **Diagnosis**:
  ```bash
  # Check running kernel vermagic
  uname -r
  # Check module vermagic
  modinfo ath9k_htc.ko | grep vermagic
  # Run repository validation tool
  ./scripts/verify-module.sh ath9k_htc.ko
  ```
- **Resolution**:
  Recompile the module ensuring `KERNELRELEASE='6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k'` and that `utsrelease.h` was generated matching that exact string.

---

### Issue: `insmod: failed to load <module>.ko: Unknown symbol in module`
- **Error Code**: `-ENOEXEC` or symbol resolution failure
- **Root Cause**:
  1. A prerequisite dependency module has not been loaded yet.
  2. One or more symbol checksums disagree under `CONFIG_MODVERSIONS`.
- **Diagnosis**:
  Inspect the tail of the kernel log:
  ```bash
  dmesg | tail -n 25
  ```
  Look for lines like:
  - `ath9k_htc: Unknown symbol ath9k_hw_... (err -2)` -> Dependency `ath9k_hw.ko` not loaded yet.
  - `ath9k_htc: disagrees about version of symbol ieee80211_register_hw` -> Symbol CRC mismatch against vendor `mac80211.ko`.
- **Resolution**:
  1. Ensure the modules are loaded in strict sequence:
     ```bash
     insmod ath.ko
     insmod ath9k_hw.ko
     insmod ath9k_common.ko
     insmod ath9k_htc.ko
     ```
  2. Validate symbol CRCs with `./scripts/verify-module.sh ath9k_htc.ko` to detect any out-of-spec CRCs.

---

### Issue: `probe of 1-1:1.0 failed with error -22` (wiphy_register failure)
- **Error Code**: `-EINVAL` (-22)
- **Root Cause**:
  The unpatched driver submitted `iface_combinations` structures that the vendor `cfg80211` rejected in `wiphy_register()`.
- **Diagnosis**:
  Check `dmesg`:
  ```text
  WARNING: at net/wireless/core.c:... wiphy_register
  ath9k_htc: probe of 1-1:1.0 failed with error -22
  ```
- **Resolution**:
  Replace `ath9k_htc.ko` with the version built with the patch from `patches/0001-wifi-ath9k_htc-disable-iface-combinations-on-TB311FU.patch`.

---

## 2. Firmware Loading Issues

### Issue: `firmware: failed to load ath9k_htc/htc_9271-1.4.0.fw (-2)`
- **Error Code**: `-ENOENT` (-2)
- **Root Cause**:
  The kernel firmware loader cannot locate the firmware blob.
- **Diagnosis**:
  ```bash
  cat /sys/module/firmware_class/parameters/path
  ```
  If empty, the kernel will only look in default system directories (which on Android are read-only and lack third-party firmware).
- **Resolution**:
  1. Create folder `/data/local/tmp/ath9271/ath9k_htc/`.
  2. Copy `htc_9271-1.4.0.fw` into it.
  3. Inform the kernel where to look:
     ```bash
     echo -n "/data/local/tmp/ath9271" > /sys/module/firmware_class/parameters/path
     ```
  4. Reload `ath9k_htc.ko`.

---

## 3. Hardware & USB Issues

### Issue: Adapter plugged in but no USB activity in `dmesg`
- **Root Cause**:
  1. OTG cable or USB-C adapter does not support USB host mode (data lines missing).
  2. Port is locked in device/peripheral mode by Android USB manager.
  3. Insufficient power delivery for high-power Wi-Fi dongles.
- **Diagnosis**:
  ```bash
  lsusb
  ls -l /sys/bus/usb/devices/
  ```
- **Resolution**:
  - Test the OTG adapter with a standard USB flash drive first.
  - If using a high-power adapter (e.g. Alfa AWUS036NHA), use a powered USB-C hub or Y-cable.

---

## 4. Wireless Interface & Monitor Mode Issues

### Issue: `phy1` not present after loading modules
- **Diagnosis**:
  `ath9k_htc` firmware upload and probe is asynchronous.
  Run `dmesg | grep -i ath9k_htc` to see if firmware download completed.
- **Resolution**:
  Wait 2–3 seconds after `insmod ath9k_htc.ko` before checking `iw phy` or `iw dev`.

### Issue: Monitor interface creation fails with `Device or resource busy` (-EBUSY)
- **Diagnosis**:
  Android NetworkStack / wpa_supplicant might be trying to manage the new interface.
- **Resolution**:
  Bring down any managed interface created automatically on the new phy before creating `mon1`:
  ```bash
  ip link set <interface_name> down
  iw phy phy1 interface add mon1 type monitor
  ip link set mon1 up
  ```

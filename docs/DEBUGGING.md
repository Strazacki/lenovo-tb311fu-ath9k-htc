# Debugging & Diagnosis Guide: Android 15 GKI USB Wi-Fi

This guide provides practical diagnostic procedures for debugging `ath9k_htc` and USB wireless adapters on Android 15 GKI tablets like the Lenovo Tab TB311FU.

---

## 1. Quick Diagnostic Checklist

1. **Root shell**: Must be elevated root (`su`).
2. **USB OTG Connection**: Adapter enumerated in `lsusb` / `/sys/bus/usb/devices/`.
3. **Firmware Location**: `/vendor/firmware/ath9k_htc/htc_9271-1.4.0.fw` deployed via Magisk overlay.
4. **Dependency Modules**: `cfg80211`, `mac80211`, `rfkill` loaded.
5. **Module Order**: `ath` -> `ath9k_hw` -> `ath9k_common` -> `ath9k_htc`.
6. **Kernel Message Log**: Check `dmesg` immediately after `insmod`.

---

## 2. Inspecting USB Enumeration

Verify that the kernel detects the physical USB device:

```bash
# Check USB devices via sysfs
for dev in /sys/bus/usb/devices/*; do
    if [ -f "$dev/idVendor" ]; then
        echo "$(basename "$dev"): $(cat "$dev/idVendor"):$(cat "$dev/idProduct") - $(cat "$dev/product" 2>/dev/null)"
    fi
done
```

Expected entry for Atheros AR9271:
```text
1-1: 0cf3:9271 - USB2.0 WLAN
```

If the adapter is not shown:
- Verify that the USB-C adapter or OTG cable supports data (not charge-only).
- Check Android notification bar to see if USB host mode is enabled.
- Check `dmesg | grep -i usb` for port overcurrent or power errors.

---

## 3. Firmware Deployment: Magisk Overlay vs. firmware_class.path

### Confirmed Method on Lenovo TB311FU: Magisk Vendor Overlay
The stock Android 15 kernel on Lenovo TB311FU searches `/vendor/firmware` by default. Because the vendor partition is read-only, deploy the firmware using a Magisk module overlay:

```text
/data/adb/modules/<module_id>/system/vendor/firmware/ath9k_htc/htc_9271-1.4.0.fw
```

After reboot, verify the file is visible in the vendor filesystem:
```bash
ls -l /vendor/firmware/ath9k_htc/htc_9271-1.4.0.fw
```

### Note on `/sys/module/firmware_class/parameters/path`
Writing to `/sys/module/firmware_class/parameters/path` **DID NOT WORK** on the Lenovo Tab TB311FU, even when tested with SELinux permissive mode (`setenforce 0`). Do not rely on dynamic path modification on this device. It is considered **NOT WORKING ON TESTED TB311FU / UNVERIFIED FALLBACK ONLY**.

---

## 4. Controlled Module Insertion Order

The modules must be loaded in strict dependency order:

```bash
cd /data/local/tmp/ath9271

# 1. Base Atheros support
insmod ath.ko
# Verify: lsmod | grep ath

# 2. Hardware layer
insmod ath9k_hw.ko

# 3. Common routines
insmod ath9k_common.ko

# 4. USB HTC Driver (patched)
insmod ath9k_htc.ko
```

---

## 5. Interpreting Common Kernel Errors

### Error -2 (`ENOENT`: No such file or directory)
```text
ath9k_htc: Firmware ath9k_htc/htc_9271-1.4.0.fw requested
firmware_class: ath9k_htc/htc_9271-1.4.0.fw: firmware file not found
```
- **Cause**: Kernel firmware loader cannot find `ath9k_htc/htc_9271-1.4.0.fw` in default vendor search paths.
- **Fix**: Deploy the firmware through Magisk overlay to `/vendor/firmware/ath9k_htc/htc_9271-1.4.0.fw` and reboot. (Writing to `/sys/module/firmware_class/parameters/path` is non-functional on TB311FU).

### Error -8 (`ENOEXEC`: Exec format error)
```text
insmod: failed to load ath9k_htc.ko: Exec format error
```
- **Cause**: Vermagic mismatch or incompatible architecture (`aarch64` vs `x86_64`).
- **Fix**: Run `scripts/verify-module.sh` to compare vermagic and verify compiler toolchain matches `Android clang r510928`.

### Error -22 (`EINVAL`: Invalid argument)
During `insmod`:
- **Cause 1**: Symbol version CRC mismatch (`CONFIG_MODVERSIONS`). Check `dmesg | tail -n 20` for:
  `ath9k_htc: disagrees about version of symbol <sym>`
- **Cause 2**: Runtime probe failure, such as the `wiphy_register()` interface combination validation failure (`(wiphy->interface_modes & types) != types`).
- **Fix**: Ensure the patched `ath9k_htc.ko` is loaded and run `scripts/verify-module.sh` to confirm 168/168 CRC compliance.

---

## 6. Verifying Physical Wireless Interfaces

Once `ath9k_htc.ko` probe succeeds:

```bash
# List physical wireless chips
iw phy

# List wireless interfaces
iw dev
```

Look for a new external physical device (observed as `phy2` during testing; PHY numbering is dynamic), in addition to the tablet's built-in `phy0`. The corresponding wireless interface was observed as `wlan1` during testing (interface names are dynamic).

---

## 7. Monitor Mode Validation Workflow

When the external PHY is successfully registered:

```bash
# 1. Inspect supported modes on external PHY (e.g. phy2)
iw phy <phyname> info | grep -A 10 "Supported interface modes"

# 2. Switch interface to monitor mode (or add monitor interface)
ip link set <ifname> down
iw dev <ifname> set type monitor
ip link set <ifname> up

# 3. Set channel (e.g. channel 6 / 2437 MHz)
iw dev <ifname> set channel 6

# 4. Verify link status
ip link show <ifname>
```

### Confirmed Passive Packet Capture
Passive packet capture was verified on the physical Lenovo TB311FU using `tcpdump` on `wlan1`:

```bash
adb shell su -c 'tcpdump -i wlan1 -e -s 256 -c 20'
```

Output confirmed:
- 20 `IEEE802_11_RADIO` packets captured (including beacons, acknowledgments, and data frames)
- 203 packets received by filter
- 0 packets dropped

*Note*: Packet injection remains **NOT YET VERIFIED** (an attempt to install `aircrack-ng` via Termux failed because Termux package mirrors were unreachable).

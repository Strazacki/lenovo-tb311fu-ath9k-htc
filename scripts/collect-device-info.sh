#!/bin/sh
#
# collect-device-info.sh - Non-destructive, read-only system & Wi-Fi diagnostic collector
#
# Intended to be run on Lenovo Tab TB311FU (via root shell / ADB / Termux)
# Does NOT modify any file, partition, module, or system state.
#
set -u

echo "======================================================================"
echo " Lenovo TB311FU / AR9271 Diagnostic Collection"
echo " Timestamp (UTC): $(date -u '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)"
echo " Running User:    $(id 2>/dev/null || whoami 2>/dev/null || echo 'unknown')"
echo "======================================================================"

echo ""
echo "=== 1. System & Kernel Information ==="
echo "uname -a:"
uname -a 2>/dev/null || echo "uname command failed"

echo ""
echo "uname -r:"
uname -r 2>/dev/null || echo "uname -r failed"

echo ""
echo "/proc/version:"
if [ -r /proc/version ]; then
    cat /proc/version
else
    echo "Cannot read /proc/version"
fi

echo ""
echo "=== 2. Android Build Properties ==="
for prop in \
    ro.product.brand \
    ro.product.manufacturer \
    ro.product.model \
    ro.product.device \
    ro.product.name \
    ro.board.platform \
    ro.build.version.release \
    ro.build.version.sdk \
    ro.build.version.incremental \
    ro.build.fingerprint \
    ro.build.date
do
    val="$(getprop "$prop" 2>/dev/null || true)"
    if [ -n "$val" ]; then
        printf "%-30s: %s\n" "$prop" "$val"
    fi
done

echo ""
echo "=== 3. Kernel Configuration (/proc/config.gz) ==="
if [ -r /proc/config.gz ]; then
    echo "Found /proc/config.gz. Inspecting key module flags:"
    zcat /proc/config.gz 2>/dev/null | grep -E "^(CONFIG_MODULES|CONFIG_MODVERSIONS|CONFIG_MODULE_SIG|CONFIG_MODULE_SIG_FORCE|CONFIG_CFG80211|CONFIG_MAC80211|CONFIG_ATH)" || \
    gzip -dc /proc/config.gz 2>/dev/null | grep -E "^(CONFIG_MODULES|CONFIG_MODVERSIONS|CONFIG_MODULE_SIG|CONFIG_MODULE_SIG_FORCE|CONFIG_CFG80211|CONFIG_MAC80211|CONFIG_ATH)" || \
    echo "Could not decompress /proc/config.gz"
else
    echo "/proc/config.gz not present or not readable."
fi

echo ""
echo "=== 4. Loaded Kernel Modules (lsmod / /proc/modules) ==="
if [ -r /proc/modules ]; then
    cat /proc/modules
elif command -v lsmod >/dev/null 2>&1; then
    lsmod
else
    echo "Neither /proc/modules nor lsmod available."
fi

echo ""
echo "=== 5. Wireless Interfaces (iw dev) ==="
if command -v iw >/dev/null 2>&1; then
    iw dev 2>&1 || echo "iw dev returned non-zero"
else
    echo "iw binary not found in PATH."
fi

echo ""
echo "=== 6. Wireless Physical Devices (iw phy) ==="
if command -v iw >/dev/null 2>&1; then
    iw phy 2>&1 || echo "iw phy returned non-zero"
else
    echo "iw binary not found in PATH."
fi

echo ""
echo "=== 7. Network Interfaces (ip link / ifconfig) ==="
if command -v ip >/dev/null 2>&1; then
    ip link show 2>&1
elif command -v ifconfig >/dev/null 2>&1; then
    ifconfig -a 2>&1
else
    echo "Neither ip nor ifconfig available."
fi

echo ""
echo "=== 8. USB Devices & Atheros AR9271 Identification ==="
if command -v lsusb >/dev/null 2>&1; then
    echo "lsusb output:"
    lsusb 2>&1
fi

echo ""
echo "Sysfs USB enumeration (/sys/bus/usb/devices/*):"
if [ -d /sys/bus/usb/devices ]; then
    found_usb=0
    for dev in /sys/bus/usb/devices/*; do
        if [ -f "$dev/idVendor" ] && [ -f "$dev/idProduct" ]; then
            vid="$(cat "$dev/idVendor" 2>/dev/null || echo '????')"
            pid="$(cat "$dev/idProduct" 2>/dev/null || echo '????')"
            mfg="$(cat "$dev/manufacturer" 2>/dev/null || echo '')"
            prod="$(cat "$dev/product" 2>/dev/null || echo '')"
            echo "Device: $(basename "$dev") -> ID ${vid}:${pid} [${mfg}] ${prod}"
            if [ "$vid" = "0cf3" ] && [ "$pid" = "9271" ]; then
                echo "  *** MATCH: Atheros AR9271 detected! ***"
            fi
            found_usb=1
        fi
    done
    if [ "$found_usb" -eq 0 ]; then
        echo "No USB device nodes with idVendor/idProduct found."
    fi
else
    echo "/sys/bus/usb/devices directory not accessible."
fi

echo ""
echo "=== 9. Firmware Loader Search Path ==="
if [ -r /sys/module/firmware_class/parameters/path ]; then
    fw_path="$(cat /sys/module/firmware_class/parameters/path 2>/dev/null || echo 'unreadable')"
    echo "firmware_class.path: '${fw_path}'"
else
    echo "/sys/module/firmware_class/parameters/path not accessible."
fi

echo ""
echo "=== 10. Relevant dmesg Filter (ath / htc / cfg80211) ==="
if command -v dmesg >/dev/null 2>&1; then
    dmesg 2>/dev/null | grep -iE "(ath|htc|0cf3|wiphy|cfg80211|mac80211|wlan)" | tail -n 50 || echo "dmesg restricted or empty"
else
    echo "dmesg command not found."
fi

echo ""
echo "======================================================================"
echo " Diagnostic collection finished."
echo "======================================================================"

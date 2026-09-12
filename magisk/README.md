# Magisk Autoload Module Template: Lenovo TB311FU ath9k_htc

This directory provides a template for creating a persistent, systemless Magisk module to automatically load the Atheros AR9271 drivers at boot time without modifying `/system` or `/vendor` partitions.

---

## 1. Directory Structure of a Flashable Magisk Module

When building the Magisk module zip:

```text
tb311fu-ath9k-magisk/
├── module.prop                # Module metadata (name, version, id)
├── service.sh                 # Background service script run late in boot
├── modules/                   # Directory containing the 4 kernel modules
│   ├── ath.ko
│   ├── ath9k_hw.ko
│   ├── ath9k_common.ko
│   └── ath9k_htc.ko
└── firmware/                  # Directory containing the open firmware
    └── ath9k_htc/
        └── htc_9271-1.4.0.fw
```

---

## 2. Kernel Module Placement & Loading Order

The 4 `.ko` files reside inside the module's private directory on the `/data` partition (e.g. `/data/adb/modules/tb311fu_ath9k/modules/`).

The kernel requires that the modules be loaded in strict dependency sequence:

1. **`ath.ko`**: Base Atheros wireless abstractions and regulatory helpers.
2. **`ath9k_hw.ko`**: Atheros 9000-series hardware abstraction layer.
3. **`ath9k_common.ko`**: Common Atheros 802.11 MAC operations and rate control.
4. **`ath9k_htc.ko`**: Patched USB Host-Target Communication transport driver.

---

## 3. Firmware Placement & Kernel Search Path

The AR9271 USB adapter dynamically requests `ath9k_htc/htc_9271-1.4.0.fw` when plugged in.

The boot script in `service.sh` automatically configures the kernel's dynamic firmware search parameter before inserting the driver:

```sh
echo -n "/data/adb/modules/tb311fu_ath9k/firmware" > /sys/module/firmware_class/parameters/path
```

This guarantees the kernel firmware loader can locate the firmware image without altering the read-only vendor partition `/vendor/firmware`.

---

## 4. Usage Instructions

1. Copy `magisk/module.prop.example` to `module.prop` and customize if desired.
2. Copy `magisk/service.sh.example` to `service.sh` and ensure executable permissions (`chmod +x service.sh`).
3. Place your verified `.ko` files into `modules/`.
4. Place the official `htc_9271-1.4.0.fw` into `firmware/ath9k_htc/`.
5. Create a flashable zip:
   ```bash
   zip -r9 tb311fu-ath9k-magisk.zip module.prop service.sh modules/ firmware/
   ```
6. Flash via **Magisk App** -> **Modules** -> **Install from storage**.
7. Reboot the tablet.

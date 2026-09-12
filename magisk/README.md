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
└── system/                    # Magisk systemless overlay for vendor partition
    └── vendor/
        └── firmware/
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

## 3. Firmware Placement & Magisk Vendor Overlay

The AR9271 USB adapter dynamically requests `ath9k_htc/htc_9271-1.4.0.fw` upon USB attachment.

### Confirmed Method on TB311FU
On the Lenovo Tab TB311FU, attempting to redirect the firmware path via `/sys/module/firmware_class/parameters/path` **DID NOT WORK**, even with SELinux in permissive mode.

The **confirmed working procedure** is deploying the firmware via Magisk's systemless vendor overlay:
1. Place the firmware blob inside the module directory at:
   `system/vendor/firmware/ath9k_htc/htc_9271-1.4.0.fw`
2. Upon device boot, Magisk automatically overlays this file into:
   `/vendor/firmware/ath9k_htc/htc_9271-1.4.0.fw`
3. Because `/vendor/firmware` is the default firmware search location of the GKI kernel, `ath9k_htc` detects and transfers the firmware blob cleanly.

---

## 4. Usage Instructions

1. Copy `magisk/module.prop.example` to `module.prop` and customize if desired.
2. Copy `magisk/service.sh.example` to `service.sh` and ensure executable permissions (`chmod +x service.sh`).
3. Place your verified `.ko` files into `modules/`.
4. Place the official `htc_9271-1.4.0.fw` into `system/vendor/firmware/ath9k_htc/`.
5. Create a flashable zip:
   ```bash
   zip -r9 tb311fu-ath9k-magisk.zip module.prop service.sh modules/ system/
   ```
6. Flash via **Magisk App** -> **Modules** -> **Install from storage**.
7. Reboot the tablet.

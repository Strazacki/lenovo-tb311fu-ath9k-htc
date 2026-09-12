# Technical Notes: Android 15 GKI 6.6 Kernel Module Porting

This document outlines the technical architecture, Kernel Module Interface (KMI) constraints, symbol versioning (`CONFIG_MODVERSIONS`), and build mechanics involved in running the `ath9k_htc` driver on the Lenovo Tab TB311FU (MediaTek Helio G85, Android 15 GKI 6.6).

---

## 1. Android GKI 2.0 Module Architecture

Android Generic Kernel Image (GKI) 2.0 decouples the generic core kernel from SoC- and board-specific device drivers:
- Core kernel is delivered as a standardized `boot.img` GKI artifact.
- Drivers are delivered as dynamically loadable kernel modules (`.ko`) residing in vendor partitions (`vendor_dlkm`, `system_dlkm`).
- Strict KMI enforcement ensures binary compatibility between the generic kernel and vendor modules.

On the Lenovo Tab TB311FU:
- Core GKI kernel release: `6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k`
- Target architecture: `aarch64` (ARM64, 4KB page size)
- Wireless vendor modules present:
  - `cfg80211.ko` (Vendor DLKM)
  - `mac80211.ko` (Vendor DLKM)
  - `wlan_drv_gen4m_6768.ko` (MediaTek internal Wi-Fi driver, registers `phy0`)

---

## 2. Vermagic and Signature Verification

### Vermagic String
When `insmod` or `finit_module` loads a kernel module, the kernel validates the `vermagic` string stored in the `.modinfo` ELF section. For this device, the vermagic must match byte-for-byte:

```text
6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k SMP preempt mod_unload modversions aarch64
```

Components breakdown:
- `6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k`: Kernel release version string (`utsrelease.h`).
- `SMP`: Symmetric Multi-Processing enabled (`CONFIG_SMP=y`).
- `preempt`: Preemption model (`CONFIG_PREEMPT=y` / `CONFIG_PREEMPTION=y`).
- `mod_unload`: Module unloading enabled (`CONFIG_MODULE_UNLOAD=y`).
- `modversions`: Symbol checksum verification enabled (`CONFIG_MODVERSIONS=y`).
- `aarch64`: Architecture identifier.

### Module Signing Policy
Inspection of running kernel configuration (`/proc/config.gz`) reveals:

```text
CONFIG_MODULE_SIG=y
# CONFIG_MODULE_SIG_FORCE is not set
CONFIG_MODULE_SIG_ALL=y
CONFIG_MODULE_SIG_SHA1=y
```

Because `CONFIG_MODULE_SIG_FORCE` is **not set**, the kernel logs an unsigned module notice and taints the kernel (`TAINT_UNSIGNED_MODULE`, flag `E`), but **does not reject** loading validly compiled modules with matching vermagic and symbol CRCs.

---

## 3. Symbol Versioning (`CONFIG_MODVERSIONS`) Mechanics

`CONFIG_MODVERSIONS` guarantees that data structures and function prototypes used by a module match the exact ABI of the running kernel.

### The `__versions` ELF Section
On 64-bit ARM (`aarch64`), each imported symbol has a 64-byte entry in the `.rodata` or `__versions` ELF section defined by `struct modversion_info`:

```c
struct modversion_info {
    unsigned long crc;
    char name[MODULE_NAME_LEN]; /* 56 bytes */
};
```

1. **CRC Calculation**: During kernel build, `genksyms` computes a 32-bit CRC based on the C type definitions and prototypes of exported symbols (`EXPORT_SYMBOL`).
2. **Kbuild Modpost**: During module compilation, `modpost` resolves unresolved symbols against `Module.symvers` and embeds the expected CRC into the module's `__versions` table.
3. **Kernel Loading Verification**: When the module is loaded, the kernel checks each imported symbol against its internal exported symbol table. If any symbol's CRC does not match, module loading fails immediately with `Exec format error` or `Unknown symbol in module`.

### ath9k_htc Symbol Analysis
The unpatched reference module and the patched `ath9k_htc.ko` both import exactly **168 symbols**:
- 104 symbols from `Module.symvers.device` (device vendor modules & GKI core)
- 59 symbols from `drivers/net/wireless/ath/Module.symvers` (`ath.ko`, `ath9k_hw.ko`, `ath9k_common.ko`)
- 5 symbols from core kernel `Module.symvers`
- **Result**: 168 matches, 0 mismatches, 0 missing.

---

## 4. Kbuild External Module Isolation

### The Duplicate Export Dilemma
Standard in-tree compilation of `M=drivers/net/wireless/ath/ath9k` causes `kbuild` to compile and export symbols for `ath9k_hw` and `ath9k_common` alongside `ath9k_htc`. When passing pre-existing symbol definitions via `Module.symvers`, `modpost` detects duplicate symbol definitions:

```text
drivers/net/wireless/ath/ath9k/ath9k_hw: duplicate symbol 'ath9k_hw_...'
```

### The Isolated Build Tree Solution
To compile *only* `ath9k_htc.ko` without rebuilding or corrupting symbol exports of the other three working modules:
1. An isolated workspace (`WORK/ext`) is constructed containing only the 8 source objects required for `ath9k_htc`:
   - `htc_drv_main.o`
   - `htc_drv_beacon.o`
   - `htc_drv_init.o`
   - `htc_drv_gpio.o`
   - `htc_drv_txrx.o`
   - `htc_drv_debug.o`
   - `wmi.o`
   - `htc_hst.o`
2. C source files are linked via relative symlinks directly to `kernel-src`.
3. A single, deduplicated `Module.symvers` (19,263 unique symbols) is provided in the build output directory (`WORK/kout/Module.symvers`).
4. `KBUILD_EXTRA_SYMBOLS` is omitted so `modpost` reads only the merged table.

### Makefile.modpost `findstring i` Quirk
During GKI external module compilation with `KERNELRELEASE=6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k`, Kbuild's `scripts/Makefile.modpost` contained:

```make
ifneq ($(findstring i, $(filter-out --%,$(MAKEFLAGS))),)
```

The letter `i` in `android` inside `KERNELRELEASE` within `MAKEFLAGS` was inadvertently matched as the Make `-i` (ignore errors) flag! This triggered modpost to pass `-n` (dry-run mode), which prevented `.mod.c` generation. Resolving this condition in the build environment restored standard `.mod.c` compilation and final `.ko` linking.

---

## 5. Disassembly Verification of the Workaround

To prove that the binary `ath9k_htc.ko` actually contains the workaround and was not linked against stale object caches:

In `drivers/net/wireless/ath/ath9k/htc_drv_init.c`:
```c
/* Lines 742-743 */
hw->wiphy->iface_combinations = NULL;
hw->wiphy->n_iface_combinations = 0;
```

Disassembly of `htc_drv_init.o` (`llvm-objdump -d -l`):
```asm
; hw->wiphy->iface_combinations = NULL;
str   xzr, [x8, #0x50]
; hw->wiphy->n_iface_combinations = 0;
str   wzr, [x8, #0x58]
```

- Register `xzr` (zero register, 64-bit) is stored at offset `0x50` (`iface_combinations`).
- Register `wzr` (zero register, 32-bit) is stored at offset `0x58` (`n_iface_combinations`).
- DWARF line debug sections confirm direct mapping to source lines 742 and 743.

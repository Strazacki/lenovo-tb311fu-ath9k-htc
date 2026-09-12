# Build and Static ABI Validation Report

- **Date of Validation**: 2026-09-12
- **Result**: **PASS — Statically and ABI-validated for controlled test loading on Lenovo Tab TB311FU**
- **Target Kernel**: `6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k`
- **Compiler**: Android Clang `r510928` / LLVM 18.0.0

---

## 1. Artifact Summary

| Property | Reference Module (`out/`) | Patched Module (`out-patched/`) | Status |
|---|---|---|---|
| **Filename** | `ath9k_htc.ko` | `ath9k_htc.ko` | — |
| **Size** | 2,417,208 bytes | 2,268,208 bytes | — |
| **SHA-256** | `2349497d2af018675eb9d789863cc8e5b9ddf8022399cf2843139bd472fe1c7a` | `c9683f1bf97a39da604d5bbcee94734ed4c348d94234398993025b4624eb5c94` | — |
| **Vermagic** | `6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k SMP preempt mod_unload modversions aarch64` | `6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k SMP preempt mod_unload modversions aarch64` | **MATCH** |
| **Compiler ID** | Android Clang r510928 (LLVM 18.0.0) | Android Clang r510928 (LLVM 18.0.0) | **MATCH** |
| **Dependencies**| `mac80211,ath9k_hw,ath,ath9k_common,cfg80211,rfkill` | `mac80211,ath9k_hw,ath,ath9k_common,cfg80211,rfkill` | **MATCH** |
| **Imported Syms**| 168 | 168 | **MATCH** |
| **CRC Matches** | 168 / 168 | 168 / 168 | **100% PASS** |
| **CRC Mismatches**| 0 | 0 | **0** |
| **Missing Syms** | 0 | 0 | **0** |

---

## 2. Compilation Environment & Exact Commands

### Toolchain
- Clang prebuilt: Google Android prebuilt Clang `r510928`
- LLVM version: `clang version 18.0.0 (https://android.googlesource.com/toolchain/llvm-project 477610d4d0d988e69dbc3fae4fe86bff3f07f2b5)`

### Kbuild Execution
Isolated out-of-tree module compilation command:

```bash
REL='6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k'
TOOLBIN="/path/to/android-clang/clang-r510928/bin"
WORK="/path/to/isolated-work"

# 1. Generate kernel release header in build directory
PATH="$TOOLBIN:$PATH" make \
  -C "$WORK/ksrc-clean" \
  O="$WORK/kout" \
  ARCH=arm64 \
  LLVM=1 \
  KERNELRELEASE="$REL" \
  include/config/kernel.release include/generated/utsrelease.h

# 2. Compile external ath9k_htc module against merged Module.symvers
PATH="$TOOLBIN:$PATH" make \
  -C "$WORK/ksrc-clean" \
  O="$WORK/kout" \
  ARCH=arm64 \
  LLVM=1 \
  KERNELRELEASE="$REL" \
  M="$WORK/ext" \
  V=1 \
  modules
```

Build exited with status code `0`, completing standard `MODPOST`, `ath9k_htc.mod.o` compilation, and ELF linking.

---

## 3. Symbol Versioning (`CONFIG_MODVERSIONS`) Results

### Symbol Source Attribution
The 168 imported symbols in `ath9k_htc.ko` resolve to the following verified sources:
- **`Module.symvers.device`**: 104 symbols (derived from device vendor modules including `cfg80211.ko` and `mac80211.ko`)
- **`drivers/net/wireless/ath/Module.symvers`**: 59 symbols (`ath.ko`, `ath9k_hw.ko`, `ath9k_common.ko`)
- **Core GKI `Module.symvers`**: 5 symbols (`device_release_driver`, `usb_bulk_msg`, `usb_interrupt_msg`, `usb_kill_anchored_urbs`, `usb_unanchor_urb`)

### Verification Summary
```text
reference imports: 168
match:             168
mismatch:            0
missing:             0
```

Both the merged `Module.symvers` and the linked `ath9k_htc.ko` satisfy the strict `168 match / 0 mismatch / 0 missing` requirement.

---

## 4. Binary Disassembly Proof of Patch

To confirm that the patch was incorporated into the linked binary:

Source diff (`drivers/net/wireless/ath/ath9k/htc_drv_init.c`):
```c
-	hw->wiphy->iface_combinations = &if_comb;
-	hw->wiphy->n_iface_combinations = 1;
+	hw->wiphy->iface_combinations = NULL;
+	hw->wiphy->n_iface_combinations = 0;
```

Disassembly of `htc_drv_init.o` (`llvm-objdump -d -l`):
```asm
; hw->wiphy->iface_combinations = NULL;
str   xzr, [x8, #0x50]
; hw->wiphy->n_iface_combinations = 0;
str   wzr, [x8, #0x58]
```

DWARF line tables correlate these zeroing instructions directly to source lines 742 and 743.

---

## 5. Notes on BTF (BPF Type Format)

The reference module in `out/` contains a `.BTF` ELF section. The newly built patched module does not include `.BTF` because compilation occurred in an isolated external Kbuild tree without a full `vmlinux` BTF base.

Kbuild issued a standard notice:
`Skipping BTF generation for ... due to unavailable vmlinux`

BTF contains type and debugging information used by eBPF programs. The absence of `.BTF` has zero effect on `insmod` compatibility, vermagic validation, or `CONFIG_MODVERSIONS` CRC enforcement.

---

## 6. Scope of Validation

- **Static Compatibility**: **CONFIRMED / PASS** (vermagic, compiler string, symbol CRCs, ELF relocation).
- **Driver Workaround Implementation**: **CONFIRMED** (binary disassembly verified).
- **Runtime Execution on Device**: **NOT YET VERIFIED** (runtime `insmod`, `wiphy_register()`, `phy1` creation, and monitor mode remain to be tested on the physical device).

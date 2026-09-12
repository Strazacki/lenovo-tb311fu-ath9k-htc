# Building `ath9k_htc` for Lenovo Tab TB311FU (Android 15 GKI 6.6)

This document provides complete instructions for building the patched `ath9k_htc.ko` driver and its dependencies for the Lenovo Tab TB311FU, adhering to Android GKI 2.0 KMI requirements.

---

## 1. Why Building for Android GKI Requires Precision

Unlike generic desktop Linux, Android GKI enforces strict binary interface checks:

### A. Exact Vermagic String
The kernel inspects the `.modinfo` ELF section. If the vermagic does not match the running kernel byte-for-byte, `insmod` fails immediately with `Exec format error`:

```text
6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k SMP preempt mod_unload modversions aarch64
```

### B. The Role of `CONFIG_MODVERSIONS`
`CONFIG_MODVERSIONS` guarantees that function signatures, struct layouts, and enum definitions match between the compiled module and the running kernel.

- When compiling C code, `genksyms` hashes AST prototypes to calculate a 32-bit CRC for every symbol.
- These CRCs are embedded into the module's `__versions` ELF section.
- **Why faking vermagic or binary-patching strings fails**:
  Even if the vermagic string is edited in a hex editor, the kernel checks every entry in `__versions` during `finit_module()`. If any single symbol CRC mismatches, the kernel aborts with:
  `ath9k_htc: disagrees about version of symbol <symbol_name>`

### C. Exact Toolchain: Android Clang r510928
To ensure that struct padding, alignment, and calling conventions match the vendor GKI build, the exact official Google Android Clang toolchain must be used:

- **Version**: Android Clang `r510928` / LLVM 18.0.0
- **Full identifier**: `Android (11209041, +pgo, +bolt, +lto, +mlgo, based on r510928) clang version 18.0.0`
- **Git Commit**: `https://android.googlesource.com/toolchain/llvm-project 477610d4d0d988e69dbc3fae4fe86bff3f07f2b5`

---

## 2. Required Validation Threshold

Before any module is considered suitable for loading, it must pass verification against the reference symbol table:

```text
reference imports: 168
matching CRCs:     168
mismatches:          0
missing:             0
```

- **Reference imports**: 168 symbols
- **Matching CRCs**: 168 symbols (100%)
- **Mismatches**: 0
- **Missing**: 0

Do not strip `CONFIG_MODVERSIONS`, do not force module loading with `--force`, and do not tamper with binary metadata.

---

## 3. Build Environment Setup

### Prerequisites
1. **Host OS**: Linux (x86_64 or aarch64)
2. **Android Clang r510928**: Download prebuilt toolchain from Google:
   ```bash
   git clone --depth=1 https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 android-clang
   # Or extract clang-r510928 specifically
   ```
3. **Android Common Kernel Source**:
   ```bash
   git clone -b android15-6.6.57_r00 --depth=1 https://android.googlesource.com/kernel/common kernel-src
   ```
4. **Running Kernel Configuration**:
   Extracted from device `/proc/config.gz`:
   ```bash
   zcat /proc/config.gz > kernel-src/.config
   ```

---

## 4. Applying the Compatibility Patch

Apply the patch from this repository to disable `iface_combinations` registration:

```bash
cd kernel-src
git apply ../patches/0001-wifi-ath9k_htc-disable-iface-combinations-on-TB311FU.patch
```

This modifies `drivers/net/wireless/ath/ath9k/htc_drv_init.c`:
```diff
-	hw->wiphy->iface_combinations = &if_comb;
-	hw->wiphy->n_iface_combinations = 1;
+	hw->wiphy->iface_combinations = NULL;
+	hw->wiphy->n_iface_combinations = 0;
```

---

## 5. Compiling `ath9k_htc.ko` (Isolated External Module Build)

To avoid duplicate symbol conflicts with in-tree `ath`, `ath9k_hw`, and `ath9k_common`, compile `ath9k_htc` in an isolated external workspace.

### Step 1: Create Isolated Workspace
```bash
WORK="$PWD/build-isolated"
mkdir -p "$WORK/ext" "$WORK/kout"

# Symlink required HTC sources
for f in htc_drv_main.c htc_drv_beacon.c htc_drv_init.c htc_drv_gpio.c \
         htc_drv_txrx.c htc_drv_debug.c wmi.c htc_hst.c; do
    ln -sf "$PWD/kernel-src/drivers/net/wireless/ath/ath9k/$f" "$WORK/ext/$f"
done
ln -sf "$PWD/kernel-src/drivers/net/wireless/ath/ath9k/ath9k.h" "$WORK/ext/ath9k.h"

# Create minimal external Makefile
cat << 'EOF' > "$WORK/ext/Makefile"
obj-m := ath9k_htc.o
ath9k_htc-y := htc_drv_main.o htc_drv_beacon.o htc_drv_init.o htc_drv_gpio.o \
               htc_drv_txrx.o htc_drv_debug.o wmi.o htc_hst.o
ccflags-y += -I$(srctree)/drivers/net/wireless/ath/ath9k \
             -I$(srctree)/drivers/net/wireless/ath
EOF
```

### Step 2: Prepare `Module.symvers`
Copy the merged, deduplicated `Module.symvers` (containing device vendor module symbols and core GKI symbols) to:
```bash
cp /path/to/merged/Module.symvers "$WORK/kout/Module.symvers"
```

### Step 3: Generate Kernel Release Headers
```bash
REL='6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k'
TOOLBIN="/path/to/android-clang/bin"

PATH="$TOOLBIN:$PATH" make \
  -C "$PWD/kernel-src" \
  O="$WORK/kout" \
  ARCH=arm64 \
  LLVM=1 \
  KERNELRELEASE="$REL" \
  include/config/kernel.release include/generated/utsrelease.h
```

### Step 4: Compile the Module
```bash
PATH="$TOOLBIN:$PATH" make \
  -C "$PWD/kernel-src" \
  O="$WORK/kout" \
  ARCH=arm64 \
  LLVM=1 \
  KERNELRELEASE="$REL" \
  M="$WORK/ext" \
  V=1 \
  modules
```

---

## 6. Verifying the Built Binary

Always run the verification script before deploying:

```bash
./scripts/verify-module.sh "$WORK/ext/ath9k_htc.ko"
```

Expected output:
```text
Module vermagic: 6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k SMP preempt mod_unload modversions aarch64
Imported Syms:   168 entries in __versions
[OK] Vermagic matches exactly
Matching CRCs:  168 / 168
CRC Mismatches: 0
Missing Syms:   0
RESULT: PASS — Module ABI & Vermagic fully verified!
```

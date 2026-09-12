# Release Assets & Distribution Guidelines

This directory explains how precompiled kernel modules and firmware binaries are handled for the Lenovo Tab TB311FU `ath9k_htc` project.

---

## 1. Why Binaries Are NOT Committed to Git

In accordance with standard open-source kernel repository standards:

1. **Repository Hygiene**: Committing binary `.ko` files and blobs bloats git history and complicates tracking.
2. **Kernel ABI Specificity**: Kernel modules are strictly coupled to the exact kernel vermagic (`6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k`) and toolchain compiler symbols. They will fail to load on differing builds.
3. **Firmware Licensing**: The AR9271 firmware (`htc_9271-1.4.0.fw`) is governed by open firmware licensing terms and is best retrieved directly from the upstream `linux-firmware` repository.

Official releases and precompiled binaries are distributed via **GitHub Releases** (attached as zip/tarball release assets) rather than committed directly into the Git repository tree.

---

## 2. Verified Module Reference Information

The following table lists the verified binaries built for Lenovo Tab TB311FU stock Android 15:

| Module | Exact Size | SHA-256 Checksum | Vermagic |
|---|---:|---|---|
| `ath.ko` | 1,187,360 B | `166334568dcdd680a86b91fec468f41a431d48d41709a2bb3ab5d9e67d0aa57e` | `6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k SMP preempt mod_unload modversions aarch64` |
| `ath9k_hw.ko` | 5,491,464 B | `5ce3f342f2f7b6999196597642f0756519d2b28f183a3af33e1b339944fd7dd2` | `6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k SMP preempt mod_unload modversions aarch64` |
| `ath9k_common.ko`| 876,872 B | `8947a5581f5220dede55b06f27c09b1d1b31476415cf90c55fc62588b3eca371` | `6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k SMP preempt mod_unload modversions aarch64` |
| `ath9k_htc.ko` (patched) | 2,268,208 B | `c9683f1bf97a39da604d5bbcee94734ed4c348d94234398993025b4624eb5c94` | `6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k SMP preempt mod_unload modversions aarch64` |

---

## 3. Official Firmware Acquisition & TB311FU Placement

The Atheros AR9271 adapter requires `htc_9271-1.4.0.fw`.

Download the file directly from the official kernel.org `linux-firmware` repository:

```bash
# Create target directory
mkdir -p ath9k_htc

# Download official v1.4.0 open firmware
curl -Lo ath9k_htc/htc_9271-1.4.0.fw \
  https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/ath9k_htc/htc_9271-1.4.0.fw

# Verify SHA256 checksum
echo "78f7d592a95b419a02fde7440f30c606fc31a871cf0ce150ced40d4857173eb0  ath9k_htc/htc_9271-1.4.0.fw" | sha256sum -c -
```

### Installation on Lenovo TB311FU
On the Lenovo Tab TB311FU, writing to `/sys/module/firmware_class/parameters/path` **DID NOT WORK** (even with SELinux permissive).

The **confirmed working method** is placing the firmware in a Magisk vendor overlay:
```text
/vendor/firmware/ath9k_htc/htc_9271-1.4.0.fw
```
(Placed inside the Magisk module at `$MODDIR/system/vendor/firmware/ath9k_htc/htc_9271-1.4.0.fw`). After reboot, the driver automatically loads the firmware from `/vendor/firmware/`.

---

## 4. Packaging a Release

To bundle locally built or verified modules into a release package, use the provided helper script:

```bash
./scripts/package-release.sh \
  --ath /path/to/ath.ko \
  --hw /path/to/ath9k_hw.ko \
  --common /path/to/ath9k_common.ko \
  --htc /path/to/ath9k_htc.ko \
  --out-dir ./release-dist \
  --archive
```

The script verifies module ABI compliance before creating `SHA256SUMS`, `BUILD-INFO.txt`, and the optional `.tar.gz` distribution archive.

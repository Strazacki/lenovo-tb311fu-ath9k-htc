#!/usr/bin/env bash
#
# package-release.sh - Prepares a structured release package containing verified kernel modules
#
# IMPORTANT:
# All 4 kernel modules must be explicitly provided via command line arguments.
# This script NEVER searches for or grabs binaries from random or unverified directories.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ATH_KO=""
ATH9K_HW_KO=""
ATH9K_COMMON_KO=""
ATH9K_HTC_KO=""
OUTPUT_DIR=""
CREATE_ARCHIVE=0

show_usage() {
    cat << EOF
Usage: $0 [options]

Required Arguments (all 4 kernel modules must be explicitly specified):
  --ath <path>            Path to ath.ko
  --hw <path>             Path to ath9k_hw.ko
  --common <path>         Path to ath9k_common.ko
  --htc <path>            Path to patched ath9k_htc.ko

Optional Arguments:
  --out-dir <dir>         Output directory for the packaged release (default: ./release-pkg)
  --archive               Also create a .tar.gz archive of the release package
  -h, --help              Show this help message

Example:
  $0 \\
    --ath path/to/ath.ko \\
    --hw path/to/ath9k_hw.ko \\
    --common path/to/ath9k_common.ko \\
    --htc path/to/ath9k_htc.ko \\
    --out-dir ./release-dist \\
    --archive
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ath)
            ATH_KO="$2"
            shift 2
            ;;
        --hw)
            ATH9K_HW_KO="$2"
            shift 2
            ;;
        --common)
            ATH9K_COMMON_KO="$2"
            shift 2
            ;;
        --htc)
            ATH9K_HTC_KO="$2"
            shift 2
            ;;
        --out-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --archive)
            CREATE_ARCHIVE=1
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown argument: $1" >&2
            show_usage
            exit 1
            ;;
    esac
done

# Validate that all 4 modules were provided
missing_args=0
for var in ATH_KO ATH9K_HW_KO ATH9K_COMMON_KO ATH9K_HTC_KO; do
    if [[ -z "${!var}" ]]; then
        echo "Error: Missing required argument: --$(echo "$var" | tr '[:upper:]' '[:lower:]' | sed 's/_ko//; s/ath9k_//')" >&2
        missing_args=1
    fi
done

if [[ "$missing_args" -eq 1 ]]; then
    echo "" >&2
    show_usage
    exit 1
fi

# Validate file existence
for f in "$ATH_KO" "$ATH9K_HW_KO" "$ATH9K_COMMON_KO" "$ATH9K_HTC_KO"; do
    if [[ ! -f "$f" ]]; then
        echo "Error: File does not exist: $f" >&2
        exit 1
    fi
done

if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="${REPO_DIR}/release-pkg"
fi

echo "======================================================================"
echo " Preparing TB311FU Kernel Module Release Package"
echo "======================================================================"
echo "ath.ko:          $ATH_KO"
echo "ath9k_hw.ko:     $ATH9K_HW_KO"
echo "ath9k_common.ko: $ATH9K_COMMON_KO"
echo "ath9k_htc.ko:    $ATH9K_HTC_KO"
echo "Output Directory: $OUTPUT_DIR"
echo "======================================================================"

# Run verification script on ath9k_htc.ko
if [[ -x "${SCRIPT_DIR}/verify-module.sh" ]]; then
    echo "Verifying ath9k_htc.ko ABI before packaging..."
    "${SCRIPT_DIR}/verify-module.sh" "$ATH9K_HTC_KO"
    echo ""
fi

mkdir -p "$OUTPUT_DIR"

# Copy modules
cp "$ATH_KO" "${OUTPUT_DIR}/ath.ko"
cp "$ATH9K_HW_KO" "${OUTPUT_DIR}/ath9k_hw.ko"
cp "$ATH9K_COMMON_KO" "${OUTPUT_DIR}/ath9k_common.ko"
cp "$ATH9K_HTC_KO" "${OUTPUT_DIR}/ath9k_htc.ko"

# Generate SHA256SUMS inside package
(
    cd "$OUTPUT_DIR"
    sha256sum ath.ko ath9k_hw.ko ath9k_common.ko ath9k_htc.ko > SHA256SUMS
)

# Extract vermagic and compiler information
VERMAGIC="$(modinfo "${OUTPUT_DIR}/ath9k_htc.ko" 2>/dev/null | grep "^vermagic:" | awk '{$1=""; print $0}' | sed 's/^ //' || echo 'unknown')"
COMPILER="Android Clang r510928 / LLVM 18.0.0"

# Generate BUILD-INFO.txt
cat << EOF > "${OUTPUT_DIR}/BUILD-INFO.txt"
======================================================================
 Lenovo Tab TB311FU (poplar) ath9k_htc Release Package
======================================================================
Build Timestamp (UTC): $(date -u '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)
Target Device:         Lenovo Tab TB311FU (poplar / POPLAR_ROW_WIFI)
Android Version:       Android 15
Target Kernel:         6.6.57-android15-8-g9dfb2bc0c466-ab12845201-4k
Architecture:          aarch64 (GKI 2.0, 4k page size)
Target Vermagic:       ${VERMAGIC}
Target Compiler:       ${COMPILER}

Included Kernel Modules:
- ath.ko
- ath9k_hw.ko
- ath9k_common.ko
- ath9k_htc.ko (patched: iface_combinations disabled for TB311FU cfg80211 wiphy_register)

Loading Sequence (strictly required in this order):
1. insmod ath.ko
2. insmod ath9k_hw.ko
3. insmod ath9k_common.ko
4. insmod ath9k_htc.ko

SHA-256 Checksums:
$(cat "${OUTPUT_DIR}/SHA256SUMS")

Firmware Notice:
The Atheros AR9271 requires the firmware blob 'ath9k_htc/htc_9271-1.4.0.fw'.
Firmware is NOT included in this package due to license redistribution policies.
Download the official open-ath9k-htc-firmware directly from upstream linux-firmware:
  https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/ath9k_htc/htc_9271-1.4.0.fw
Expected Firmware SHA256:
  78f7d592a95b419a02fde7440f30c606fc31a871cf0ce150ced40d4857173eb0
======================================================================
EOF

echo "Package contents generated in: ${OUTPUT_DIR}"
ls -lh "${OUTPUT_DIR}"

if [[ "$CREATE_ARCHIVE" -eq 1 ]]; then
    ARCHIVE_NAME="tb311fu-ath9k_htc-gki-6.6.57-$(date +%Y%m%d).tar.gz"
    ARCHIVE_PATH="${OUTPUT_DIR}/../${ARCHIVE_NAME}"
    echo ""
    echo "Creating compressed tarball: ${ARCHIVE_PATH} ..."
    tar -czf "${ARCHIVE_PATH}" -C "${OUTPUT_DIR}" .
    echo "Archive created successfully: $(ls -lh "${ARCHIVE_PATH}" | awk '{print $5, $9}')"
    echo "Archive SHA256: $(sha256sum "${ARCHIVE_PATH}" | awk '{print $1}')"
fi

echo ""
echo "Release packaging completed successfully."

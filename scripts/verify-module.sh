#!/usr/bin/env bash
#
# verify-module.sh - Kernel module ABI, vermagic, and CRC validator
#
# Usage:
#   ./scripts/verify-module.sh <module.ko> [options]
#
# Options:
#   --reference <ref.ko>   Compare against reference .ko file
#   --symvers <file>       Compare against reference Module.symvers / CRC table
#   --expected-vermagic <v> Custom vermagic string (default from config/expected-vermagic.txt)
#   --help, -h             Show this help message
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

DEFAULT_VERMAGIC_FILE="${REPO_DIR}/config/expected-vermagic.txt"
DEFAULT_SYMVERS_FILE="${REPO_DIR}/config/reference-symvers-ath9k_htc.txt"

TARGET_KO=""
REF_KO=""
SYMVERS_FILE=""
EXPECTED_VERMAGIC=""

show_usage() {
    echo "Usage: $0 <path-to-module.ko> [options]"
    echo ""
    echo "Options:"
    echo "  --reference <ref.ko>     Path to reference .ko file for full 1:1 comparison"
    echo "  --symvers <file>         Path to expected CRC table (default: config/reference-symvers-ath9k_htc.txt if checking ath9k_htc)"
    echo "  --expected-vermagic <v>  Expected vermagic string"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 ./ath9k_htc.ko"
    echo "  $0 ./out-patched/ath9k_htc.ko --reference ./out/ath9k_htc.ko"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_usage
            exit 0
            ;;
        --reference)
            REF_KO="$2"
            shift 2
            ;;
        --symvers)
            SYMVERS_FILE="$2"
            shift 2
            ;;
        --expected-vermagic)
            EXPECTED_VERMAGIC="$2"
            shift 2
            ;;
        -*)
            echo "Error: Unknown option $1" >&2
            show_usage
            exit 1
            ;;
        *)
            if [[ -z "${TARGET_KO}" ]]; then
                TARGET_KO="$1"
                shift
            else
                echo "Error: Unexpected argument $1" >&2
                show_usage
                exit 1
            fi
            ;;
    esac
done

if [[ -z "${TARGET_KO}" ]]; then
    echo "Error: Target .ko module path required." >&2
    show_usage
    exit 1
fi

if [[ ! -f "${TARGET_KO}" ]]; then
    echo "Error: Target file not found: ${TARGET_KO}" >&2
    exit 1
fi

if [[ -n "${REF_KO}" && ! -f "${REF_KO}" ]]; then
    echo "Error: Reference file not found: ${REF_KO}" >&2
    exit 1
fi

if [[ -z "${EXPECTED_VERMAGIC}" && -f "${DEFAULT_VERMAGIC_FILE}" ]]; then
    EXPECTED_VERMAGIC="$(head -n 1 "${DEFAULT_VERMAGIC_FILE}" | tr -d '\r\n')"
fi

# If target looks like ath9k_htc and no symvers specified, default to built-in table
BASENAME="$(basename "${TARGET_KO}")"
if [[ -z "${SYMVERS_FILE}" && "${BASENAME}" == *"ath9k_htc"* && -f "${DEFAULT_SYMVERS_FILE}" ]]; then
    SYMVERS_FILE="${DEFAULT_SYMVERS_FILE}"
fi

echo "======================================================================"
echo " TB311FU Kernel Module Verification"
echo "======================================================================"
echo "Target Module:   ${TARGET_KO}"
if [[ -n "${REF_KO}" ]]; then
    echo "Reference Module: ${REF_KO}"
fi
if [[ -n "${SYMVERS_FILE}" ]]; then
    echo "Symvers Table:   ${SYMVERS_FILE}"
fi
echo "======================================================================"

python3 - "${TARGET_KO}" "${REF_KO}" "${SYMVERS_FILE}" "${EXPECTED_VERMAGIC}" << 'EOF'
import sys
import os
import hashlib
import struct
import subprocess

target_path = sys.argv[1]
ref_path = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else None
symvers_path = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] else None
expected_vermagic = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] else None

def get_sha256(filepath):
    h = hashlib.sha256()
    with open(filepath, 'rb') as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def get_readelf_comment(filepath):
    # Try llvm-readelf-18, llvm-readelf, or readelf
    for tool in ['llvm-readelf-18', 'llvm-readelf', 'readelf']:
        try:
            res = subprocess.run([tool, '-p', '.comment', filepath],
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            if res.returncode == 0:
                lines = [l.split(']', 1)[-1].strip() for l in res.stdout.splitlines() if ']' in l]
                if lines:
                    return " | ".join(lines)
        except FileNotFoundError:
            continue
    return "Unknown (readelf not found)"

def extract_modinfo(filepath):
    info = {}
    # Try modinfo first
    try:
        res = subprocess.run(['modinfo', filepath],
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if res.returncode == 0:
            for line in res.stdout.splitlines():
                if ':' in line:
                    k, v = line.split(':', 1)
                    info[k.strip()] = v.strip()
            if 'vermagic' in info:
                return info
    except FileNotFoundError:
        pass

    # Fallback to reading .modinfo section via readelf
    for tool in ['llvm-readelf-18', 'llvm-readelf', 'readelf']:
        try:
            res = subprocess.run([tool, '-p', '.modinfo', filepath],
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            if res.returncode == 0:
                for line in res.stdout.splitlines():
                    if ']' in line:
                        content = line.split(']', 1)[1].strip()
                        if '=' in content:
                            k, v = content.split('=', 1)
                            info[k.strip()] = v.strip()
                return info
        except FileNotFoundError:
            continue
    return info

def extract_modversions(filepath):
    symbols = {}
    with open(filepath, 'rb') as f:
        data = f.read()

    if len(data) < 64 or data[:4] != b'\x7fELF':
        return symbols

    e_shoff = struct.unpack_from('<Q', data, 40)[0]
    e_shentsize = struct.unpack_from('<H', data, 58)[0]
    e_shnum = struct.unpack_from('<H', data, 60)[0]
    e_shstrndx = struct.unpack_from('<H', data, 62)[0]

    shstr_hdr = data[e_shoff + e_shstrndx * e_shentsize : e_shoff + (e_shstrndx + 1) * e_shentsize]
    shstr_offset, shstr_size = struct.unpack_from('<QQ', shstr_hdr, 24)
    shstrtab = data[shstr_offset : shstr_offset + shstr_size]

    for i in range(e_shnum):
        sh = data[e_shoff + i * e_shentsize : e_shoff + (i + 1) * e_shentsize]
        sh_name_idx, sh_type, sh_flags, sh_addr, sh_offset, sh_size = struct.unpack_from('<IIQQQQ', sh, 0)
        name = shstrtab[sh_name_idx:].split(b'\x00')[0].decode('latin1', errors='ignore')
        if name == '__versions':
            vdata = data[sh_offset : sh_offset + sh_size]
            for offset in range(0, len(vdata), 64):
                if offset + 64 > len(vdata):
                    break
                crc = struct.unpack_from('<I', vdata, offset)[0]
                sym = vdata[offset+8:offset+64].split(b'\x00')[0].decode('latin1', errors='replace')
                if sym:
                    symbols[sym] = crc
    return symbols

target_size = os.path.getsize(target_path)
target_sha = get_sha256(target_path)
target_info = extract_modinfo(target_path)
target_vermagic = target_info.get('vermagic', 'UNKNOWN')
target_comment = get_readelf_comment(target_path)
target_syms = extract_modversions(target_path)

print(f"File Size:       {target_size:,} bytes")
print(f"SHA-256:         {target_sha}")
print(f"Compiler Info:   {target_comment}")
print(f"Module vermagic: {target_vermagic}")
print(f"Dependencies:    {target_info.get('depends', '(none)')}")
print(f"Imported Syms:   {len(target_syms)} entries in __versions")
print("")

errors = 0

# Check vermagic
if expected_vermagic:
    print("--- Vermagic Check ---")
    if target_vermagic == expected_vermagic:
        print(f"[OK] Vermagic matches exactly: {target_vermagic}")
    else:
        print("[FAIL] Vermagic mismatch!")
        print(f"  Expected: {expected_vermagic}")
        print(f"  Actual:   {target_vermagic}")
        errors += 1
    print("")

# Compare against reference file or symvers
expected_syms = {}
ref_source_name = None

if ref_path:
    ref_source_name = f"Reference file ({os.path.basename(ref_path)})"
    expected_syms = extract_modversions(ref_path)
    ref_info = extract_modinfo(ref_path)
    print(f"--- Reference Comparison: {os.path.basename(ref_path)} ---")
    print(f"  Reference Size:     {os.path.getsize(ref_path):,} bytes")
    print(f"  Reference SHA-256:  {get_sha256(ref_path)}")
    print(f"  Reference vermagic: {ref_info.get('vermagic', 'UNKNOWN')}")
    print(f"  Reference Symbols:  {len(expected_syms)}")
elif symvers_path and os.path.isfile(symvers_path):
    ref_source_name = f"Symvers Table ({os.path.basename(symvers_path)})"
    with open(symvers_path, 'r') as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) >= 2:
                crc_str = parts[0]
                sym_name = parts[1]
                try:
                    crc_val = int(crc_str, 16)
                    expected_syms[sym_name] = crc_val
                except ValueError:
                    pass
    print(f"--- Expected Symvers Table: {os.path.basename(symvers_path)} ---")
    print(f"  Loaded Expected Symbols: {len(expected_syms)}")

if expected_syms:
    print("--- Symbol CRC & KMI Check ---")
    matches = 0
    mismatches = []
    missing_in_target = []
    target_only = []

    for sym, exp_crc in expected_syms.items():
        if sym in target_syms:
            act_crc = target_syms[sym]
            if act_crc == exp_crc:
                matches += 1
            else:
                mismatches.append((sym, act_crc, exp_crc))
        else:
            missing_in_target.append((sym, exp_crc))

    for sym in target_syms:
        if sym not in expected_syms:
            target_only.append(sym)

    print(f"  Matching CRCs:  {matches} / {len(expected_syms)}")
    print(f"  CRC Mismatches: {len(mismatches)}")
    print(f"  Missing Syms:   {len(missing_in_target)}")
    if target_only:
        print(f"  Extra Syms:     {len(target_only)}")

    if mismatches:
        print("\n  [FAIL] Symbol CRC Mismatches detected:")
        for sym, act, exp in mismatches[:20]:
            print(f"    - {sym}: built=0x{act:08x}, expected=0x{exp:08x}")
        if len(mismatches) > 20:
            print(f"    ... and {len(mismatches) - 20} more")
        errors += len(mismatches)

    if missing_in_target:
        print("\n  [FAIL] Missing required symbols:")
        for sym, exp in missing_in_target[:20]:
            print(f"    - {sym} (expected 0x{exp:08x})")
        if len(missing_in_target) > 20:
            print(f"    ... and {len(missing_in_target) - 20} more")
        errors += len(missing_in_target)

    if not mismatches and not missing_in_target:
        print(f"\n[OK] 100% symbol ABI compliance against {ref_source_name}!")
    print("")

print("======================================================================")
if errors == 0:
    print("RESULT: PASS — Module ABI & Vermagic fully verified!")
    print("======================================================================")
    sys.exit(0)
else:
    print(f"RESULT: FAIL — Found {errors} verification error(s)!")
    print("======================================================================")
    sys.exit(1)
EOF

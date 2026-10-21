#!/usr/bin/env bash
# Build the Xiaomi 12X (psyche) LineageOS 23.2 kernel with kallsyms.
#
# The stock LOS kernel is 4.19.246 and was built without a usable kallsyms
# token table (kptools says "find_token_table error").  This build uses the
# current lineage-23.2 source (4.19.325) plus the LOS config fragments, forces
# KALLSYMS/KALLSYMS_ALL, and disables LTO and KernelSU.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_DIR="${KERNEL_DIR:-$REPO_ROOT/kernel}"
OUT_DIR="${OUT_DIR:-out}"
CLANG_DIR="${CLANG_DIR:-$REPO_ROOT/clang}"
JOBS="${JOBS:-$(nproc)}"

export PATH="$CLANG_DIR/bin:$PATH"
export ARCH=arm64
export SUBARCH=arm64
export LLVM=1
export LLVM_IAS=1
export CC=clang
export LD=ld.lld
export AR=llvm-ar
export NM=llvm-nm
export OBJCOPY=llvm-objcopy
export OBJDUMP=llvm-objdump
export STRIP=llvm-strip
export READELF=llvm-readelf
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
export CLANG_TRIPLE=aarch64-linux-gnu-
export HOSTCC=gcc
export HOSTCXX=g++
export KBUILD_BUILD_USER=github-actions
export KBUILD_BUILD_HOST=psyche

cd "$KERNEL_DIR"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

echo "=== toolchain ==="
clang --version | head -1
ld.lld --version | head -1
aarch64-linux-gnu-gcc --version | head -1

echo "=== base defconfig ==="
make O="$OUT_DIR" vendor/kona-perf_defconfig

echo "=== merge LOS config fragments ==="
bash scripts/kconfig/merge_config.sh -O "$OUT_DIR" \
    arch/arm64/configs/vendor/debugfs.config \
    arch/arm64/configs/vendor/xiaomi/sm8250-common.config \
    arch/arm64/configs/vendor/xiaomi/psyche.config \
    "$REPO_ROOT/config/kallsyms.config"

echo "=== force kallsyms / no LTO / no KSU ==="
bash scripts/config --file "$OUT_DIR/.config" \
    --enable KALLSYMS \
    --enable KALLSYMS_ALL \
    --enable KALLSYMS_BASE_RELATIVE \
    --disable LTO_CLANG \
    --enable LTO_NONE \
    --disable CFI_CLANG \
    --disable SHADOW_CALL_STACK \
    --disable KSU

make O="$OUT_DIR" olddefconfig

# Some kernel trees keep a choice symbol enabled even after --disable.
if grep -q '^CONFIG_LTO_CLANG=y' "$OUT_DIR/.config"; then
    echo "LTO_CLANG is still enabled; forcing LTO_NONE"
    sed -i 's/^CONFIG_LTO_CLANG=y/# CONFIG_LTO_CLANG is not set/' "$OUT_DIR/.config"
    grep -q '^CONFIG_LTO_NONE=y' "$OUT_DIR/.config" || echo 'CONFIG_LTO_NONE=y' >> "$OUT_DIR/.config"
    make O="$OUT_DIR" olddefconfig
fi

if grep -q '^CONFIG_KSU=y' "$OUT_DIR/.config"; then
    echo "KSU is still enabled; forcing it off"
    sed -i 's/^CONFIG_KSU=y/# CONFIG_KSU is not set/' "$OUT_DIR/.config"
    make O="$OUT_DIR" olddefconfig
fi

if grep -q '^CONFIG_CFI_CLANG=y' "$OUT_DIR/.config"; then
    echo "CFI_CLANG is still enabled; forcing it off"
    sed -i 's/^CONFIG_CFI_CLANG=y/# CONFIG_CFI_CLANG is not set/' "$OUT_DIR/.config"
    make O="$OUT_DIR" olddefconfig
fi
if grep -q '^CONFIG_SHADOW_CALL_STACK=y' "$OUT_DIR/.config"; then
    echo "SHADOW_CALL_STACK is still enabled; forcing it off"
    sed -i 's/^CONFIG_SHADOW_CALL_STACK=y/# CONFIG_SHADOW_CALL_STACK is not set/' "$OUT_DIR/.config"
    make O="$OUT_DIR" olddefconfig
fi

echo "=== final relevant config ==="
grep -E '^CONFIG_(KALLSYMS|KALLSYMS_ALL|KALLSYMS_BASE_RELATIVE|LTO_.*|KSU|CFI_CLANG|SHADOW_CALL_STACK|DEBUG_INFO|MODULES|MODVERSIONS)=' "$OUT_DIR/.config" || true

if ! grep -q '^CONFIG_KALLSYMS=y' "$OUT_DIR/.config"; then
    echo "ERROR: CONFIG_KALLSYMS is not enabled" >&2
    exit 1
fi
if ! grep -q '^CONFIG_KALLSYMS_ALL=y' "$OUT_DIR/.config"; then
    echo "ERROR: CONFIG_KALLSYMS_ALL is not enabled" >&2
    exit 1
fi
if grep -q '^CONFIG_LTO_CLANG=y' "$OUT_DIR/.config"; then
    echo "ERROR: LTO_CLANG is still enabled" >&2
    exit 1
fi
if grep -q '^CONFIG_CFI_CLANG=y' "$OUT_DIR/.config"; then
    echo "ERROR: CFI_CLANG is still enabled" >&2
    exit 1
fi
if grep -q '^CONFIG_SHADOW_CALL_STACK=y' "$OUT_DIR/.config"; then
    echo "ERROR: SHADOW_CALL_STACK is still enabled" >&2
    exit 1
fi
if grep -q '^CONFIG_KSU=y' "$OUT_DIR/.config"; then
    echo "ERROR: KSU is still enabled" >&2
    exit 1
fi

echo "=== build Image ==="
make O="$OUT_DIR" -j"$JOBS" Image
make O="$OUT_DIR" System.map

echo "=== kallsyms symbols in System.map ==="
grep -E ' kallsyms_(token_table|token_index|names|num_syms|offsets|relative_base|markers)$' "$OUT_DIR/System.map" || true

ls -lh "$OUT_DIR/arch/arm64/boot/Image" "$OUT_DIR/System.map" "$OUT_DIR/.config"

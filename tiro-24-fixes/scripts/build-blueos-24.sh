#!/usr/bin/env bash
set -Eeo pipefail

SRC=/mnt/ytx-src/blueos-tiro-24.0/source
BUILD=/mnt/axion-build/blueos-tiro-24.0
OUT="$BUILD/out"
CACHE=/mnt/axion-cache/ccache
JOBS=8   # R8 (Xmx4096M per JVM) crashed repeatedly at -j12 on 31 GiB RAM
LOG="$BUILD/build-blueos-24-$(date +%Y%m%d-%H%M%S).log"

exec > >(tee -a "$LOG") 2>&1
trap 'rc=$?; echo; echo "SCRIPT EXIT CODE: $rc"; echo "LOG: $LOG"; echo "$rc" > "$BUILD/build-blueos-24.exit"' EXIT

set -x

echo "=== VERIFY STORAGE ==="
[[ "$(findmnt -n -o SOURCE -T /mnt/ytx-src)" == "/dev/mapper/ubuntu--vg-ytx--src" ]]
[[ "$(findmnt -n -o SOURCE -T /mnt/axion-build)" == "/dev/sdb2" ]]
[[ "$(findmnt -n -o SOURCE -T /mnt/axion-cache)" == "/dev/mapper/ubuntu--vg-axion--cache" ]]
[[ -f "$SRC/build/envsetup.sh" ]]
[[ -d "$SRC/vendor/blueos" ]]

echo "=== BUILD CONFIG ==="
echo "SRC=$SRC"
echo "OUT=$OUT"
echo "JOBS=$JOBS"
echo "TARGET=lineage_tiro-cp2a-userdebug (stable release, codename=REL)"

export OUT_DIR="$OUT"
export USE_CCACHE=1
export CCACHE_DIR="$CACHE"
export CCACHE_EXEC="$(command -v ccache)"
# bionic/libc/kernel/tools/cpp.py imports clang.cindex; make the bundled
# bindings visible inside the sbox sandbox too.
export PYTHONPATH="$SRC/prebuilts/clang/host/linux-x86/clang-stable/lib/python3/site-packages"
# siso hashfs repeatedly fails on DTB_OBJ/* dirs; use plain ninja instead.
export SOONG_NINJA=ninja

mkdir -p "$OUT" "$CACHE"

# The 24.0 kernel keeps audio UAPI headers in sm8650-modules, outside the
# kernel headers_install tree.  ar_osal includes <linux/msm_audio.h>, so put
# them where the generated kernel-headers include dirs expect them.
KHEAD="$OUT/soong/.intermediates/vendor/lineage/build/soong/generated_kernel_includes/gen"
AUDIO_SRC="$SRC/kernel/nubia/sm8650-modules/qcom/opensource/audio-kernel/include/uapi/audio"
if [ -d "$AUDIO_SRC" ]; then
    mkdir -p "$KHEAD/usr/audio/include/uapi" "$KHEAD/usr/include/audio/include/uapi"
    cp -a "$AUDIO_SRC/." "$KHEAD/usr/audio/include/uapi/"
    cp -a "$AUDIO_SRC/." "$KHEAD/usr/include/audio/include/uapi/"
fi
DISPLAY_SRC="$SRC/kernel/nubia/sm8650-modules/qcom/opensource/display-drivers/include/uapi/display"
if [ -d "$DISPLAY_SRC" ]; then
    mkdir -p "$KHEAD/usr/include/display"
    cp -a "$DISPLAY_SRC/." "$KHEAD/usr/include/display/"
fi

echo "=== CCACHE ==="
ccache -M 25G
ccache -s

echo "=== CONFIGURE ==="
cd "$SRC"
source build/envsetup.sh
lunch lineage_tiro-cp2a-userdebug

echo "=== BUILD (m bacon -j$JOBS) ==="
m bacon -j"$JOBS"

echo "=== BUILD FINISHED ==="

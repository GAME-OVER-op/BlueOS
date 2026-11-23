#!/bin/bash
set -eu

# sbox runs this script from the sandbox root, where neither the real bionic
# tools nor the bundled clang Python bindings live.  Switch to the real source
# tree so cpp.py can find prebuilts/clang/... and its cwd check passes.
export ANDROID_BUILD_TOP=/mnt/ytx-src/blueos-tiro-24.0/source
cd "$ANDROID_BUILD_TOP"

./bionic/libc/kernel/tools/clean_header.py -u \
    "$1/usr/include/asm/signal.h" \
    "$1/usr/include/asm-generic/signal.h" \
    "$1/usr/include/linux/eventpoll.h"

# 24.0 keeps audio UAPI headers in sm8650-modules, outside the kernel's
# headers_install tree.  ar_osal includes <linux/msm_audio.h>, so restore them
# into the generated header dirs after every headers_install run.
AUDIO_SRC="$ANDROID_BUILD_TOP/kernel/nubia/sm8650-modules/qcom/opensource/audio-kernel/include/uapi/audio"
if [ -d "$AUDIO_SRC" ]; then
    mkdir -p "$1/usr/audio/include/uapi" "$1/usr/include/audio/include/uapi"
    cp -a "$AUDIO_SRC/." "$1/usr/audio/include/uapi/"
    cp -a "$AUDIO_SRC/." "$1/usr/include/audio/include/uapi/"
    # The raw vendor headers still contain kernel-only annotations such as
    # __user (e.g. sound/devdep_params.h).  Run bionic's cleaner on them.
    for AUDIO_DST in "$1/usr/audio/include/uapi" "$1/usr/include/audio/include/uapi"; do
        files=$(cd "$AUDIO_DST" && find . -name '*.h' -printf '%P\n' | sort)
        if [ -n "$files" ]; then
            echo "$files" | xargs -r python3 ./bionic/libc/kernel/tools/clean_header.py \
                -u -k "$AUDIO_DST" -d "$AUDIO_DST"
        fi
    done
fi

# Same for display UAPI headers (libdrmutils includes <display/drm/msm_drm_pp.h>).
DISPLAY_SRC="$ANDROID_BUILD_TOP/kernel/nubia/sm8650-modules/qcom/opensource/display-drivers/include/uapi/display"
if [ -d "$DISPLAY_SRC" ]; then
    mkdir -p "$1/usr/include/display"
    cp -a "$DISPLAY_SRC/." "$1/usr/include/display/"
fi

# Vendor UAPI headers from the loadable kernel modules are not part of the
# main kernel headers_install tree.  Copy any that are missing into the
# generated include dir (e.g. linux/qti-smmu-proxy.h used by gralloc).
find "$ANDROID_BUILD_TOP/kernel/nubia/sm8650-modules" -path '*/include/uapi/linux/*.h' -type f | while read -r hdr; do
    rel=${hdr#*/include/uapi/}
    dst="$1/usr/include/$rel"
    if [ ! -f "$dst" ]; then
        mkdir -p "$(dirname "$dst")"
        cp "$hdr" "$dst"
    fi
done

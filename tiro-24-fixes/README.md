# Tiro 24.0 build fixes (BlueOS 0.9.0)

Backup of every local change made to build **BlueOS 0.9.0 / LineageOS 24.0** for
Red Magic 9 Pro (`tiro`). Branch `tiro-24-fixes` is based on the upstream tag
`v0.9.0` of `GDmio/BlueOS` so the fixes can be recovered independently of the
build machine.

The modified files belong to other projects (`device/nubia/tiro` and
`vendor/lineage`), **not** to the BlueOS repository itself. They are kept here as
plain copies plus patches so nothing is lost. `vendor/blueos` itself is unmodified.

## Fixes

1. **Manifest setup** — `manifests/`
   - `blueos-tiro.xml`: 7 `nubia-sm8650-devs` projects on `lineage-24.0`,
     `BlueOS` on `0.9.0`, including `android_kernel_nubia_sm8650-devicetrees`
     (missing in the broken 24.0 manifest).
   - `nubia-sm8650-modules.xml`: kernel modules on `lineage-24.0`.
   - `*.bak-20261120` are the originals.

2. **Slider fix** — `patches/001-tiro-slider-fix.patch`, `files/device/nubia/tiro/`
   - `device.mk`: removed `LineageSlider` and `vendor.lineage.slider-service.default`
     from `PRODUCT_PACKAGES` (those modules do not exist in the 24.0 tree, kati
     failed with "includes non-existent modules").
   - `vendor.prop`: removed the slider properties.

3. **Kernel UAPI headers fix** — `patches/002-kernel-uapi-headers-fix.patch`,
   `files/vendor/lineage/`
   - `build/soong/Android.bp`: `dep_files` uses `scripts/**/*` so the sbox
     sandbox receives `Makefile.build`, `pahole-flags.sh`, etc.
   - `tools/clean_headers.sh`: uses the real `ANDROID_BUILD_TOP` (sbox cwd is
     the sandbox root) and restores vendor UAPI headers after each
     `headers_install` run: audio (`linux/msm_audio.h`), display
     (`display/drm/msm_drm_pp.h`) and all missing `include/uapi/linux/*.h`
     from `kernel/nubia/sm8650-modules`. Copied audio headers are additionally
     passed through bionic's `clean_header.py` to strip `__user`, which
     otherwise breaks `sound/devdep_params.h`.

4. **Build script** — `scripts/build-blueos-24.sh`
   - `lunch lineage_tiro-cp2a-userdebug` — stable release:
     `PLATFORM_VERSION_CODENAME=REL`, `preview_sdk=0`. Do **not** use
     `trunk_staging` (Baklava, `preview_sdk=1`), which breaks LSPosed/LSPlant.
   - `-j12` threads, `OUT_DIR=/mnt/axion-build/blueos-tiro-24.0/out`,
     shared ccache at `/mnt/axion-cache/ccache`.

## Restore

Copy the files from `files/` to the matching paths in the 24.0 source tree, or
apply the patches from the top of each project:

```
cd <src>/device/nubia/tiro && git apply <this>/patches/001-tiro-slider-fix.patch
cd <src>/vendor/lineage     && git apply <this>/patches/002-kernel-uapi-headers-fix.patch
```

Copy the manifest XMLs into `<src>/.repo/local_manifests/` and run `repo sync`.

# Psyche kernel build 4

- kernel repo: `xiaomi-psyche-dev/android_kernel_xiaomi_sm8250`
- kernel ref: `lineage-23.2`
- commit: `354104fb5bcda7d1811a9a17b08e35bcc908b59f`
- clang: `Android (7284624, based on r416183b) clang version 12.0.5 (https://android.googlesource.com/toolchain/llvm-project c935d99d7cf2016289302412d708641d52d2f7ee)`

## Relevant config
```
CONFIG_KALLSYMS=y
CONFIG_KALLSYMS_ALL=y
CONFIG_KALLSYMS_BASE_RELATIVE=y
CONFIG_LTO_NONE=y
CONFIG_MODULES=y
```

## Artifacts
```
total 98M
-rw-r--r-- 1 runner runner  492 Oct 21 09:45 BUILD.md
-rwxr-xr-x 1 runner runner  45M Oct 21 09:45 Image
-rw-r--r-- 1 runner runner 6.3M Oct 21 09:45 System.map
-rw-r--r-- 1 runner runner  47M Oct 21 09:45 boot.img
-rw-r--r-- 1 runner runner 171K Oct 21 09:45 kernel.config
-rw-r--r-- 1 runner runner  261 Oct 21 09:45 kptools.log
```

## kptools
not run

Flash the unpatched `boot.img` for a kallsyms-enabled kernel, or
the `patched-boot.img` if you want the test KernelPatch injection.
The superkey for the patched image is in `superkey.txt`.

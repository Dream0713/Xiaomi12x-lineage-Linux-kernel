# Xiaomi12x-lineage-Linux-kernel

在 GitHub Actions 上为 **Xiaomi 12X（psyche）LineageOS 23.2** 重新编译内核，打开 `KALLSYMS` / `KALLSYMS_ALL`，让 `kptools` / FolkPatch（KernelPatch 0.13.9）能够识别并 patch `boot.img`。

## 为什么需要重编

当前安装的 LineageOS 23.2（20260226）内核 banner 是：

```text
Linux version 4.19.246 ... clang version 21.0.0 ... #7 SMP PREEMPT
```

`kptools -p` 报错：

```text
find_token_table error
analyze_kallsym_info error
```

内核镜像里没有可用的 kallsyms token table。这个 workflow 从维护者仓库的 `lineage-23.2` 分支（当前 4.19.325）重新编译，强制：

```text
CONFIG_KALLSYMS=y
CONFIG_KALLSYMS_ALL=y
CONFIG_KALLSYMS_BASE_RELATIVE=y
CONFIG_LTO_NONE=y
# CONFIG_LTO_CLANG is not set
# CONFIG_KSU is not set
```

然后使用**原版 LOS 的 ramdisk 和 boot header**（从 ROM 的 `payload.bin` 提取）打包新的 `boot.img`，并在 CI 里用 `kptools` 验证。

## 仓库怎么建、怎么跑

当前这台电脑上没有可用的 GitHub 写权限 token，所以需要你手动建一个空仓库并 push 一次（之后全自动）。

1. 打开 <https://github.com/new>，仓库名填 `Xiaomi12x-lineage-Linux-kernel`，选 **Public**，**不要**勾选 README / .gitignore / license。
2. 在本目录运行：

```powershell
cd C:\Users\Sky\Documents\psyche-rom\github-kernel
powershell -ExecutionPolicy Bypass -File .\setup-github.ps1
```

脚本会把默认仓库设为 `Dream0713/Xiaomi12x-lineage-Linux-kernel`。如果用户名或仓库名不同：

```powershell
powershell -ExecutionPolicy Bypass -File .\setup-github.ps1 -Repo "你的用户名/Xiaomi12x-lineage-Linux-kernel"
```

第一次 push 时 Git Credential Manager 会弹出 GitHub 登录窗口，按提示登录即可。push 成功后 workflow 会自动开始跑（因为 workflow 文件在 push 里）。

也可以手动触发：打开 `https://github.com/<你的用户名>/Xiaomi12x-lineage-Linux-kernel/actions` → **Build psyche kernel (kallsyms / FolkPatch)** → **Run workflow**。

## Workflow 做了什么

1. checkout `xiaomi-psyche-dev/android_kernel_xiaomi_sm8250` 的 `lineage-23.2` 分支。
2. 下载 LineageOS 官方 prebuilt clang `r416183b`。
3. 合并 LOS 的 config 片段：
   - `vendor/kona-perf_defconfig`
   - `vendor/debugfs.config`
   - `vendor/xiaomi/sm8250-common.config`
   - `vendor/xiaomi/psyche.config`
   - 本仓库的 `config/kallsyms.config`
4. 强制 KALLSYMS / 关闭 LTO / 关闭 KernelSU，编译 `Image` + `System.map`。
5. 下载 LOS 20260226 ROM（1.63 GB，带 MD5 校验），用 `payload-dumper-go` 提取原版 `boot.img`。
6. 用原版 header + ramdisk + 新 `Image` 打包 `boot.img`（保留 cmdline / os_version / header v3；不复制旧 AVB footer）。
7. 下载 `kptools-linux` + `kpimg-android` 0.13.9，运行 `kptools -d` 和 `kptools -p`，把结果写进 `kptools.log` / `kptools-result.txt`。
8. 把 `Image`、`boot.img`、`patched-boot.img`、`System.map`、`kernel.config`、日志和 `SHA256SUMS.txt` 上传到 Actions artifact，并创建一个 pre-release。

构建时间大约 20–40 分钟；public 仓库的 Actions 免费。

## 产物怎么用

在 Actions run 页面底部下载 artifact，或打开对应的 **Releases** 页面下载。

### 只换内核（推荐先测这个）

```powershell
fastboot flash boot boot.img
fastboot reboot
```

这个 `boot.img` 只是新内核 + 原版 LOS ramdisk，不带 FolkPatch。先确认能开机、Wi-Fi/相机/指纹/通话正常。

### 直接刷测试版 FolkPatch

CI 如果报告 `kptools: OK`，会额外生成：

- `patched-boot.img`
- `superkey.txt`

```powershell
fastboot flash boot patched-boot.img
fastboot reboot
```

测试 superkey 默认是：

```text
folkpatch-psyche-2026
```

FolkPatch 管理器里用这个 key。想用自己的 key，在 Actions 的 **Run workflow** 里改 `superkey` 输入。也可以只刷未 patch 的 `boot.img`，自己在本机用 `kptools` patch。

### 回滚

刷回 LOS 原版 boot（你本地整合包里有）：

```powershell
fastboot flash boot C:\Users\Sky\Documents\psyche-rom\out\psyche-lineage-23.2-20260226\recovery\boot.img
fastboot reboot
```

如果还能进 fastboot，基本都能救。**不要**刷 `init_boot`，也**不要**锁 bootloader。

## 重要说明 / 风险

- 编译的是当前 `lineage-23.2` 源码（4.19.325），不是安装包里那个 4.19.246。4.19.x 是 stable 分支，ABI 基本兼容；我检查了 LOS 的 `vendor` 和 `odm` 镜像，里面**没有 `.ko` 模块**（驱动是 built-in），所以不存在常见的“内核版本和 vendor 模块 vermagic 不匹配”问题。
- 但如果新内核的 DTS/驱动和 20260226 的 vendor blobs 有差异，可能出现 Wi-Fi、相机、指纹、通话等异常。先刷未 patch 的 `boot.img` 测试；异常就刷回原版 boot。
- 旧 `boot.img` 末尾有 AVB footer；新 `boot.img` 不复制它。设备已经解锁，且 LOS 的 `vbmeta` 是 `--disable-verification` 刷的，所以 bootloader 不会校验 boot 的 AVB。**不要**重新锁 bootloader。
- `CONFIG_KALLSYMS_ALL=y` 会增大内核，但 boot 分区 192 MB，足够。
- Workflow 的 `ci-log` 分支会保存最后一次构建日志的末尾；构建失败时先看 `ci/BUILD.md` 和 `ci/kptools.log`。
- 这是非官方内核；Play Integrity / 银行 App 检测与 root 的风险自负。

## 本地验证

在 Windows 上可以用本目录的 `scripts\pack_boot.py` 和本机已有的 kptools 验证产物：

```powershell
python scripts\pack_boot.py <stock-boot.img> <new-Image> test-boot.img
C:\Users\Sky\Documents\psyche-rom\tools\kptools\win\kptools.exe -d -i test-boot.img
```

如果 `-d` 能打印 `linux_banner` 和 kallsyms 信息，不再报 `find_token_table error`，说明内核可用于 FolkPatch。

#!/usr/bin/env python3
"""Replace the kernel inside a stock Android boot.img (header v3).

Usage:
    pack_boot.py <stock_boot.img> <new_Image> <out_boot.img>

The stock boot image supplies the header, command line, os_version, page
size and ramdisk.  The AVB footer is intentionally not copied: the phone is
unlocked and vbmeta verification is disabled by the LOS flash script.

The output is a normal raw boot image.  It is smaller than the stock
partition image; fastboot accepts it.
"""
import hashlib
import os
import struct
import sys

PAGE = 4096


def die(msg: str) -> "NoReturn":
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    if len(sys.argv) != 4:
        print(__doc__.strip(), file=sys.stderr)
        sys.exit(2)

    stock_path, kernel_path, out_path = sys.argv[1:]
    data = open(stock_path, "rb").read()
    if len(data) < PAGE:
        die("stock boot image is too small")
    if data[:8] != b"ANDROID!":
        die("stock image does not start with ANDROID!")
    header = bytearray(data[:PAGE])
    header_version = struct.unpack_from("<I", header, 40)[0]
    if header_version != 3:
        die(f"only boot header v3 is supported, got v{header_version}")

    kernel_size, ramdisk_size = struct.unpack_from("<II", header, 8)
    if kernel_size == 0 or ramdisk_size == 0:
        die("stock boot image has zero kernel/ramdisk size")

    kernel_off = PAGE
    ramdisk_off = ((kernel_off + kernel_size + PAGE - 1) // PAGE) * PAGE
    if ramdisk_off + ramdisk_size > len(data):
        die("stock boot image is truncated")

    stock_ramdisk = data[ramdisk_off:ramdisk_off + ramdisk_size]
    new_kernel = open(kernel_path, "rb").read()
    if new_kernel[:2] == b"\x1f\x8b":
        die("new kernel looks gzip-compressed; pass the raw arm64 Image")
    if len(new_kernel) < 1024:
        die("new kernel is unexpectedly small")

    struct.pack_into("<I", header, 8, len(new_kernel))
    struct.pack_into("<I", header, 12, len(stock_ramdisk))

    out = bytearray(header)
    out += new_kernel
    out += b"\x00" * ((-len(out)) % PAGE)
    out += stock_ramdisk
    out += b"\x00" * ((-len(out)) % PAGE)

    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(out)

    sha = hashlib.sha256(out).hexdigest()
    print(f"stock:  {stock_path} ({len(data)} bytes)")
    print(f"kernel: {kernel_path} ({len(new_kernel)} bytes)")
    print(f"ramdisk:{ramdisk_off}..{ramdisk_off + ramdisk_size} "
          f"({len(stock_ramdisk)} bytes)")
    print(f"output: {out_path} ({len(out)} bytes)")
    print(f"sha256: {sha}")


if __name__ == "__main__":
    main()

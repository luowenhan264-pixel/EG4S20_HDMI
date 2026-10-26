#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
只读扫描 TF 卡（或卡镜像）的物理扇区，找出 640x480x24 非压缩 BMP 的起始 LBA，
并直接打印可粘贴到 top_tf_hdmi_audio.v / sd_card_bmp 的 IMG_SECTOR 参数。

本脚本只读，不会写卡。

Windows 用法（需“以管理员身份运行”的命令行）：
  1. 查卡的物理盘号：  wmic diskdrive get Index,Model,Size
     或 PowerShell：    Get-Disk
  2. 扫描（把 2 换成 TF 卡的盘号，千万别选系统盘）：
       python find_bmp_sectors.py \\\\.\\PhysicalDrive2
  也可以扫一个卡镜像文件：  python find_bmp_sectors.py card.img

可选参数：
  --max-mib 256     最多扫描前多少 MiB（默认 256）
  --count 4         需要几张图（默认 4，对应 IMG_COUNT）
  --any-size        不限定 640x480x24，列出所有 BM 头（排查用）
"""
import argparse
import struct
import sys

SECTOR = 512
CHUNK = 1024 * 1024  # 1 MiB，扇区对齐，Windows 裸盘读取要求


def parse_bmp_header(buf):
    """buf 至少 54 字节。返回 (w, h, bpp, comp, filesize) 或 None。"""
    if buf[:2] != b"BM" or len(buf) < 54:
        return None
    filesize, _, off = struct.unpack_from("<IIi", buf, 2)
    dib, w, h, planes, bpp, comp = struct.unpack_from("<IiiHHI", buf, 14)
    if dib < 40 or planes != 1:
        return None
    return w, h, bpp, comp, filesize, off


def main():
    ap = argparse.ArgumentParser(description="扫描 TF 卡物理扇区里的 BMP 起始 LBA（只读）")
    ap.add_argument("device", help=r"\\.\PhysicalDriveN 或镜像文件路径")
    ap.add_argument("--max-mib", type=int, default=256)
    ap.add_argument("--count", type=int, default=4)
    ap.add_argument("--any-size", action="store_true")
    a = ap.parse_args()

    limit = a.max_mib * 1024 * 1024
    found = []
    try:
        f = open(a.device, "rb", buffering=0)
    except PermissionError:
        sys.exit("打不开设备：请用管理员权限运行命令行。")
    except FileNotFoundError:
        sys.exit("找不到设备/文件：检查 PhysicalDrive 编号或路径。")

    pos = 0
    with f:
        while pos < limit:
            try:
                data = f.read(CHUNK)
            except OSError as e:
                print(f"读到 {pos // SECTOR} 扇区附近出错，停止：{e}")
                break
            if not data:
                break
            for i in range(0, len(data) - 1, SECTOR):
                if data[i:i + 2] != b"BM":
                    continue
                hdr = parse_bmp_header(data[i:i + 64])
                if not hdr:
                    continue
                w, h, bpp, comp, fsz, off = hdr
                lba = (pos + i) // SECTOR
                ok = (w == 640 and abs(h) == 480 and bpp == 24 and comp == 0)
                if ok or a.any_size:
                    found.append((lba, w, h, bpp, comp, fsz, ok))
            pos += len(data)

    if not found:
        print(f"前 {a.max_mib} MiB 内没找到符合条件的 BMP。可加 --max-mib 1024 或 --any-size 再试。")
        return

    print(f"扫描范围：前 {min(pos, limit) // (1024*1024)} MiB")
    print("LBA(扇区)    宽x高      位深 压缩 文件字节   合格")
    for lba, w, h, bpp, comp, fsz, ok in found:
        print(f"{lba:<12} {w}x{h:<7} {bpp:<4} {comp:<4} {fsz:<10} {'是' if ok else '否'}")

    good = [x[0] for x in found if x[6]]
    if len(good) > a.count:
        print(f"\n注意：找到 {len(good)} 张合格图，多于 {a.count} 张，可能有旧图残留，"
              f"建议先用 sync_to_sd.py 重新同步卡。下面取前 {a.count} 张。")
    if len(good) < a.count:
        print(f"\n注意：只找到 {len(good)} 张合格图（需要 {a.count} 张）。")
    sel = good[:a.count]
    if sel:
        print("\n// 粘贴到 top_tf_hdmi_audio.v / sd_card_bmp 参数：")
        print(f"IMG_COUNT   = {len(sel)}")
        for k, lba in enumerate(sel):
            print(f"IMG_SECTOR{k} = {lba}")
        for k in range(1, len(sel)):
            gap = sel[k] - sel[k - 1]
            if gap < 1801:
                print(f"警告：图{k-1} 与图{k} 只隔 {gap} 扇区，小于一张图的 1801 扇区，可能不是连续存放。")


if __name__ == "__main__":
    main()

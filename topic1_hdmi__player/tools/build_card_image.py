"""Create a regular 64 MiB FAT32 image with four contiguous BMP files.

Never opens a physical disk, formats a drive, deletes files, or overwrites an
existing output. The FPGA scans sectors; the FAT32 layout is for host usability.
Python standard library only.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

SECTOR = 512
TOTAL = 131072
START = 2048
RESERVED = 32
FAT_SECTORS = 1024
DATA_START = START + RESERVED + 2 * FAT_SECTORS
CLUSTERS = TOTAL - DATA_START


def read_bmp(path):
    data = Path(path).read_bytes()
    if len(data) < 54 or data[:2] != b"BM":
        raise ValueError(f"{path}: not a BMP")
    size, = struct.unpack_from('<I', data, 2)
    offset, dib, width, height, planes, bits, compression = struct.unpack_from('<IIiiHHI', data, 10)
    if ((dib, planes, bits, compression) != (40, 1, 24, 0)
            or not (1 <= width <= 2048 and 1 <= abs(height) <= 2048)):
        raise ValueError(f"{path}: requires BITMAPINFOHEADER(40), 1..2048 pixels per axis, 24-bit BI_RGB")
    stride = (width * 3 + 3) & ~3
    if not (54 <= offset <= 4096 and offset + stride * abs(height) <= size <= len(data) and size <= 0x1000000):
        raise ValueError(f"{path}: invalid/truncated BMP length or pixel offset")
    return data[:size]


def build_image(paths, output):
    if len(paths) != 4:
        raise ValueError('Provide exactly four BMP files')
    output = Path(output)
    # Only a new ordinary image file. No Windows device namespaces or drive roots.
    if output.suffix.lower() != '.img' or str(output).startswith(('\\\\.\\', '\\\\?\\')):
        raise ValueError('Output must be a new regular .img file')
    manifest = output.with_suffix('.json')
    if output.exists() or manifest.exists():
        raise FileExistsError('Output image or manifest already exists; choose a new name')
    pictures = [read_bmp(path) for path in paths]
    if sum((len(data)+511)//512 for data in pictures) + 1 > CLUSTERS:
        raise ValueError('Images exceed image capacity')
    fat = bytearray(FAT_SECTORS * SECTOR)
    for index, value in enumerate((0x0ffffff8, 0xffffffff, 0x0fffffff)):
        struct.pack_into('<I', fat, index*4, value)
    root = bytearray(SECTOR)
    entries = []
    cluster = 3  # root directory is cluster 2
    for index, (path, data) in enumerate(zip(paths, pictures)):
        count = (len(data)+511)//512
        name = f'IMAGE{index+1:03d}BMP'
        entry = index*32
        root[entry:entry+11] = name.encode('ascii')
        root[entry+11] = 0x20
        struct.pack_into('<H', root, entry+20, cluster >> 16)
        struct.pack_into('<H', root, entry+26, cluster & 0xffff)
        struct.pack_into('<I', root, entry+28, len(data))
        for c in range(cluster, cluster+count):
            struct.pack_into('<I', fat, c*4, c+1 if c < cluster+count-1 else 0x0fffffff)
        entries.append(dict(source=str(Path(path).resolve()), name=f'IMAGE{index+1:03d}.BMP',
                            first_cluster=cluster, lba=DATA_START+cluster-2,
                            sectors=count, bytes=len(data),
                            width=struct.unpack_from('<i',data,18)[0],
                            signed_height=struct.unpack_from('<i',data,22)[0],
                            sha256=hashlib.sha256(data).hexdigest()))
        cluster += count
    mbr = bytearray(SECTOR)
    mbr[446:462] = struct.pack('<B3sB3sII', 0, b'\xfe\xff\xff', 0x0c,
                               b'\xfe\xff\xff', START, TOTAL-START)
    mbr[510:512] = b'\x55\xaa'
    boot = bytearray(SECTOR)
    boot[:11] = b'\xeb\x58\x90MSWIN4.1'
    struct.pack_into('<HBHBHHBHHHII', boot, 11, 512, 1, RESERVED, 2, 0, 0,
                     0xf8, 0, 63, 255, START, TOTAL-START)
    struct.pack_into('<IHHIHH', boot, 36, FAT_SECTORS, 0, 0, 2, 1, 6)
    boot[64:67] = b'\x80\x00\x29'
    struct.pack_into('<I', boot, 67, 0x20261026)
    boot[71:82] = b'HDMI PLAYER'
    boot[82:90] = b'FAT32   '
    boot[510:512] = b'\x55\xaa'
    fsinfo = bytearray(SECTOR)
    struct.pack_into('<I', fsinfo, 0, 0x41615252)
    struct.pack_into('<III', fsinfo, 484, 0x61417272, CLUSTERS-(cluster-2), cluster)
    fsinfo[508:512] = b'\x00\x00\x55\xaa'
    with output.open('xb') as stream:
        stream.truncate(TOTAL*SECTOR)
        def put(lba, data):
            stream.seek(lba*SECTOR)
            stream.write(data)
        put(0, mbr)
        for offset in (0, 6):
            put(START+offset, boot)
            put(START+offset+1, fsinfo)
        put(START+RESERVED, fat)
        put(START+RESERVED+FAT_SECTORS, fat)
        put(DATA_START, root)
        for entry, data in zip(entries, pictures):
            put(entry['lba'], data)
    result = dict(image=str(output.resolve()), bytes=TOTAL*SECTOR,
                  partition_start=START, scan_max_sector=TOTAL-1,
                  fpga_output=[640,480], scale_mode='nearest-neighbour stretch', images=entries)
    with manifest.open('x', encoding='utf-8') as stream:
        json.dump(result, stream, ensure_ascii=False, indent=2)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('images', nargs=4, type=Path)
    parser.add_argument('-o', '--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        result = build_image(args.images, args.output)
    except (ValueError, OSError) as error:
        parser.exit(1, f'{error}\n')
    print(json.dumps(result, ensure_ascii=False, indent=2))
    print('Image created only. No card or physical drive has been written.')


if __name__ == '__main__':
    main()

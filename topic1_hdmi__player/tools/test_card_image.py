"""Independent readback of MBR/BPB/FAT chains and pixel payloads."""
import hashlib
import struct
import tempfile
import unittest
from pathlib import Path
from build_card_image import build_image, read_bmp


class CardImageTest(unittest.TestCase):
    def test_filesystem_readback_and_reject(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            files = []
            for i, (width, height) in enumerate(((320,240),(800,600),(641,-479),(1920,1080))):
                header = bytearray(54)
                header[:2] = b'BM'
                stride = (width*3+3)&~3
                struct.pack_into('<I', header, 2, 54+stride*abs(height))
                struct.pack_into('<IIiiHHI', header, 10, 54, 40, width, height, 1, 24, 0)
                path = folder / f'{i}.bmp'
                path.write_bytes(header + (bytes([i,17,203])*width+bytes(stride-width*3))*abs(height))
                files.append(path)
            out = folder/'test.img'
            result = build_image(files, out)
            image = out.read_bytes()
            start, count = struct.unpack_from('<II', image, 454)
            bpb = image[start*512:(start+1)*512]
            self.assertEqual(image[510:512], b'\x55\xaa')
            self.assertEqual((start+count)*512, len(image))
            size, spc, reserved, fats = struct.unpack_from('<HBHB', bpb, 11)
            fat_size, = struct.unpack_from('<I', bpb, 36)
            self.assertEqual((size, spc, fats), (512, 1, 2))
            data_start = start + reserved + fats*fat_size
            self.assertGreaterEqual(count-reserved-fats*fat_size, 65525)  # FAT32
            fat = image[(start+reserved)*512:(start+reserved+fat_size)*512]
            self.assertEqual(fat, image[(start+reserved+fat_size)*512:data_start*512])
            directory = image[data_start*512:(data_start+1)*512]
            for i, path in enumerate(files):
                entry = directory[i*32:(i+1)*32]
                cluster = (struct.unpack_from('<H',entry,20)[0]<<16) | struct.unpack_from('<H',entry,26)[0]
                length, = struct.unpack_from('<I',entry,28)
                data = bytearray()
                visited = set()
                while cluster < 0x0ffffff8:
                    self.assertNotIn(cluster, visited)
                    visited.add(cluster)
                    lba = data_start+cluster-2
                    data += image[lba*512:(lba+1)*512]
                    nxt, = struct.unpack_from('<I', fat, cluster*4)
                    self.assertTrue(nxt==cluster+1 or nxt>=0x0ffffff8)
                    cluster = nxt
                self.assertEqual(bytes(data[:length]), path.read_bytes())
                self.assertEqual(hashlib.sha256(data[:length]).hexdigest(),result['images'][i]['sha256'])
            with self.assertRaises(FileExistsError):
                build_image(files,out)
            files[0].write_bytes(b'BM broken')
            with self.assertRaises(ValueError):
                build_image(files,folder/'invalid.img')
            self.assertFalse((folder/'invalid.img').exists())

    def test_geometry_and_truncation(self):
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'bounds.bmp'
            for w,h,accept in ((1,1,True),(2048,-2048,True),(2049,1,False),
                               (1,2049,False),(0,1,False),(1,0,False),(-1,1,False)):
                header=bytearray(54);header[:2]=b'BM'
                payload=bytes(((max(w,0)*3+3)&~3)*abs(h))
                struct.pack_into('<I',header,2,54+len(payload))
                struct.pack_into('<IIiiHHI',header,10,54,40,w,h,1,24,0)
                path.write_bytes(header+payload)
                if accept:
                    self.assertEqual(read_bmp(path),header+payload)
                    path.write_bytes((header+payload)[:-1])
                    with self.assertRaises(ValueError): read_bmp(path)
                else:
                    with self.assertRaises(ValueError): read_bmp(path)


if __name__ == '__main__':
    unittest.main()

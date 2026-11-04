"""Encode the four generated fire-safety posters as source-size BGR24 BMPs.
Requires Pillow. Keep artwork and typography unchanged; only resize/encode.
All BMPs use top-down rows to avoid backwards SD row traversal.
"""
from pathlib import Path
import argparse, shutil, struct
from PIL import Image
from build_card_image import build_image

SIZES=((320,240),(800,600),(641,479),(960,540))

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('artwork',nargs=4,type=Path)
    p.add_argument('--directory',required=True,type=Path)
    p.add_argument('--output',required=True,type=Path)
    a=p.parse_args()
    if a.directory.exists() or a.output.exists() or a.output.with_suffix('.json').exists():
        p.error('Choose new paths to preserve existing assets')
    a.directory.mkdir(parents=True)
    files=[]
    for i,(source,(w,h)) in enumerate(zip(a.artwork,SIZES),1):
        shutil.copy2(source,a.directory/f'{i:02d}_artwork.png')
        path=a.directory/f'{i:02d}_fire_{w}x{h}.bmp'
        with Image.open(source) as image:
            image.convert('RGB').resize((w,h),Image.Resampling.LANCZOS).save(path)
        data=bytearray(path.read_bytes());off=struct.unpack_from('<I',data,10)[0]
        stride=(w*3+3)&~3
        pixels=data[off:off+stride*h]
        data[off:off+stride*h]=b''.join(pixels[j*stride:(j+1)*stride] for j in range(h-1,-1,-1))
        struct.pack_into('<i',data,22,-h)
        path.write_bytes(data)
        with Image.open(path) as check:
            assert check.size==(w,h) and check.mode=='RGB'
        files.append(path)
    result=build_image(files,a.output)
    for item in result['images']:
        print(item['name'],item['width'],item['signed_height'],item['bytes'],item['lba'])
    print(result['image'])

if __name__=='__main__':main()

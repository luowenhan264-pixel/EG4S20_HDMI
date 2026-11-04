"""Generate four DIFFERENT-resolution BGR24 BMPs and a new card image.

Standard library only. These are original source-size patterns, not pre-scaled
640x480 output frames. The FPGA performs the display adaptation.
"""
import argparse
import struct
from pathlib import Path
from build_card_image import build_image

DIGITS = {
    '0': ('111','101','101','101','111'), '1': ('010','110','010','010','111'),
    '2': ('111','001','111','100','111'), '3': ('111','001','111','001','111'),
    '4': ('101','101','111','001','001'), '5': ('111','100','111','001','111'),
    '6': ('111','100','111','101','111'), '7': ('111','001','010','010','010'),
    '8': ('111','101','111','101','111'), '9': ('111','101','111','001','111'),
    'x': ('000','101','010','101','000'),
}

def pattern(width, height, top_down=False):
    stride=(width*3+3)&~3
    header=bytearray(54)
    header[:2]=b'BM'
    struct.pack_into('<I',header,2,54+stride*height)
    struct.pack_into('<IIiiHHI',header,10,54,40,width,-height if top_down else height,1,24,0)
    struct.pack_into('<I',header,34,stride*height)
    label=f'{width}x{height}'
    cell=max(1,width//64)
    tx=(width-len(label)*4*cell)//2
    ty=height//2-2*cell
    border=max(1,min(width,height)//60)
    radius=min(width,height)//3
    body=bytearray()
    rows=range(height) if top_down else range(height-1,-1,-1)
    for y in rows:
        row=bytearray()
        for x in range(width):
            if y<height//2:
                rgb=(210,45,50) if x<width//2 else (40,180,90)
            else:
                rgb=(40,95,220) if x<width//2 else (230,175,30)
            d=(x-width//2)**2+(y-height//2)**2
            if abs(d-radius**2)<radius*border: rgb=(245,245,245)
            if min(x,width-1-x,y,height-1-y)<border: rgb=(255,255,255)
            # One top bar, two bottom bars: orientation remains visible on screen.
            if width//4<x<width*3//4 and (height//12<y<height//12+border*3 or
                    height*10//12<y<height*10//12+border*3 or
                    height*11//12<y<height*11//12+border*3): rgb=(20,20,30)
            xx=(x-tx)//cell; yy=(y-ty)//cell
            if 0<=xx<len(label)*4 and 0<=yy<5:
                if xx%4<3 and DIGITS[label[xx//4]][yy][xx%4]=='1': rgb=(255,255,255)
            row.extend(reversed(rgb))
        row.extend(bytes(stride-width*3)); body.extend(row)
    return header+body

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    if args.directory.exists() or args.output.exists() or args.output.with_suffix('.json').exists():
        parser.error('Choose new output names; existing files are preserved')
    args.directory.mkdir(parents=True)
    paths=[]
    for i,(w,h,td) in enumerate(((320,240,False),(800,600,False),(641,479,True),(1920,1080,False))):
        path=args.directory/f'{i+1:02d}_{w}x{h}.bmp'
        path.write_bytes(pattern(w,h,td)); paths.append(path)
    result=build_image(paths,args.output)
    for item in result['images']:
        print(item['name'],item['width'],item['signed_height'],'LBA',item['lba'])
    print(result['image'])

if __name__=='__main__': main()

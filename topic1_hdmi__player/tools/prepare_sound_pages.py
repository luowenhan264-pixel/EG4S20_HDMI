"""Encode approved sound-science artwork as four source-size top-down BMPs.
Pillow is used only for deterministic resizing and format conversion.
Does not change FPGA source, card images, or existing media folders.
"""
import argparse,hashlib,json,shutil,struct
from pathlib import Path
from PIL import Image

PAGES=[('sound_wave',320,240),('pitch_frequency',800,600),
       ('volume_amplitude',641,479),('music_mixing',960,540)]

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('artwork',nargs=4,type=Path)
    p.add_argument('--output',required=True,type=Path)
    a=p.parse_args()
    a.output.mkdir(parents=True,exist_ok=False)
    records=[]
    for i,(source,(name,w,h)) in enumerate(zip(a.artwork,PAGES),1):
        original=a.output/f'{i:02d}_{name}_artwork.png'
        target=a.output/f'{i:02d}_{name}_{w}x{h}.bmp'
        shutil.copy2(source,original)
        with Image.open(source) as im:
            rgb=im.convert('RGB').resize((w,h),Image.Resampling.LANCZOS)
            rgb.save(target)
        b=bytearray(target.read_bytes());offset=struct.unpack_from('<I',b,10)[0]
        stride=(w*3+3)&~3;raw=b[offset:offset+stride*h]
        b[offset:offset+stride*h]=b''.join(raw[j*stride:(j+1)*stride] for j in range(h-1,-1,-1))
        struct.pack_into('<i',b,22,-h);target.write_bytes(b)
        with Image.open(target) as check:
            assert check.size==(w,h) and check.convert('RGB').tobytes()==rgb.tobytes()
        assert struct.unpack_from('<IIiiHHI',b,10)==(54,40,w,-h,1,24,0)
        records.append(dict(index=i,name=name,width=w,height=h,bmp=target.name,
                            original=original.name,sha256=hashlib.sha256(b).hexdigest()))
    (a.output/'manifest.json').write_text(json.dumps(dict(pages=records,output_resolution=[640,480],
        proposed_waveform_pixels=[32,344,576,64],subtitle_y=[444,468],
        artwork_only=True),ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(records,indent=2))

if __name__=='__main__':main()

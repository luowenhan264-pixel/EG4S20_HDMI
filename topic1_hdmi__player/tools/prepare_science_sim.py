"""Convert real source BMPs into nearest-neighbour VGA testbench pixels (stdlib)."""
from pathlib import Path
import struct,sys
root=Path(__file__).resolve().parents[1]
out=Path(sys.argv[1])
for i,p in enumerate(sorted((root/'doc/sound_science_pages').glob('*.bmp'))):
    b=p.read_bytes();offset=struct.unpack_from('<I',b,10)[0]
    w,h=struct.unpack_from('<ii',b,18);stride=(w*3+3)&~3
    with (out/f'science_background{i}.hex').open('w') as f:
        for y in range(480):
            sy=y*abs(h)//480
            if h>0: sy=h-1-sy
            for x in range(640):
                pos=offset+sy*stride+(x*w//640)*3
                f.write(b[pos:pos+3][::-1].hex()+'\n')

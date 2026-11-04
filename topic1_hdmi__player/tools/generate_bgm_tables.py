"""Generate deterministic ROM tables for the project's original loop.
Only generates constants; synthesis and playback run entirely in the FPGA.
"""
import math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
fs=12_295_082/256
notes=[261.625565,329.627557,391.995436,329.627557,
       293.664768,349.228231,440.0,349.228231,
       329.627557,391.995436,523.251131,391.995436,
       293.664768,349.228231,391.995436,0,
       261.625565,329.627557,440.0,391.995436,
       349.228231,329.627557,293.664768,0,
       329.627557,391.995436,329.627557,293.664768,
       261.625565,293.664768,261.625565,0]
s='// Original 32-step C-major loop, about 80 BPM / 24 seconds.\n'
s+='function [31:0] melody_inc; input [4:0] step; begin case(step)\n'
s+=''.join(f"5'd{i}:melody_inc=32'd{round(f*2**32/fs)};\n" for i,f in enumerate(notes))
s+='endcase end endfunction\n'
s+='function [31:0] bass_inc; input [1:0] chord; begin case(chord)\n'
s+=''.join(f"2'd{i}:bass_inc=32'd{round(f*2**32/fs)};\n" for i,f in enumerate([130.812783,110.0,87.307058,97.998859]))
s+='endcase end endfunction\n'
s+='function signed [15:0] sine; input [7:0] phase; reg [5:0] addr; reg [14:0] mag; begin\n'
s+='addr=phase[6] ? ~phase[5:0] : phase[5:0];\ncase(addr)\n'
s+=''.join(f"6'd{i}:mag=15'd{round(32767*math.sin(i*math.pi/126))};\n" for i in range(64))
s+='endcase\nsine=phase[7] ? -$signed({1\'b0,mag}) : $signed({1\'b0,mag});\nend endfunction\n'
p=ROOT/'src/user_source/hdl_source/background_music.v'
text=p.read_text(encoding='utf-8')
start='// BEGIN GENERATED BGM TABLES'
end='// END GENERATED BGM TABLES'
block=start+'\n'+s+end
if start in text:
    a=text.index(start);b=text.index(end,a)+len(end)
    text=text[:a]+block+text[b:]
else:
    text=text.replace('`include "bgm_tables.vh"',block)
p.write_text(text,encoding='utf-8')

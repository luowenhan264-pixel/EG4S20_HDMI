`timescale 1ns/1ps
module tb_background_music_link;
reg clk=0,mclk=0,rst=1,event_toggle=0,en=0,vs=1;
always #20 clk=~clk;always #40.667 mclk=~mclk;
reg [1:0] volume=3;
wire bclk,lrck,dout,cv,mv;wire [23:0] cl,cr,ml,mr;
hdmi_audio_link_i2s #(.CUE_SAMPLES(2048)) cue(mclk,rst,event_toggle,2'd0,bclk,lrck,dout,volume,1'b0);
I2S_receiver receiver(clk,rst,bclk,lrck,dout,cv,cl,cr);
background_music music(clk,rst,en,volume,cv,cl,cr,mv,ml,mr);
audio_visualizer scope(clk,rst,1'b1,1'b0,vs,1'b0,24'd0,mv,ml,mr,,,,);
reg [23:0] cue_value;
integer samples=0,music_seen=0,cue_seen=0,diff;
always @(posedge clk) if(!rst)begin
 if(cv)cue_value<=cl;
 if(mv)begin
  if(ml!==mr)$fatal(1,"stereo output");
  diff=$signed(ml)-$signed(cue_value);
  if(diff>164000 || diff< -164000)$fatal(1,"mix cadence or amplitude");
  if(cue_value==0 && ml!=0)music_seen<=music_seen+1;
  if(cue_value!=0 && ml!=cue_value)cue_seen<=cue_seen+1;
  samples<=samples+1;
 end
end
task wait_samples(input integer n);
 integer start;
 begin start=samples;wait(samples>=start+n);@(negedge clk);end
endtask
task publish;
 begin wait(scope.pending);@(negedge clk);vs=0;repeat(4)@(negedge clk);vs=1;end
endtask
initial begin
 repeat(10)@(negedge clk);rst=0;wait_samples(10);
 if(music_seen!=0)$fatal(1,"music before picture enable");
 en=1;publish();wait_samples(800);publish();
 if(music_seen<100 || !scope.show_valid || scope.show_peak_l==0)$fatal(1,"BGM not visualized");
 event_toggle=1;wait_samples(2200);publish();
 if(cue_seen<100)$fatal(1,"cue not mixed");
 volume=0;wait_samples(300);publish();wait_samples(300);publish();
 if(scope.show_peak_l!=0 || scope.show_peak_r!=0)$fatal(1,"scope mute");
 if(ml!=0 || mr!=0)$fatal(1,"master mute");
 $display("PASS tb_background_music_link: real I2S cue + BGM mixer + waveform, startup enable, ongoing music, cue overlap, volume mute");$finish;
end
initial begin #150000000;$fatal(1,"watchdog");end
endmodule

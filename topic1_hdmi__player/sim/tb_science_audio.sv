`timescale 1ns/1ps
module tb_science_audio;
reg clk=0;always #5 clk=~clk;
reg rst=1,sv=0,en=1;reg [1:0] page=0,choice=0,vol=3;
wire av;wire [23:0] l,r,bg;wire [1:0] ap,ac;
science_audio dut(clk,rst,sv,en,page,choice,vol,av,l,r,bg,ap,ac,);
integer value=0,background=0,received=0,sent=0,i,k,crossings,last,peak,peaks[0:2],music_hits,cue_hits,mix_hits,quiet_hits;
reg old_av=0;
always @(posedge clk)begin
 #1;
 if(av)begin
  if(l!==r)$fatal(1,"stereo mismatch");
  if(^l===1'bx||^bg===1'bx)$fatal(1,"unknown PCM");
  value=$signed(l);background=$signed(bg);received++;
  if(value>600000||value< -600000)$fatal(1,"unexpected clipping/loud output %d",value);
 end
 if(av&&old_av)$fatal(1,"valid wider than one clock");old_av=av;
end
task sample;begin
 @(negedge clk);sv=1;sent++;@(negedge clk);sv=0;repeat(10)@(negedge clk);
end endtask
task settle;begin repeat(530)sample();end endtask
initial begin
 repeat(5)@(negedge clk);rst=0;
 for(k=0;k<3;k++)begin
  page=1;choice=k;settle();crossings=0;last=value;peak=0;
  for(i=0;i<48028;i++)begin
   sample();if(last<0&&value>=0)crossings++;last=value;
   if(value>peak)peak=value;if(background!=0)$fatal(1,"BGM in pure tone page");
  end
  if(crossings<((k==0)?219:(k==1)?439:879)||crossings>((k==0)?221:(k==1)?441:881))$fatal(1,"frequency %d crossings %d",k,crossings);
  if(peak<250000||peak>263000)$fatal(1,"tone amplitude %d",peak);
 end
 page=2;
 for(k=0;k<3;k++)begin
  choice=k;settle();peak=0;repeat(1000)begin sample();if(value>peak)peak=value;end peaks[k]=peak;
 end
 if(peaks[1]<peaks[0]*2-3||peaks[1]>peaks[0]*2+3||peaks[2]<peaks[1]*2-3||peaks[2]>peaks[1]*2+3)$fatal(1,"amplitude ratios %d %d %d",peaks[0],peaks[1],peaks[2]);
 choice=3;settle();repeat(600)begin sample();if(value)$fatal(1,"amp stop");end
 page=0;choice=2;settle();repeat(500)begin sample();if(value!=261112&&value!= -261113)$fatal(1,"square shape %d",value);end
 choice=1;settle();peak=0;repeat(1000)begin sample();if(value>peak)peak=value;end if(peak<250000)$fatal(1,"triangle");
 page=3;choice=0;settle();music_hits=0;repeat(3000)begin sample();if(value!=background)$fatal(1,"music only trace");if(value)music_hits++;end
 if(music_hits<1000)$fatal(1,"no music");
 choice=1;settle();cue_hits=0;quiet_hits=0;
 repeat(100000)begin sample();if(background)$fatal(1,"BGM in cue-only");if(value)cue_hits++;else quiet_hits++;end
 if(cue_hits<9000||quiet_hits<80000)$fatal(1,"periodic cue duty %d / %d",cue_hits,quiet_hits);
 choice=2;settle();mix_hits=0;music_hits=0;
 repeat(12000)begin sample();if(background)music_hits++;if(value!=background)mix_hits++;end
 if(mix_hits<7000||music_hits<8000)$fatal(1,"mix missing component");
 vol=0;settle();repeat(1000)begin sample();if(value||background)$fatal(1,"master mute");end
 vol=2;choice=3;settle();repeat(1000)begin sample();if(value||background)$fatal(1,"music stop");end
 page=0;choice=0;settle();en=0;settle();repeat(300)begin sample();if(value)$fatal(1,"display invalid sound");end
 if(received!=sent)$fatal(1,"cadence sent=%d received=%d",sent,received);
 $display("PASS tb_science_audio: 220/440/880Hz, equal peaks, 25/50/100 ratios, waveform, periodic cue, music/mix traces, master mute, fade, cadence");$finish;
end
initial begin #100000000;$fatal(1,"watchdog");end
endmodule

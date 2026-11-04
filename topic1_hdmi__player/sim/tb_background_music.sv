`timescale 1ns/1ps
module tb_background_music;
reg clk=0;always #5 clk=~clk;
reg rst=1,en=0,valid=0;reg [1:0] vol=3;
reg [23:0] l=0,r=0;
wire ov;wire [23:0] ol,orr;
background_music dut(clk,rst,en,vol,valid,l,r,ov,ol,orr);
localparam N=36021*32;
reg signed [23:0] reference[0:N-1];
integer i,j,k,value,peak=0,nonzero=0,fd,pcm;
reg [3:0] expected_valid=0;
always @(posedge clk)begin
 if(rst)expected_valid=0;
 else begin
  #1;if(ov!==expected_valid[3])$fatal(1,"sample cadence/latency");
  if(!ov && (ol!=0 || orr!=0))$fatal(1,"invalid cycles not blank");
  expected_valid={expected_valid[2:0],valid};
 end
end
task sample(input integer left_value,right_value);
 begin
 @(negedge clk);valid=1;l=left_value;r=right_value;
 @(negedge clk);valid=0;
 repeat(4)@(negedge clk);
 if(!ov)$fatal(1,"missing output sample");
 end
endtask
task reset;
 begin @(negedge clk);rst=1;valid=0;repeat(3)@(negedge clk);rst=0;end
endtask
initial begin
 reset();
 sample(123456,-765432);if($signed(ol)!=123456 || $signed(orr)!=-765432)$fatal(1,"disabled bypass");
 vol=0;sample(100000,200000);if(ol!=0 || orr!=0)$fatal(1,"master mute");
 vol=3;en=1;reset();
 fd=$fopen("background_music_s16le.pcm","wb");
 for(i=0;i<N;i=i+1)begin
  sample(0,0);reference[i]=ol;
  if(ol!==orr)$fatal(1,"music stereo mismatch");
  value=$signed(ol);if(value<0)value=-value;
  if(value>peak)peak=value;if(value!=0)nonzero=nonzero+1;
  if(value>164000)$fatal(1,"excessive music amplitude");
  pcm=$signed(ol)>>>8;
  $fwrite(fd,"%c%c%c%c",pcm&255,(pcm>>8)&255,pcm&255,(pcm>>8)&255);
 end
 $fclose(fd);
 if(dut.step!=0 || dut.beat_count!=0 || peak<80000 || nonzero<N/2)$fatal(1,"loop duration/content");
 // Full second loop must reproduce the first sample-for-sample.
 for(i=0;i<N;i=i+1)begin sample(0,0);if(ol!==reference[i])$fatal(1,"loop mismatch %d",i);end
 for(j=0;j<4;j=j+1)begin
  vol=j;reset();
  for(i=0;i<5000;i=i+1)begin
   sample(0,0);
   value=j==0 ? 0 : j==1 ? reference[i]>>>2 : j==2 ? reference[i]>>>1 : reference[i];
   if($signed(ol)!=value)$fatal(1,"volume %d index %d",j,i);
  end
 end
 // Inject independent stereo cues; both are mixed with exactly the same music.
 vol=3;reset();
 for(i=0;i<5000;i=i+1)begin
  sample(500000,-250000);
  if($signed(ol)!=reference[i]+500000 || $signed(orr)!=reference[i]-250000)$fatal(1,"cue mixing");
 end
 reset();
 for(i=0;i<5000;i=i+1)begin
  sample(8388607,-8388608);
  value=reference[i]>0 ? 8388607:8388607+reference[i];
  if($signed(ol)!=value)$fatal(1,"positive saturation");
  value=reference[i]<0 ? -8388608:-8388608+reference[i];
  if($signed(orr)!=value)$fatal(1,"negative saturation");
 end
 en=0;sample(123,-456);if($signed(ol)!=123 || $signed(orr)!=-456)$fatal(1,"enable bypass");
 en=1;sample(0,0);if(ol!=reference[0])$fatal(1,"enable restart");
 $display("PASS tb_background_music: two complete 24s loops, amplitude, sample cadence, volume/mute, stereo cue mixing, saturation, enable/reset; peak=%d",peak);
 $finish;
end
initial begin #200000000;$fatal(1,"watchdog");end
endmodule

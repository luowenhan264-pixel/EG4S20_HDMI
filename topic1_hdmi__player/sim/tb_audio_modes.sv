`timescale 1ns/1ps
module tb_audio_modes;
reg clk=0,mclk=0,rst=1,event_toggle=0;
always #20 clk=~clk;always #40.667 mclk=~mclk;
reg [1:0] image_id=0;reg [2:0] cfg=7;
wire [2:0] audio_cfg;wire bclk,lrck,dout,valid;wire [23:0] left_pcm,right_pcm;
player_config_cdc #(.WIDTH(3),.RESET_VALUE(3'b111)) mailbox(clk,rst,cfg,mclk,rst,audio_cfg);
hdmi_audio_link_i2s #(.CUE_SAMPLES(1024)) cue(mclk,rst,event_toggle,image_id,bclk,lrck,dout,audio_cfg[2:1],audio_cfg[0]);
I2S_receiver receiver(clk,rst,bclk,lrck,dout,valid,left_pcm,right_pcm);
task sample;
 begin @(posedge clk);#2;while(!valid)begin @(posedge clk);#2;end
 if(left_pcm!==right_pcm || $isunknown(left_pcm))$fatal(1,"stereo/unknown");end
endtask
task trigger(input [1:0] id,input [1:0] vol,input mode);
 begin cfg={vol,mode};repeat(40)@(negedge clk);
 image_id=id;event_toggle=~event_toggle;end
endtask
task note(input integer expected_crossings,input integer expected_peak);
 integer n,crossings,previous,pcm,peak,timeout;
 begin
 n=0;crossings=0;previous=0;peak=0;timeout=0;
 sample();while(left_pcm==0 && timeout<8)begin sample();timeout=timeout+1;end
 while(left_pcm!=0 && n<1100)begin
   pcm=$signed(left_pcm);n=n+1;
   if((pcm<0 && previous>0)||(pcm>0 && previous<0))crossings=crossings+1;
   previous=pcm;if(pcm>peak)peak=pcm;
   if(pcm>expected_peak || pcm< -expected_peak)$fatal(1,"volume overflow");sample();
 end
 if(n!=1023 || crossings<expected_crossings-1 || crossings>expected_crossings+1 || peak!=expected_peak)
   $fatal(1,"note mismatch count=%0d crossings=%0d peak=%0d",n,crossings,peak);
 end
endtask
integer k;
initial begin
 repeat(10)@(negedge clk);rst=0;repeat(5)sample();
 trigger(0,3,1);note(11,500000);note(14,500000);
 trigger(1,2,1);note(14,250000);note(16,250000);
 trigger(2,1,1);note(16,125000);note(22,125000);
 trigger(3,3,1);note(22,500000);
 cfg={2'd3,1'b0};note(28,500000); // changing mode preserves this cue's second note
 trigger(0,3,0);note(11,500000);
 for(k=0;k<1050;k=k+1)begin sample();if(left_pcm!=0)$fatal(1,"single mode repeats");end
 trigger(2,0,1);
 for(k=0;k<2060;k=k+1)begin sample();if(left_pcm!=0)$fatal(1,"mute");end
 // A new picture cancels both the current note and its queued second note.
 trigger(0,3,1);repeat(20)sample();trigger(3,3,0);
 sample();while(left_pcm!=0)sample();note(22,500000);
 for(k=0;k<1050;k=k+1)begin sample();if(left_pcm!=0)$fatal(1,"old second note survived retrigger");end
 trigger(3,3,1);repeat(30)sample();cfg={2'd0,1'b1};repeat(6)sample();
 for(k=0;k<20;k=k+1)begin sample();if(left_pcm!=0)$fatal(1,"runtime mute delayed");end
 rst=1;repeat(10)@(negedge clk);rst=0;repeat(5)sample();
 for(k=0;k<20;k=k+1)begin sample();if(left_pcm!=0)$fatal(1,"reset left pending second note");end
 $display("PASS tb_audio_modes: four two-note signatures, 4 volume levels, live mute, mode latch, retrigger cancels old second note, stereo, reset");$finish;
end
initial begin #400000000;$fatal(1,"watchdog");end
endmodule

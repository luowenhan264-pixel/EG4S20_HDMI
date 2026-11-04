`timescale 1ns/1ps
module tb_audio_visualizer_link;
reg clk=0,mclk=0,rst=1,event_toggle=0,vs=1;
always #20 clk=~clk;always #40.667 mclk=~mclk;
reg [1:0] volume=3;
wire bclk,lrck,dout,valid;wire [23:0] l,r;
hdmi_audio_link_i2s #(.CUE_SAMPLES(12000)) cue(mclk,rst,event_toggle,2'd2,bclk,lrck,dout,volume,1'b1);
I2S_receiver receiver(clk,rst,bclk,lrck,dout,valid,l,r);
audio_visualizer scope(clk,rst,1'b1,1'b0,vs,1'b0,24'd0,valid,l,r,,,,);
integer i,j;
task snapshot;
 begin
 wait(scope.pending);@(negedge clk);vs=0;repeat(4)@(negedge clk);vs=1;
 if(!scope.show_valid)$fatal(1,"no captured PCM");
 end
endtask
initial begin
 repeat(10)@(negedge clk);rst=0;
 snapshot();if(scope.show_peak_l!=0)$fatal(1,"idle should be silent");
 event_toggle=1;
 // Envelope rises for 256 samples; discard two startup snapshots.
 snapshot();snapshot();snapshot();
 if(scope.show_peak_l!=30 || scope.show_peak_r!=30)$fatal(1,"post-I2S full-volume amplitude");
 volume=2;snapshot();snapshot();
 if(scope.show_peak_l!=15 || scope.show_peak_r!=15)$fatal(1,"half volume");
 volume=1;snapshot();snapshot();
 if(scope.show_peak_l!=7 || scope.show_peak_r!=7)$fatal(1,"quarter volume");
 volume=0;snapshot();snapshot();
 if(scope.show_peak_l!=0 || scope.show_peak_r!=0)$fatal(1,"mute amplitude");
 for(i=0;i<256;i=i+1)if(scope.samples[{scope.show_bank,8'(i)}]!=={6'd32,6'd32,6'd32,6'd32})$fatal(1,"mute waveform");
 $display("PASS tb_audio_visualizer_link: actual cue serializer + I2S receiver + scope, stereo PCM, volume 3/2/1/0, silent baseline");$finish;
end
initial begin #150000000;$fatal(1,"watchdog");end
endmodule

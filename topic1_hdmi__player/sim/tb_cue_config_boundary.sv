`timescale 1ns/1ps
// Sweep the presentation edge across a whole audio sample period. The same
// video edge changes picture and mode, as when a settings snapshot coincides
// with a black-frame bank swap in top. Check decoded PCM, not internal state.
module tb_cue_config_boundary;
reg clk=0,mclk=0,rst=1,present_valid=0;
always #20 clk=~clk;always #40.667 mclk=~mclk;
reg [1:0] bank=0,image_id=0;
reg [2:0] settings=3'b110;
wire event_toggle,event_mode;wire [1:0] event_image;wire [1:0] audio_volume;
wire bclk,lrck,dout,pcm_valid;wire [23:0] left_pcm,right_pcm;
player_picture_event events(clk,rst,present_valid,bank,image_id,event_toggle,event_image,settings[0],event_mode);
player_config_cdc #(.WIDTH(2),.RESET_VALUE(2'b11))
 config_cdc(clk,rst,settings[2:1],mclk,rst,audio_volume);
hdmi_audio_link_i2s #(.CUE_SAMPLES(8))
 cue(mclk,rst,event_toggle,event_image,bclk,lrck,dout,audio_volume,event_mode);
I2S_receiver receiver(clk,rst,bclk,lrck,dout,pcm_valid,left_pcm,right_pcm);
task sample;
 begin @(posedge clk);#2;while(!pcm_valid)begin @(posedge clk);#2;end
 if(left_pcm!==right_pcm || $isunknown(left_pcm))$fatal(1,"PCM mismatch");end
endtask
integer offset,k,nonzero;
initial begin
 for(offset=0;offset<256;offset=offset+1) begin
   @(negedge clk);rst=1;present_valid=0;bank=0;settings=3'b110;
   repeat(8)@(negedge clk);rst=0;repeat(5)sample();
   @(negedge lrck);repeat(offset)@(posedge mclk);
   @(negedge clk);settings=3'b111;bank=1;present_valid=1;
   nonzero=0;
   for(k=0;k<24;k=k+1)begin sample();if(left_pcm!=0)nonzero=nonzero+1;end
   if(nonzero!=14)$fatal(1,"mode/picture race at audio offset %0d: expected two notes (14 nonzero samples), got %0d",offset,nonzero);
 end
 $display("PASS tb_cue_config_boundary: 256 phases, simultaneous picture/config change, two notes decoded correctly");$finish;
end
initial begin #250000000;$fatal(1,"watchdog");end
endmodule

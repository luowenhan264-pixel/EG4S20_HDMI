`timescale 1ns/1ps
module tb_video;
reg clk=0;always #20 clk=~clk;
reg rst=1,frame_start=0,toggle=0;
reg [1:0] bank=0,img=0;
wire ack,valid;
wire [1:0] active_bank,active_img;
player_frame_commit #(.FADE_ENABLE(0)) dut(clk,rst,frame_start,toggle,bank,img,ack,active_bank,active_img,valid,,);
reg hs=0,vs=1,de=0;
reg [23:0] rgb=0;
wire oh,ov,od;
wire [23:0] out_rgb;
osd_overlay_640x480 osd(clk,rst,hs,vs,de,2'd0,1'b0,4'd0,rgb,out_rgb,oh,ov,od);
wire local_rst;
player_reset_sync rs(clk,rst,local_rst);
integer i;
initial begin
 repeat(3) @(negedge clk); rst=0;
 repeat(2) @(negedge clk);
 if(!local_rst) $fatal(1,"reset released too early");
 @(negedge clk);if(local_rst) $fatal(1,"reset did not release");
 bank=1;img=2;toggle=1;
 repeat(8) @(negedge clk);
 if(ack || valid || active_bank) $fatal(1,"midframe swap");
 frame_start=1; @(negedge clk);frame_start=0;
 if(!ack || !valid || active_bank!=1 || active_img!=2) $fatal(1,"commit");
 bank=0;img=3;toggle=0;
 repeat(8) @(negedge clk);
 if(!ack || active_bank!=1) $fatal(1,"early bank reuse");
 frame_start=1;@(negedge clk);frame_start=0;
 if(ack || active_bank!=0 || active_img!=3) $fatal(1,"second commit");
 // First line lies outside overlay. Check both DE edges and all 640 pixels.
 vs=0;repeat(3) @(negedge clk);
 for(i=0;i<642;i=i+1) begin
   de=(i<640);rgb=24'h123400+i;hs=i[0];
   @(posedge clk);#1;
   if(od!==de || ov!==vs || oh!==hs || out_rgb!==(de?rgb:24'd0))
     $fatal(1,"RGB/timing mismatch at pixel %0d",i);
   @(negedge clk);
 end
 #3 rst=1;#1;if(!local_rst) $fatal(1,"async reset assertion");
 $display("PASS tb_video: frame-boundary handshake, OSD alignment, reset synchronization");$finish;
end
endmodule

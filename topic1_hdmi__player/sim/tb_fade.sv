`timescale 1ns/1ps
module tb_fade;
reg clk=0;always #20 clk=~clk;
reg rst=1,frame_start=0,request=0;
reg [1:0] bank=0,image_id=0;
wire ack,valid,busy;
wire [1:0] active_bank,active_image;
wire [5:0] gain;
player_frame_commit #(.FRAMES_PER_STEP(2)) dut(clk,rst,frame_start,request,
    bank,image_id,ack,active_bank,active_image,valid,gain,busy);
reg hs=0,vs=0,de=0;
reg [23:0] rgb=0;
reg [5:0] scale=0;
wire ho,vo,dout;
wire [23:0] result;
video_fade_rgb pixels(clk,rst,hs,vs,de,rgb,scale,ho,vo,dout,result);
integer i,j,expected;
task frame;
 begin
 @(negedge clk);frame_start=1;
 @(negedge clk);frame_start=0;
 repeat(4) @(negedge clk);
 end
endtask
task expect_gain(input integer value);
 begin
 if(gain!==value) $fatal(1,"gain expected %0d got %0d",value,gain);
 end
endtask
initial begin
 repeat(4) @(negedge clk);rst=0;
 request=1;image_id=2;bank=1;
 repeat(8) @(negedge clk);
 if(valid || ack) $fatal(1,"commit outside blank");
 frame();expect_gain(0);
 if(!valid || active_bank!=1 || active_image!=2) $fatal(1,"first image");
 for(i=1;i<=32;i=i+1) begin
   frame();expect_gain(i-1);
   if(ack) $fatal(1,"early ack");
   frame();expect_gain(i);
 end
 if(!ack || busy) $fatal(1,"first fade-in completion");
 bank=0;image_id=3;request=0;
 repeat(9) @(negedge clk);expect_gain(32);
 frame();expect_gain(32);
 for(i=31;i>=0;i=i-1) begin
   frame();expect_gain(i+1);
   frame();expect_gain(i);
   if(active_bank!=1 || !ack) $fatal(1,"early swap/reuse");
 end
 frame();expect_gain(0);
 if(active_bank!=0 || active_image!=3 || !ack) $fatal(1,"black swap");
 for(i=1;i<=32;i=i+1) begin
   frame();expect_gain(i-1);frame();expect_gain(i);
   if(i<32 && !ack) $fatal(1,"early fade-in ack");
 end
 if(ack || busy) $fatal(1,"final ack");
 // Exhaustively check every gain and all 256 channel values, plus blanking.
 for(i=0;i<=32;i=i+1) for(j=0;j<256;j=j+1) begin
   @(negedge clk);scale=i;rgb={8'(j),8'(255-j),8'(j^8'h55)};
   de=(j!=255);hs=j[0];vs=j[1];
   @(posedge clk);#1;
   if(ho!==hs || vo!==vs || dout!==de) $fatal(1,"timing alignment");
   if(de) begin
     if(result !== {8'((j*i)>>5),8'(((255-j)*i)>>5),8'(((j^8'h55)*i)>>5)})
       $fatal(1,"RGB arithmetic gain=%0d pixel=%0d",i,j);
   end else if(result!=0) $fatal(1,"blanking must be black");
 end
 // Reset during fade-out must cancel pending presentation cleanly.
 @(negedge clk);request=1;bank=1;
 repeat(6) @(negedge clk);frame();frame();
 #7 rst=1;#1;
 if(valid || ack || gain) $fatal(1,"reset during fade");
 $display("PASS tb_fade: 33 levels, configured duration, black-only bank swap, delayed ACK, RGB/sync arithmetic, reset");
 $finish;
end
initial begin #2000000;$fatal(1,"watchdog");end
endmodule

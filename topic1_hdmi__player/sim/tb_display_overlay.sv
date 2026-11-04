`timescale 1ns/1ps
module tb_display_overlay;
reg clk=0,rst=1,hs=0,vs=1,de=0,menu=1,sub=1;
reg [2:0] field=3,contrast=2;
reg [3:0] brightness=4;
reg [1:0] img=0;
wire ho,vo,dout;wire [23:0] out;
always #5 clk=~clk;
player_settings_osd #(.PIXEL_HZ(1000)) dut(clk,rst,hs,vs,de,24'h406080,menu,field,2'd0,2'd3,1'b1,
 ho,vo,dout,out,brightness,contrast,sub,img);
integer x,y,f,k,ink_count,oldscroll;
reg [3:0] oldsec;
task frame_begin;
begin
 de=0;vs=1;repeat(4)@(negedge clk);vs=0;repeat(4)@(negedge clk);
end
endtask
initial begin
 repeat(4)@(negedge clk);rst=0;
 frame_begin();oldscroll=dut.scroll;oldsec=dut.show_so;
 f=$fopen("display_overlay.ppm","w");$fwrite(f,"P3\n640 480\n255\n");ink_count=0;
 for(y=0;y<480;y=y+1)begin
   for(x=0;x<640;x=x+1)begin
     de=1;hs=x[0];@(posedge clk);#1;
     if(!dout || ho!==hs || vo!==vs)$fatal(1,"sync");
     if(dut.scroll!=oldscroll || dut.show_so!=oldsec)$fatal(1,"mid-frame text mutation");
     if(y==60 && x==8 && out!=24'hffff00)$fatal(1,"brightness selected");
     if(y==60 && x==154 && out!=24'he0e0e0)$fatal(1,"contrast label");
     if(y>=444 && y<468 && out==24'hffffff)ink_count=ink_count+1;
     if(y==445 && out!=24'h203040)$fatal(1,"subtitle alpha background");
     if(y==100 && out!=24'h406080)$fatal(1,"outside overlay");
     $fwrite(f,"%0d %0d %0d\n",out[23:16],out[15:8],out[7:0]);
     @(negedge clk);
   end
   de=0;@(posedge clk);#1;if(dout || out!=0)$fatal(1,"blanking");repeat(4)@(negedge clk);
 end
 $fclose(f);if(ink_count<100)$fatal(1,"no readable subtitle");
 img=3;frame_begin();if(dut.scroll!=oldscroll+2 || dut.show_image!=3)$fatal(1,"frame scroll/image update");
 if(dut.show_so==oldsec && dut.show_st==0)$fatal(1,"elapsed time not updated");
 // Check full scroll cycle without rendering every pixel.
 for(k=0;k<705;k=k+1)begin
   oldscroll=dut.scroll;frame_begin();
   if(dut.scroll!==(oldscroll>=1406 ? 0 : oldscroll+2))$fatal(1,"scroll wrap");
 end
 // Subtitle disabled: full-frame transparent pass-through with menu closed.
 sub=0;menu=0;frame_begin();
 for(y=0;y<480;y=y+1)begin
  for(x=0;x<640;x=x+1)begin de=1;@(posedge clk);#1;if(out!=24'h406080)$fatal(1,"disabled overlay");@(negedge clk);end
  de=0;repeat(4)@(negedge clk);
 end
 rst=1;repeat(3)@(negedge clk);if(dut.scroll!=640 || dut.sec_ones!=0 || dout)$fatal(1,"reset");
 $display("PASS tb_display_overlay: two-row labels, highlight, text render, alpha strip, frame-only motion/time/image, wrap, subtitle disable, reset");$finish;
end
initial begin #20000000;$fatal(1,"watchdog");end
endmodule

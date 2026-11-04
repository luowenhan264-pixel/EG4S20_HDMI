`timescale 1ns/1ps
module tb_picture_adjust;
reg clk=0,rst=1,hs=0,vs=0,de=0;
reg [23:0] rgb=0;
reg [3:0] brightness=4;
reg [2:0] contrast=2;
wire ho,vo,dout;wire [23:0] out;
always #5 clk=~clk;
video_picture_adjust dut(clk,rst,hs,vs,de,rgb,brightness,contrast,ho,vo,dout,out);
function [7:0] ref_channel(input integer p,b,c);
 integer z;begin
   // Integer floor for negative quarter values, independent of HDL shifts.
   z=(p-128)*(c+2);z=z<0 ? -((-z+3)/4) : z/4;
   z=z+128+(b-4)*16;ref_channel=z<0 ? 0 : z>255 ? 255 : z;
 end
endfunction
reg [23:0] expected=0,previous=0;
reg eh=0,ev=0,ed=0,ph=0,pv=0,pd=0;
integer b,c,p,count=0;
always @(posedge clk) begin
 if(rst) begin previous=0;ph=0;pv=0;pd=0;end
 else begin
   expected=de ? {ref_channel(rgb[23:16],brightness,contrast),ref_channel(rgb[15:8],brightness,contrast),ref_channel(rgb[7:0],brightness,contrast)} : 24'd0;
   eh=hs;ev=vs;ed=de;
   #1;
   if(out!==previous || ho!==ph || vo!==pv || dout!==pd)
      $fatal(1,"RGB/sync pipeline mismatch got %h expected %h b=%d c=%d",out,previous,brightness,contrast);
   previous=expected;ph=eh;pv=ev;pd=ed;count=count+1;
 end
end
initial begin
 repeat(4)@(negedge clk);rst=0;
 for(b=0;b<=8;b=b+1)for(c=0;c<=4;c=c+1)for(p=0;p<256;p=p+1)begin
    @(negedge clk);brightness=b;contrast=c;rgb={8'(p),8'(255-p),8'((p*37)%256)};
    de=p%7!=0;hs=p[0];vs=p[1];
 end
 @(negedge clk);de=0;repeat(4)@(negedge clk);
 rst=1;repeat(3)@(negedge clk);if(out!==0 || dout!==0)$fatal(1,"reset");
 $display("PASS tb_picture_adjust: all RGB levels at all 45 settings, clipping, blanking, two-stage sync, reset (%0d pixels)",count);$finish;
end
initial begin #1000000;$fatal(1,"watchdog");end
endmodule

`timescale 1ns/1ps
module tb_science_scope;
reg clk=0;always #5 clk=~clk;
reg rst=1,vs=1,de=0,av=0,trigger_=1;reg [6:0] tag=0;
reg [23:0] l=0,r=0;wire ho,vo,dout;wire [23:0] rgb;
science_scope #(.AUDIO_TIMEOUT_CYCLES(1000000)) dut(clk,rst,1'b1,1'b0,vs,de,24'h4080c0,av,l,r,trigger_,tag,ho,vo,dout,rgb);
integer i,x,y,n=0,px,py;reg render=0,bank;
always @(posedge clk)begin #1;if(render&&dout)begin
 px=n%640;py=n/640;n++;
 if(py==360 && (px==32||px==100||px==300)&&rgb!=24'h00ffff)$fatal(1,"wide cyan trace %d",px);
 if(py==369 && (px==32||px==300||px==607)&&rgb!=24'hffffff)$fatal(1,"white OUT width %d",px);
 if(px==607&&py==392&&rgb!=24'h00ffff)$fatal(1,"last sample mapping");
 if((py>=444||px<30)&&rgb!=24'h4080c0)$fatal(1,"outside panel");
end end
task sample(input integer a,b);begin @(negedge clk);av=1;l=a;r=b;@(negedge clk);av=0;end endtask
task frame;begin de=0;vs=1;repeat(4)@(negedge clk);vs=0;repeat(4)@(negedge clk);end endtask
initial begin
 repeat(5)@(negedge clk);rst=0;frame();
 repeat(10)sample(262144,125000);if(dut.armed||dut.count)$fatal(1,"trigger before crossing");
 sample(0,-1);sample(262144,125000);if(!dut.armed||dut.count!=1)$fatal(1,"trigger missing");
 for(i=1;i<512;i++)sample(i<256?262144:-262144,125000);
 if(!dut.pending||dut.show_valid)$fatal(1,"capture size / early publish");frame();bank=dut.show_bank;
 if(!dut.show_valid||dut.show_peak_l!=16||dut.show_peak_r!=7)$fatal(1,"publish");
 repeat(1024)sample(0,0);if(!dut.pending||dut.show_bank!=bank)$fatal(1,"silence fallback or bank tearing");
 n=0;render=1;
 for(y=0;y<480;y++)begin for(x=0;x<640;x++)begin de=1;@(negedge clk);end de=0;repeat(4)@(negedge clk);end
 render=0;if(n!=307200)$fatal(1,"raster");frame();
 if(dut.show_peak_l||dut.show_peak_r)$fatal(1,"silence peak");
 tag=1;repeat(5)@(negedge clk);if(dut.show_valid||dut.pending)$fatal(1,"old config persisted");
 $display("PASS tb_science_scope: 512 samples mapped to 576 pixels, trigger, silence fallback, double banks, full raster, config invalidation");$finish;
end
initial begin #10000000;$fatal(1,"watchdog");end
endmodule

`timescale 1ns/1ps
module tb_audio_visualizer;
reg clk=0;always #5 clk=~clk;
reg rst=1,en=1,hs=0,vs=1,de=0,av=0;
reg [23:0] l=0,r=0;
wire ho,vo,dout;wire [23:0] rgb;
audio_visualizer #(.AUDIO_TIMEOUT_CYCLES(1000000)) dut(clk,rst,en,hs,vs,de,24'h4080c0,av,l,r,ho,vo,dout,rgb);
integer i,x,y,f,n=0,px,py;reg oldbank,ph=0,pv=0,pd=0;
reg render=0;integer mode=0;
always @(posedge clk) begin
 #1;
 if(!rst) begin
  if(ho!==ph || vo!==pv || dout!==pd)$fatal(1,"two-stage sync alignment");
  if(!dout && rgb!=0)$fatal(1,"blanking");
  if(render && dout) begin
   px=n%640;py=n/640;n=n+1;
   if(mode==0)begin
    if(px==368 && py==376 && rgb!=24'h00ffff)$fatal(1,"left trace %h",rgb);
    if(px==368 && py==385 && rgb!=24'hff80ff)$fatal(1,"right trace %h",rgb);
    if(px==496 && py==400 && rgb!=24'h00ffff)$fatal(1,"vertical connector");
    if(px==360 && py==400 && rgb!=24'h102030)$fatal(1,"alpha panel");
    if((py>=444 || px<352) && rgb!=24'h4080c0)$fatal(1,"outside scope changed");
    $fwrite(f,"%0d %0d %0d\n",rgb[23:16],rgb[15:8],rgb[7:0]);
   end else if(rgb!=24'h4080c0)$fatal(1,"disabled bypass");
  end
 end
 ph=hs;pv=vs;pd=de;
 if(rst)begin ph=0;pv=0;pd=0;end
end
task frame;
 begin
 @(negedge clk);de=0;vs=1;repeat(4)@(negedge clk);vs=0;repeat(4)@(negedge clk);
 end
endtask
task sample(input integer a,b);
 begin @(negedge clk);av=1;l=a;r=b;@(negedge clk);av=0;end
endtask
task raster;
 begin
 n=0;render=1;
 for(y=0;y<480;y=y+1) begin
  for(x=0;x<640;x=x+1)begin de=1;hs=x[0];@(negedge clk);end
  de=0;repeat(4)@(negedge clk);
 end
 render=0;if(n!=307200)$fatal(1,"pixel count %d",n);
 end
endtask
initial begin
 repeat(4)@(negedge clk);rst=0;frame();
 if(dut.show_valid)$fatal(1,"uninitialized RAM exposed");
 if(dut.ordinate(24'h800000)!=62 || dut.ordinate(24'h7fffff)!=2 || dut.ordinate(0)!=32)$fatal(1,"signed clipping");
 for(i=0;i<256;i=i+1)sample(i<128 ? 262144:-262144,125000);
 if(!dut.pending || dut.show_valid)$fatal(1,"premature publish");
 if(dut.samples[128]!=={6'd16,6'd48,6'd25,6'd25})$fatal(1,"segment data");
 repeat(10)sample(0,0);
 if(dut.samples[0]!=={6'd16,6'd16,6'd25,6'd25})$fatal(1,"pending overwrite");
 frame();oldbank=dut.show_bank;
 if(!dut.show_valid || dut.show_peak_l!=16 || dut.show_peak_r!=7)$fatal(1,"publish/peaks");
 // Capture silence into the other bank; displayed data must remain immutable.
 for(i=0;i<256;i=i+1)sample(0,0);
 if(dut.show_bank!=oldbank || dut.samples[{oldbank,8'd128}]!=={6'd16,6'd48,6'd25,6'd25})$fatal(1,"tearing");
 f=$fopen("audio_visualizer.ppm","w");$fwrite(f,"P3\n640 480\n255\n");
 raster();$fclose(f);
 frame();
 if(dut.show_peak_l!=0 || dut.show_peak_r!=0 || dut.samples[{dut.show_bank,8'd0}]!=={6'd32,6'd32,6'd32,6'd32})$fatal(1,"silence not flat");
 en=0;mode=1;raster();
 repeat(1000001)@(negedge clk);frame();
 if(dut.show_valid || dut.pending || dut.count!=0)$fatal(1,"stale samples retained");
 for(i=0;i<256;i=i+1)sample(-8388608,8388607);
 frame();if(!dut.show_valid || dut.show_peak_l!=30 || dut.show_peak_r!=30)$fatal(1,"recovery/full scale");
 rst=1;repeat(3)@(negedge clk);if(dout || dut.show_valid || dut.pending)$fatal(1,"reset");
 $display("PASS tb_audio_visualizer: signed PCM, clipping, stereo segments, frame-atomic RAM banks, silence, timeout/recovery, full raster and sync, bypass/reset");$finish;
end
initial begin #30000000;$fatal(1,"watchdog");end
endmodule

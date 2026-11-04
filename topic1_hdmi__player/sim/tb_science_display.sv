`timescale 1ns/1ps
module tb_science_display;
reg clk=0;always #5 clk=~clk;
reg rst=1,sv=0,hs=0,vs=1,de=0,menu=0;reg [23:0] pixel=0;
reg [1:0] page=0,choice=0,vol=2;reg [3:0] bri=4;reg [2:0] con=2;
wire av,h1,v1,d1,ho,vo,dout,sr;wire [23:0] l,r,bg,rgb1,rgb;wire [1:0] ap,ac;
science_audio audio_(clk,rst,sv,1'b1,page,choice,vol,av,l,r,bg,ap,ac,sr);
science_scope scope(clk,rst,1'b1,hs,vs,de,pixel,av&&sr,page==3?bg:l,r,page!=3,{1'b1,page,choice,vol},h1,v1,d1,rgb1);
science_osd dut(clk,rst,h1,v1,d1,rgb1,page,choice,vol,2'd1,menu,1'b0,1'b1,3'd1,con,bri,1'b0,ho,vo,dout,rgb);
reg [23:0] background[0:307199];
integer x,y,n=0,f,i,k,zh_hits=0;reg render=0;
reg [3:0] hist_de=0,hist_vs=0,hist_hs=0;
always @(posedge clk)begin
 #1;
 if(!rst)begin
  if(dout!==hist_de[2]||vo!==hist_vs[2]||ho!==hist_hs[2])$fatal(1,"four-stage pixel/sync alignment");
  if(!dout&&rgb!=0)$fatal(1,"blanking");
  if(render&&dout)begin
   if(^rgb===1'bx)$fatal(1,"unknown pixel");
   if(n/640>=448&&n/640<464&&rgb==24'hffffff)zh_hits++;
   $fwrite(f,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);n++;
  end
 end
 hist_de={hist_de[2:0],de};hist_vs={hist_vs[2:0],vs};hist_hs={hist_hs[2:0],hs};
 if(rst)begin hist_de=0;hist_vs=0;hist_hs=0;end
end
task sample;begin sv=1;@(negedge clk);sv=0;repeat(11)@(negedge clk);end endtask
task frame;begin de=0;vs=1;repeat(6)@(negedge clk);vs=0;repeat(6)@(negedge clk);end endtask
initial begin
 repeat(6)@(negedge clk);rst=0;
 for(k=0;k<5;k++)begin
  page=k==4?2:k;choice=k==2?1:k==3?2:0;menu=k==4;vol=k==4?0:2;bri=k==4?0:4;con=k==4?0:2;
  $readmemh($sformatf("science_background%0d.hex",page),background);
  frame();repeat(1800)sample();frame();
  if(!scope.show_valid)$fatal(1,"no captured audio");
  f=$fopen($sformatf("science_page%0d.ppm",k),"wb");$fwrite(f,"P6\n640 480\n255\n");
  n=0;zh_hits=0;render=1;
  for(y=0;y<480;y++)begin
   for(x=0;x<640;x++)begin de=1;hs=x[0];pixel=background[y*640+x];@(negedge clk);end
   de=0;repeat(8)@(negedge clk);
  end
  repeat(8)@(negedge clk);render=0;$fclose(f);
  if(n!=307200||zh_hits<100)$fatal(1,"raster/font missing n=%d ink=%d",n,zh_hits);
 end
 $display("PASS tb_science_display: actual four BMPs, audio/scope/OSD pipeline, Chinese glyphs, menu, no unknown pixels, 640x480 raster and sync");$finish;
end
initial begin #30000000;$fatal(1,"watchdog");end
endmodule

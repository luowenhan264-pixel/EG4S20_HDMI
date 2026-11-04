// Real post-volume PCM monitor, in the HDMI pixel clock domain.
// Capture 256 stereo samples, freeze until VS falling edge, then swap banks.
// RAM holds vertical segments between successive samples. Never write the bank
// being scanned out. Display gain is fixed (1 pixel / 16384 PCM units).
module audio_visualizer #(parameter integer AUDIO_TIMEOUT_CYCLES=2500000)(
 input clk,rst,enable,hs,vs,de,input [23:0] rgb,
 input audio_valid,input [23:0] audio_left,audio_right,
 output reg hs_out,vs_out,de_out,output reg [23:0] rgb_out
);
reg de_d,vs_d;
reg [9:0] x,y;
wire [9:0] xc=de ? (de_d ? x+10'd1 : 10'd0) : 10'd0;
wire frame_edge=vs_d && !vs;
localparam TW=$clog2(AUDIO_TIMEOUT_CYCLES+1);
reg [TW-1:0] age;
wire stale=age>=AUDIO_TIMEOUT_CYCLES;
reg write_bank,show_bank,pending,show_valid;
reg [7:0] count;
reg [5:0] prev_l,prev_r,peak_l,peak_r,show_peak_l,show_peak_r;
function [5:0] ordinate;
 input [23:0] pcm;
 reg [23:0] mag;reg [5:0] amp;
 begin
  mag=pcm[23] ? (~pcm+24'd1) : pcm;
  amp=mag>=24'd491520 ? 6'd30 : {1'b0,mag[18:14]};
  ordinate=pcm[23] ? 6'd32+amp : 6'd32-amp;
 end
endfunction
wire [5:0] yl=ordinate(audio_left),yr=ordinate(audio_right);
wire [5:0] pl=count==0 ? yl:prev_l,pr=count==0 ? yr:prev_r;
wire [5:0] al=yl>=32 ? yl-6'd32 : 6'd32-yl;
wire [5:0] ar=yr>=32 ? yr-6'd32 : 6'd32-yr;
reg [23:0] samples [0:511];
reg [23:0] segment;
wire [9:0] plot_x=xc-10'd368;
wire capture=audio_valid && !pending && !rst;
always @(posedge clk) begin
 if(capture) samples[{write_bank,count}] <= {
  (yl<pl ? yl:pl),(yl>pl ? yl:pl),(yr<pr ? yr:pr),(yr>pr ? yr:pr)};
 segment<=samples[{show_bank,plot_x[7:0]}];
end
always @(posedge clk or posedge rst) begin
 if(rst) begin
  de_d<=0;vs_d<=0;x<=0;y<=0;age<=AUDIO_TIMEOUT_CYCLES;
  write_bank<=0;show_bank<=1;pending<=0;show_valid<=0;count<=0;
  prev_l<=32;prev_r<=32;peak_l<=0;peak_r<=0;show_peak_l<=0;show_peak_r<=0;
 end else begin
  de_d<=de;vs_d<=vs;x<=xc;
  if(frame_edge)y<=0;else if(de_d && !de)y<=y+1'b1;
  if(audio_valid)age<=0;else if(!stale)age<=age+1'b1;
  if(capture) begin
   prev_l<=yl;prev_r<=yr;
   if(al>peak_l)peak_l<=al;if(ar>peak_r)peak_r<=ar;
   if(count==255)pending<=1;else count<=count+1'b1;
  end
  if(frame_edge && stale) begin
   show_valid<=0;pending<=0;count<=0;peak_l<=0;peak_r<=0;
   show_peak_l<=0;show_peak_r<=0;
  end else if(frame_edge && pending) begin
   show_bank<=write_bank;write_bank<=~write_bank;show_valid<=1;
   show_peak_l<=peak_l;show_peak_r<=peak_r;
   pending<=0;count<=0;peak_l<=0;peak_r<=0;
  end
 end
end
// Pipeline RAM and pixel coordinates together, then composite in stage two.
reg h1,v1,d1,en1,valid1;
reg [23:0] rgb1;
reg [9:0] x1,y1;
wire panel=x1>=352 && x1<632 && y1>=336 && y1<436;
wire plot=x1>=368 && x1<624 && y1>=360 && y1<424;
wire [9:0] py=y1-10'd360;
wire left_ink=plot && valid1 && py>=segment[23:18] && py<=segment[17:12];
wire right_ink=plot && valid1 && py>=segment[11:6] && py<=segment[5:0];
wire grid=plot && (y1==392 || x1==368 || x1==432 || x1==496 || x1==560 || x1==623);
wire border=panel && (x1==352 || x1==631 || y1==336 || y1==435);
wire lbar=y1>=428 && y1<432 && x1>=368 && x1<368+{show_peak_l,2'b0};
wire rbar=y1>=428 && y1<432 && x1>=496 && x1<496+{show_peak_r,2'b0};
// Tiny fixed AUDIO / L / R legend, large enough for the 640x480 output.
function [34:0] glyph;
 input [2:0] c;
 begin case(c)
 0:glyph={5'b01110,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
 1:glyph={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
 2:glyph={5'b11110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b11110};
 3:glyph={5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b11111};
 4:glyph={5'b01110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
 5:glyph={5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b11111};
 6:glyph={5'b11110,5'b10001,5'b10001,5'b11110,5'b10100,5'b10010,5'b10001};
 default:glyph=0;endcase end
endfunction
wire [9:0] tx=x1-10'd368,ty=y1-10'd342;
wire [2:0] cell_id=tx[6:4],col=tx[3:1],row=ty[3:1];
wire [34:0] bitmap=glyph(cell_id);
wire label_ink=x1>=368 && x1<480 && y1>=342 && y1<356 && col<5 && bitmap[34-row*5-col];
wire [23:0] dim={2'b0,rgb1[23:18],2'b0,rgb1[15:10],2'b0,rgb1[7:2]};
reg [23:0] composed;
always @* begin
 composed=rgb1;
 if(en1 && panel) begin
  composed=dim;
  if(grid)composed=24'h405060;
  if(border)composed=24'h708090;
  if(label_ink)composed=cell_id==5 ? 24'h00ffff : cell_id==6 ? 24'hff80ff : 24'he0e0e0;
  if(lbar || left_ink)composed=24'h00ffff;
  if(rbar || right_ink)composed=24'hff80ff;
  if(left_ink && right_ink)composed=24'hffffff;
 end
end
always @(posedge clk or posedge rst) begin
 if(rst) begin
  h1<=0;v1<=0;d1<=0;en1<=0;valid1<=0;rgb1<=0;x1<=0;y1<=0;
  hs_out<=0;vs_out<=0;de_out<=0;rgb_out<=0;
 end else begin
  h1<=hs;v1<=vs;d1<=de;en1<=enable;valid1<=show_valid;
  rgb1<=rgb;x1<=xc;y1<=y;
  hs_out<=h1;vs_out<=v1;de_out<=d1;rgb_out<=d1 ? composed : 24'd0;
 end
end
endmodule

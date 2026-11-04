// Real post-volume PCM monitor, in the HDMI pixel clock domain.
// Capture 512 samples (BGM component and final OUT), freeze until VS falling edge, then swap banks.
// 576 x 64 plot, fixed ~10.7 ms window; rising zero-cross trigger with silent fallback.
// RAM holds vertical segments between successive samples. Never write the bank
// being scanned out. Display gain is fixed (1 pixel / 16384 PCM units).
module science_scope #(parameter integer AUDIO_TIMEOUT_CYCLES=2500000)(
 input clk,rst,enable,hs,vs,de,input [23:0] rgb,
 input audio_valid,input [23:0] audio_left,audio_right,
 input trigger_enable,input [6:0] config_tag,
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
reg [8:0] count;
reg armed,previous_negative;
reg [8:0] trigger_wait;
reg [6:0] last_config;
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
reg [23:0] samples [0:1023];
reg [23:0] segment;
wire [9:0] plot_x=xc-10'd32;
wire cross_up=previous_negative && !audio_right[23];
wire start_capture=!trigger_enable || cross_up || trigger_wait==511;
wire capture=audio_valid && !pending && !rst && config_tag==last_config && (armed || start_capture);
wire [12:0] scaled_x={plot_x,3'b0};
wire [12:0] read_index=scaled_x/13'd9;
always @(posedge clk) begin
 if(capture) samples[{write_bank,count}] <= {
  (yl<pl ? yl:pl),(yl>pl ? yl:pl),(yr<pr ? yr:pr),(yr>pr ? yr:pr)};
 segment<=samples[{show_bank,read_index[8:0]}];
end
always @(posedge clk or posedge rst) begin
 if(rst) begin
  de_d<=0;vs_d<=0;x<=0;y<=0;age<=AUDIO_TIMEOUT_CYCLES;
  write_bank<=0;show_bank<=1;pending<=0;show_valid<=0;count<=0;armed<=0;previous_negative<=0;trigger_wait<=0;last_config<=0;
  prev_l<=32;prev_r<=32;peak_l<=0;peak_r<=0;show_peak_l<=0;show_peak_r<=0;
 end else begin
  de_d<=de;vs_d<=vs;x<=xc;
  if(frame_edge)y<=0;else if(de_d && !de)y<=y+1'b1;
  if(audio_valid)age<=0;else if(!stale)age<=age+1'b1;
  if(audio_valid)begin
   previous_negative<=audio_right[23];
   if(!pending&&!armed&&trigger_wait!=511)trigger_wait<=trigger_wait+1'b1;
  end
  if(capture) begin
   armed<=1;
   prev_l<=yl;prev_r<=yr;
   if(al>peak_l)peak_l<=al;if(ar>peak_r)peak_r<=ar;
   if(count==511)pending<=1;else count<=count+1'b1;
  end
  if(frame_edge && stale) begin
   show_valid<=0;pending<=0;count<=0;armed<=0;trigger_wait<=0;peak_l<=0;peak_r<=0;
   show_peak_l<=0;show_peak_r<=0;
  end else if(frame_edge && pending) begin
   show_bank<=write_bank;write_bank<=~write_bank;show_valid<=1;
   show_peak_l<=peak_l;show_peak_r<=peak_r;
   pending<=0;count<=0;armed<=0;trigger_wait<=0;peak_l<=0;peak_r<=0;
  end
  if(config_tag!=last_config)begin
   last_config<=config_tag;pending<=0;count<=0;armed<=0;trigger_wait<=0;show_valid<=0;peak_l<=0;peak_r<=0;show_peak_l<=0;show_peak_r<=0;
  end
 end
end
// Pipeline RAM and pixel coordinates together, then composite in stage two.
reg h1,v1,d1,en1,valid1;
reg [23:0] rgb1;
reg [9:0] x1,y1;
wire panel=x1>=30 && x1<610 && y1>=342 && y1<416;
wire plot=x1>=32 && x1<608 && y1>=344 && y1<408;
wire [9:0] py=y1-10'd344;
wire left_ink=plot && valid1 && py>=segment[23:18] && py<=segment[17:12];
wire right_ink=plot && valid1 && py>=segment[11:6] && py<=segment[5:0];
wire grid=plot && (y1==376 || x1==32 || x1==176 || x1==320 || x1==464 || x1==607);
wire border=panel && (x1==30 || x1==609 || y1==342 || y1==415);
wire lbar=y1>=410 && y1<414 && x1>=32 && x1<32+{show_peak_l,3'b0};
wire rbar=y1>=410 && y1<414 && x1>=352 && x1<352+{show_peak_r,3'b0};
wire [23:0] dim={2'b0,rgb1[23:18],2'b0,rgb1[15:10],2'b0,rgb1[7:2]};
reg [23:0] composed;
always @* begin
 composed=rgb1;
 if(en1 && panel) begin
  composed=dim;
  if(grid)composed=24'h405060;
  if(border)composed=24'h708090;
  if(lbar || left_ink)composed=24'h00ffff;
  if(rbar || right_ink)composed=24'hffffff;
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

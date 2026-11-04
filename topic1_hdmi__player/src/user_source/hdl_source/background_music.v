// Original looping two-voice sine melody, mixed with post-volume cue PCM.
// Input sample cadence is inherited from I2S_receiver, not a separate timer.
// Five registered stages preserve valid/L/R coherence. No TF/SDRAM access.
module background_music #(parameter integer BEAT_SAMPLES=36021)(
 input clk,rst,enable,input [1:0] volume,
 input sample_valid,input [23:0] cue_left,cue_right,
 output reg audio_valid,output reg [23:0] audio_left,audio_right
);
// BEGIN GENERATED BGM TABLES
// Original 32-step C-major loop, about 80 BPM / 24 seconds.
function [31:0] melody_inc; input [4:0] step; begin case(step)
5'd0:melody_inc=32'd23396375;
5'd1:melody_inc=32'd29477586;
5'd2:melody_inc=32'd35054954;
5'd3:melody_inc=32'd29477586;
5'd4:melody_inc=32'd26261543;
5'd5:melody_inc=32'd31230414;
5'd6:melody_inc=32'd39347856;
5'd7:melody_inc=32'd31230414;
5'd8:melody_inc=32'd29477586;
5'd9:melody_inc=32'd35054954;
5'd10:melody_inc=32'd46792750;
5'd11:melody_inc=32'd35054954;
5'd12:melody_inc=32'd26261543;
5'd13:melody_inc=32'd31230414;
5'd14:melody_inc=32'd35054954;
5'd15:melody_inc=32'd0;
5'd16:melody_inc=32'd23396375;
5'd17:melody_inc=32'd29477586;
5'd18:melody_inc=32'd39347856;
5'd19:melody_inc=32'd35054954;
5'd20:melody_inc=32'd31230414;
5'd21:melody_inc=32'd29477586;
5'd22:melody_inc=32'd26261543;
5'd23:melody_inc=32'd0;
5'd24:melody_inc=32'd29477586;
5'd25:melody_inc=32'd35054954;
5'd26:melody_inc=32'd29477586;
5'd27:melody_inc=32'd26261543;
5'd28:melody_inc=32'd23396375;
5'd29:melody_inc=32'd26261543;
5'd30:melody_inc=32'd23396375;
5'd31:melody_inc=32'd0;
endcase end endfunction
function [31:0] bass_inc; input [1:0] chord; begin case(chord)
2'd0:bass_inc=32'd11698188;
2'd1:bass_inc=32'd9836964;
2'd2:bass_inc=32'd7807604;
2'd3:bass_inc=32'd8763739;
endcase end endfunction
function signed [15:0] sine; input [7:0] phase; reg [5:0] addr; reg [14:0] mag; begin
addr=phase[6] ? ~phase[5:0] : phase[5:0];
case(addr)
6'd0:mag=15'd0;
6'd1:mag=15'd817;
6'd2:mag=15'd1633;
6'd3:mag=15'd2449;
6'd4:mag=15'd3263;
6'd5:mag=15'd4074;
6'd6:mag=15'd4884;
6'd7:mag=15'd5690;
6'd8:mag=15'd6493;
6'd9:mag=15'd7291;
6'd10:mag=15'd8085;
6'd11:mag=15'd8875;
6'd12:mag=15'd9658;
6'd13:mag=15'd10436;
6'd14:mag=15'd11207;
6'd15:mag=15'd11971;
6'd16:mag=15'd12728;
6'd17:mag=15'd13477;
6'd18:mag=15'd14217;
6'd19:mag=15'd14949;
6'd20:mag=15'd15671;
6'd21:mag=15'd16384;
6'd22:mag=15'd17086;
6'd23:mag=15'd17778;
6'd24:mag=15'd18458;
6'd25:mag=15'd19128;
6'd26:mag=15'd19785;
6'd27:mag=15'd20430;
6'd28:mag=15'd21062;
6'd29:mag=15'd21681;
6'd30:mag=15'd22287;
6'd31:mag=15'd22879;
6'd32:mag=15'd23457;
6'd33:mag=15'd24020;
6'd34:mag=15'd24568;
6'd35:mag=15'd25101;
6'd36:mag=15'd25618;
6'd37:mag=15'd26120;
6'd38:mag=15'd26605;
6'd39:mag=15'd27073;
6'd40:mag=15'd27525;
6'd41:mag=15'd27960;
6'd42:mag=15'd28377;
6'd43:mag=15'd28777;
6'd44:mag=15'd29158;
6'd45:mag=15'd29522;
6'd46:mag=15'd29867;
6'd47:mag=15'd30194;
6'd48:mag=15'd30502;
6'd49:mag=15'd30791;
6'd50:mag=15'd31061;
6'd51:mag=15'd31311;
6'd52:mag=15'd31542;
6'd53:mag=15'd31754;
6'd54:mag=15'd31945;
6'd55:mag=15'd32117;
6'd56:mag=15'd32269;
6'd57:mag=15'd32401;
6'd58:mag=15'd32513;
6'd59:mag=15'd32604;
6'd60:mag=15'd32675;
6'd61:mag=15'd32726;
6'd62:mag=15'd32757;
6'd63:mag=15'd32767;
endcase
sine=phase[7] ? -$signed({1'b0,mag}) : $signed({1'b0,mag});
end endfunction
// END GENERATED BGM TABLES
localparam BW=$clog2(BEAT_SAMPLES+1);
localparam RAMP=BEAT_SAMPLES<8192 ? BEAT_SAMPLES/4 : 2048;
reg [BW-1:0] beat_count;
reg [4:0] step;
reg [31:0] phase_m,phase_b;
reg [10:0] envelope;
reg [3:0] valid_pipe;
reg signed [15:0] m0,b0;
reg signed [11:0] env0;
reg signed [27:0] mp1,bp1;
reg signed [24:0] music2,music3;
reg signed [24:0] sum_l,sum_r;
reg [23:0] l0,l1,l2,l3,r0,r1,r2,r3;
reg [1:0] vol0,vol1,vol2,vol3;
wire [31:0] note_inc=melody_inc(step);
function [23:0] saturate;
 input signed [24:0] value;
 begin
 if(value>25'sd8388607)saturate=24'h7fffff;
 else if(value< -25'sd8388608)saturate=24'h800000;
 else saturate=value[23:0];
 end
endfunction
always @* begin
 sum_l=$signed({l3[23],l3})+music3;
 sum_r=$signed({r3[23],r3})+music3;
end
always @(posedge clk or posedge rst) begin
 if(rst) begin
  beat_count<=0;step<=0;phase_m<=0;phase_b<=0;envelope<=0;
  valid_pipe<=0;m0<=0;b0<=0;env0<=0;mp1<=0;bp1<=0;music2<=0;music3<=0;
  l0<=0;l1<=0;l2<=0;l3<=0;r0<=0;r1<=0;r2<=0;r3<=0;
  vol0<=0;vol1<=0;vol2<=0;vol3<=0;
  audio_valid<=0;audio_left<=0;audio_right<=0;
 end else begin
  valid_pipe<={valid_pipe[2:0],sample_valid};audio_valid<=valid_pipe[3];
  if(sample_valid)begin
   l0<=cue_left;r0<=cue_right;vol0<=volume;
   m0<=enable && note_inc!=0 ? sine(phase_m[31:24]) : 16'sd0;
   b0<=enable ? sine(phase_b[31:24]) : 16'sd0;
   env0<=$signed({1'b0,envelope});
   if(!enable)begin beat_count<=0;step<=0;phase_m<=0;phase_b<=0;envelope<=0;end
   else if(beat_count==BEAT_SAMPLES-1)begin
    beat_count<=0;step<=step+1'b1;phase_m<=0;phase_b<=0;envelope<=0;
   end else begin
    beat_count<=beat_count+1'b1;
    phase_m<=phase_m+note_inc;phase_b<=phase_b+bass_inc(step[4:3]);
    if(beat_count>=BEAT_SAMPLES-RAMP)begin if(envelope!=0)envelope<=envelope-1'b1;end
    else if(envelope<RAMP-1)envelope<=envelope+1'b1;
   end
  end
  if(valid_pipe[0])begin
   mp1<=m0*env0;bp1<=b0*env0;
   l1<=l0;r1<=r0;vol1<=vol0;
  end
  if(valid_pipe[1])begin
   music2<=(mp1>>>9)+(bp1>>>11);
   l2<=l1;r2<=r1;vol2<=vol1;
  end
  if(valid_pipe[2])begin
   music3<=vol2==0 ? 25'sd0 : vol2==1 ? music2>>>2 : vol2==2 ? music2>>>1 : music2;
   l3<=l2;r3<=r2;vol3<=vol2;
  end
  if(valid_pipe[3])begin
   audio_left<=vol3==0 ? 24'd0 : saturate(sum_l);
   audio_right<=vol3==0 ? 24'd0 : saturate(sum_r);
  end else begin audio_left<=0;audio_right<=0;end
 end
end
endmodule

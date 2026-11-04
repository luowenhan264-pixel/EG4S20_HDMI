// All science audio is generated in the pixel domain, paced by real HDMI Fs.
// page 0 waveform, 1 pitch, 2 amplitude, 3 BGM/cue/mix/stop.
module science_audio #(
 parameter integer CUE_PERIOD=96056,CUE_LENGTH=9606
)(input clk,rst,sample_valid,enable,input [1:0] page,choice,volume,
 output reg audio_valid,output reg [23:0] audio_left,audio_right,
 output reg [23:0] scope_background,output reg [1:0] active_page,active_choice,
 output scope_ready);
wire music_valid;
wire [23:0] music_left,music_right;
background_music music(.clk(clk),.rst(rst),.enable(active_page==3),.volume(2'd3),
 .sample_valid(sample_valid),.cue_left(24'd0),.cue_right(24'd0),
 .audio_valid(music_valid),.audio_left(music_left),.audio_right(music_right));
reg active_enable;
reg [1:0] active_volume;
reg [7:0] envelope;
reg [31:0] phase,cue_phase;
reg [16:0] cue_count;
wire changed={enable,page,choice,volume}!={active_enable,active_page,active_choice,active_volume};
// BEGIN SCIENCE SINE
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
// END SCIENCE SINE
wire [31:0] increment=active_page==1 ? (active_choice==0 ? 32'd19673928 : active_choice==2 ? 32'd78695712 : 32'd39347856) : 32'd39347856;
wire [7:0] ph=phase[31:24];
wire [5:0] ta=ph[6] ? ~ph[5:0] : ph[5:0];
wire signed [15:0] triangle=ph[7] ? -$signed({1'b0,ta,9'b0}):$signed({1'b0,ta,9'b0});
wire signed [15:0] waveform=active_page==0 && active_choice==1 ? triangle :
 active_page==0 && active_choice==2 ? (ph[7] ? -16'sd32767:16'sd32767):sine(ph);
wire silent=(active_page==0 || active_page==3) && active_choice==3 || active_page==2 && active_choice==3;
// Exclude configuration fade ramps from a newly captured teaching waveform.
assign scope_ready=!changed && ((active_enable&&!silent&&envelope==255) ||
 ((!active_enable||silent)&&envelope==0));
wire [7:0] cue_env=cue_count>=CUE_LENGTH ? 8'd0 : cue_count<255 ? cue_count[7:0] :
 cue_count>=CUE_LENGTH-255 ? CUE_LENGTH-1-cue_count : 8'd255;
reg signed [23:0] source0,bg0;
reg signed [8:0] env0;
reg [1:0] vol0,vol1;
reg signed [32:0] product1,bg_product1;
reg [1:0] valid_pipe;
wire signed [23:0] cue_sample=($signed(sine(cue_phase[31:24]))*$signed({1'b0,cue_env}))>>>5;
wire signed [23:0] pure_sample=$signed(waveform)<<<3; // fixed peak about 262k / 8.39M
wire signed [23:0] amp_sample=active_page!=2 ? pure_sample : active_choice==0 ? pure_sample>>>2 : active_choice==1 ? pure_sample>>>1:pure_sample;
wire signed [23:0] selected_music=(active_choice==0 || active_choice==2) ? $signed(music_left):24'sd0;
wire signed [23:0] selected_cue=(active_choice==1 || active_choice==2) ? cue_sample:24'sd0;
wire signed [32:0] scaled=product1>>>8,bg_scaled=bg_product1>>>8;
always @(posedge clk or posedge rst)begin
 if(rst)begin
  active_enable<=0;active_page<=0;active_choice<=0;active_volume<=2;envelope<=0;
  phase<=0;cue_phase<=0;cue_count<=0;source0<=0;bg0<=0;env0<=0;vol0<=0;vol1<=0;
  product1<=0;bg_product1<=0;valid_pipe<=0;audio_valid<=0;audio_left<=0;audio_right<=0;scope_background<=0;
 end else begin
  valid_pipe<={valid_pipe[0],music_valid};audio_valid<=valid_pipe[1];
  if(music_valid)begin
   if(changed)begin
    if(envelope!=0)envelope<=envelope-1'b1;
    else begin
     active_enable<=enable;active_page<=page;active_choice<=choice;active_volume<=volume;
     phase<=0;cue_phase<=0;cue_count<=0;
    end
   end else begin
    if(active_enable&&!silent&&envelope!=255)envelope<=envelope+1'b1;
    else if((!active_enable||silent)&&envelope!=0)envelope<=envelope-1'b1;
   end
   // Phase runs during fade; only reset when reconfiguration reaches silence.
   if(!(changed&&envelope==0))begin
    phase<=phase+increment;cue_phase<=cue_phase+32'd78695712;
    cue_count<=cue_count==CUE_PERIOD-1 ? 0:cue_count+1'b1;
   end
   source0<=active_page==3 ? selected_music+selected_cue : amp_sample;
   bg0<=active_page==3 ? selected_music:24'sd0;
   env0<=$signed({1'b0,envelope});vol0<=active_volume;
  end
  if(valid_pipe[0])begin
   product1<=source0*env0;bg_product1<=bg0*env0;vol1<=vol0;
  end
  if(valid_pipe[1])begin
   audio_left<=vol1==0 ? 24'd0 : vol1==1 ? scaled>>>2 : vol1==2 ? scaled>>>1:scaled;
   audio_right<=vol1==0 ? 24'd0 : vol1==1 ? scaled>>>2 : vol1==2 ? scaled>>>1:scaled;
   scope_background<=vol1==0 ? 24'd0 : vol1==1 ? bg_scaled>>>2 : vol1==2 ? bg_scaled>>>1:bg_scaled;
  end else begin audio_left<=0;audio_right<=0;scope_background<=0;end
 end
end
endmodule

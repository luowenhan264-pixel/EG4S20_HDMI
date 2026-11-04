`timescale 1ns/1ps
// Short synthetic video frames keep this integration regression fast. Real
// control/reader/fade/menu/CDC/audio logic; sector+SDRAM completion are models.
module tb_extensions_flow;
reg sclk=0,vclk=0,mclk=0,rst=1,n=1,a=1,finish=0,write_ack=0;
always #5 sclk=~sclk;always #20 vclk=~vclk;always #40.667 mclk=~mclk;
wire np,ap,menu,two_note,displayed,auto_play,req,we,request,ack,valid,busy;
wire [2:0] field;
wire [1:0] period,volume,image_id,wb,db,bank,shown_image;
wire [31:0] period_ms,data;wire [3:0] status;wire [5:0] gain;
localparam [16:0] RESET_CFG={1'b1,3'd2,4'd4,1'b0,3'd0,2'd0,2'd3,1'b1};
wire [3:0] brightness;wire [2:0] contrast;wire subtitle;
wire [16:0] cfg_cdc;reg [16:0] cfg_frame=RESET_CFG;wire [1:0] audio_volume;
wire event_toggle,event_mode;wire [1:0] event_image;
wire bclk,lrck,dout,pcm_valid;wire [23:0] pcm_l,pcm_r;
reg [5:0] cycle=0;wire frame_start=cycle==0;
wire de=cycle>=8 && cycle<40;
wire [23:0] raw=valid ? (bank==0 ? 24'h804020 : 24'h2080c0) : 24'd0;
wire fh,fv,fd;wire [23:0] faded;
integer writes=0,presentations=0,cues=0,loads=0,pcm_frames=0;
reg previous_valid=0,previous_event=0;reg [1:0] previous_bank=0;
player_controls #(.CLK_FREQ_HZ(1000),.DEBOUNCE_MS(2),.LONG_MS(16))
 controls(sclk,rst,n,a,np,ap,menu,field,period,volume,two_note,period_ms,brightness,contrast,subtitle);
sd_card_bmp #(.CLK_FREQ_HZ(1000),.SCAN_MAX_SECTOR(6),.IO_TIMEOUT_MS(1500),.EXTERNAL_CONTROL(1)) player(
 .clk(sclk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.state_code(status),
 .bmp_width(16'd4),.bmp_height(16'd2),.display_valid(displayed),.img_idx(image_id),.auto_play_en(auto_play),
 .write_finish_toggle(finish),.write_buf_idx(wb),.disp_buf_idx(db),
 .display_req_toggle(request),.display_ack_toggle(ack),.write_req(req),.write_req_ack(write_ack),
 .write_en(we),.write_data(data),.SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1),
 .control_next(np),.control_auto(ap),.control_pause(menu),.control_period_ms(period_ms));
player_frame_commit #(.FRAMES_PER_STEP(3))
 commit(vclk,rst,frame_start,request,db,image_id,ack,bank,shown_image,valid,gain,busy);
player_config_cdc #(.WIDTH(17),.RESET_VALUE(RESET_CFG)) settings_to_video(
 sclk,rst,{subtitle,contrast,brightness,menu,field,period,volume,two_note},vclk,rst,cfg_cdc);
always @(posedge vclk) if(rst)begin cycle<=0;cfg_frame<=RESET_CFG;end
 else begin cycle<=cycle+1'b1;if(frame_start)cfg_frame<=cfg_cdc;end
player_config_cdc #(.WIDTH(2),.RESET_VALUE(2'd3)) settings_to_audio(
 vclk,rst,cfg_frame[2:1],mclk,rst,audio_volume);
player_picture_event events(vclk,rst,valid,bank,shown_image,event_toggle,event_image,cfg_frame[0],event_mode);
hdmi_audio_link_i2s #(.CUE_SAMPLES(8)) cue(mclk,rst,event_toggle,event_image,bclk,lrck,dout,audio_volume,event_mode);
I2S_receiver receiver(vclk,rst,bclk,lrck,dout,pcm_valid,pcm_l,pcm_r);
video_fade_rgb pixels(vclk,rst,1'b0,!frame_start,de,raw,gain,fh,fv,fd,faded);
always @(posedge sclk)begin
 if(rst)begin writes<=0;write_ack<=0;finish<=0;loads<=0;end
 else begin
  write_ack<=req;
  if(we)begin
   writes<=writes+1;if(writes%8==7)finish<=~finish;
   if(valid && wb==bank)$fatal(1,"displayed bank reused during fade");
  end
  if(player.load_start)loads<=loads+1;
 end
end
reg [5:0] old_gain;reg [1:0] old_bank;reg old_ack,was_frame,old_de;
reg [23:0] expected_rgb;reg [16:0] old_cfg;
integer fade_step_frames=0;reg measure_fade_in=0;
always @(posedge vclk)begin
 old_gain=gain;old_bank=bank;old_ack=ack;was_frame=frame_start;old_de=de;old_cfg=cfg_frame;
 expected_rgb=de ? {8'((32'(raw[23:16])*gain)>>5),8'((32'(raw[15:8])*gain)>>5),8'((32'(raw[7:0])*gain)>>5)} : 24'd0;
 #1;
 if(rst)begin previous_valid=0;previous_bank=0;previous_event=0;presentations=0;cues=0;pcm_frames=0;
 fade_step_frames=0;measure_fade_in=0;end
 else begin
  if((gain!=old_gain || bank!=old_bank || cfg_frame!=old_cfg) && !was_frame)$fatal(1,"mid-frame change");
  if(bank!=old_bank && gain!=0)$fatal(1,"nonblack swap");
  if(ack!=old_ack && gain!=32)$fatal(1,"early fade ACK");
  if(faded!==expected_rgb || fd!==old_de)$fatal(1,"fade pixel/timing mismatch expected=%h got=%h",expected_rgb,faded);
  if(valid && (!previous_valid || bank!=previous_bank))begin
   presentations=presentations+1;fade_step_frames=0;measure_fade_in=1;
  end else if(was_frame && measure_fade_in)begin
   fade_step_frames=fade_step_frames+1;
   if(gain!=old_gain)begin
    if(fade_step_frames!=3 || gain!=old_gain+1)$fatal(1,"non-power-of-two fade step duration");
    fade_step_frames=0;if(gain==32)measure_fade_in=0;
   end
  end
  if(event_toggle!=previous_event)begin
   cues=cues+1;if(event_image!=shown_image || event_mode!=cfg_frame[0])$fatal(1,"wrong cue payload");
  end
  previous_valid=valid;previous_bank=bank;previous_event=event_toggle;
  if(pcm_valid)begin pcm_frames=pcm_frames+1;
   if(pcm_frames>5 && (pcm_l!==pcm_r || $isunknown(pcm_l)))$fatal(1,"decoded PCM mismatch");
  end
 end
end
task tap(input integer key);
 begin @(negedge sclk);if(key==0)n=0;else a=0;
 repeat(7)@(negedge sclk);n=1;a=1;repeat(8)@(negedge sclk);end
endtask
task long_auto;
 begin @(negedge sclk);a=0;repeat(35)@(negedge sclk);a=1;repeat(8)@(negedge sclk);end
endtask
integer count_before;
initial begin
 repeat(8)@(negedge sclk);rst=0;
 wait(valid && gain>0 && gain<10);long_auto();tap(0);tap(0);tap(1);
 if(!menu || two_note)$fatal(1,"edit mode during first fade");
 wait(displayed);repeat(100)@(negedge sclk);
 if(presentations!=1 || cues!=1)$fatal(1,"settings created extra cue/commit");
 long_auto();tap(0);wait(busy && gain<20 && gain>0);
 // Queue one further manual request while old picture is still fading out.
 tap(0);long_auto();tap(0);tap(1); // VOL -> mute during animation
 if(!menu || volume!=0)$fatal(1,"menu mute during fade");
 wait(presentations==3);wait(!busy && player.state==5);repeat(100)@(negedge sclk);
 if(cues!=3 || loads!=3)$fatal(1,"queued request duplicated/lost");
 long_auto();player.sd_card_top_m0.stall=1;tap(0);wait(status==4'he);
 count_before=cues;repeat(100)@(negedge sclk);
 if(cues!=count_before || !valid)$fatal(1,"I/O failure lost image or made sound");
 long_auto();tap(0);repeat(100)@(negedge sclk);
 if(status!=4'he)$fatal(1,"menu selection accidentally retried I/O");
 long_auto();player.sd_card_top_m0.stall=0;tap(0);wait(busy && gain<20 && gain>0);
 // Reset while a recovery transition is in progress.
 @(negedge sclk);rst=1;repeat(12)@(negedge sclk);
 if(valid || gain || menu || event_toggle)$fatal(1,"reset failed to clear extension state");
 rst=0;wait(displayed);repeat(100)@(negedge sclk);
 if(presentations!=1 || cues!=1 || volume!=3 || !two_note)$fatal(1,"recovery defaults or ghost cue");
 long_auto();tap(0);tap(0);tap(0);tap(1);
 repeat(200)@(negedge sclk);
 if(cfg_frame[12:9]!=5 || cfg_frame[7:5]!=3 || !cfg_frame[8])$fatal(1,"brightness mailbox/menu field");
 tap(0);tap(1);repeat(200)@(negedge sclk);
 if(cfg_frame[15:13]!=3 || cfg_frame[7:5]!=4)$fatal(1,"contrast mailbox");
 tap(0);tap(1);repeat(200)@(negedge sclk);
 if(cfg_frame[16]!=0 || cfg_frame[7:5]!=5)$fatal(1,"subtitle mailbox");
 $display("PASS tb_extensions_flow: 3-frame fade steps, menu during animation, queued next, mode/volume CDC, PCM, I/O retry, reset recovery");$finish;
end
initial begin #10000000;$fatal(1,"watchdog status=%h presentations=%0d",status,presentations);end
endmodule

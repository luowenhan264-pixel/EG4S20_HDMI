`timescale 1ns/1ps
// Integration test uses the real BMP parser/scheduler and a mocked sector
// transport + SDRAM completion. It does not simulate the vendor SDRAM/HDMI IP.
module tb_player #(parameter SCALE=0);
reg clk=0;always #5 clk=~clk;
reg video_clk=0;always #13 video_clk=~video_clk;
reg rst=1,next_key=1,auto_key=1,finish=0,ack=0,frame_start=0;
wire [3:0] status;
wire displayed,auto_play,req,we,commit_req,commit_ack,video_valid;
wire [1:0] img,wb,db,vb,vi;
wire [31:0] data;
integer writes=0,loads=0,mode=0,cycles=0,commits=0;
reg source_done_seen=0;
sd_card_bmp #(.SCALE_ENABLE(SCALE),.CLK_FREQ_HZ(1000),.SCAN_MAX_SECTOR(6),.AUTO_PERIOD_MS(80),.IO_TIMEOUT_MS(1500)) dut(
 .clk(clk),.rst(rst),.key_next(next_key),.key_auto(auto_key),.state_code(status),
 .bmp_width(16'd4),.bmp_height(16'd2),.display_valid(displayed),.img_idx(img),.auto_play_en(auto_play),
 .write_finish_toggle(finish),.write_buf_idx(wb),.disp_buf_idx(db),
 .display_req_toggle(commit_req),.display_ack_toggle(commit_ack),
 .write_req(req),.write_req_ack(ack),.write_en(we),.write_data(data),.write_ready(1'b1),
 .SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1),
 .control_next(1'b0),.control_auto(1'b0),.control_pause(1'b0),.control_period_ms(32'd80));
player_frame_commit commit(video_clk,rst,frame_start,commit_req,db,img,commit_ack,vb,vi,video_valid,,);
always @(posedge clk) begin
 ack<=req;
 if(we) begin
   writes<=writes+1;
   if(video_valid && wb==vb) $fatal(1,"writing displayed bank");
   if(data!==32'h12345600) $fatal(1,"RGB order");
   if(writes%8==7 && mode==0) finish<=~finish; // memory completes BEFORE sector end
 end
 if(dut.load_start) loads<=loads+1;
 cycles<=cycles+1;
 if(cycles>80000) $fatal(1,"integration watchdog status=%h",status);
end
task vsync_commit;
 integer frames;
 begin
 wait(status==5);repeat(15) @(negedge clk);
 if(commit_req==commit_ack) $fatal(1,"ack before vertical blank");
 frames=0;
 while(commit_req!=commit_ack && frames<80) begin
   @(negedge video_clk);frame_start=1;
   @(negedge video_clk);frame_start=0;
   repeat(4) @(negedge video_clk);
   frames=frames+1;
 end
 if(frames==80) $fatal(1,"fade did not finish");
 wait(commit_req==commit_ack);repeat(8) @(negedge clk);
 commits=commits+1;
 end
endtask
task next_press;
 begin next_key=0;repeat(60) @(negedge clk);next_key=1;repeat(60) @(negedge clk);end
endtask
initial begin
 repeat(5) @(negedge clk);rst=0;
 vsync_commit();
 if(!displayed || vi!=0 || vb!=0 || writes!=8 || dut.found_count!=2) $fatal(1,"initial discovery/load");
 // Completion order reversed: source done first, then SDRAM finishes.
 mode=1;next_press();wait(dut.source_done);
 repeat(20) @(negedge clk);
 if(status==5) $fatal(1,"committed without memory completion");
 finish=~finish;vsync_commit();
 if(vi!=1 || vb!=1 || writes!=16) $fatal(1,"next image");
 // Enable auto-play and ensure it actually requests another frame.
 mode=0;auto_key=0;repeat(60) @(negedge clk);auto_key=1;
 wait(auto_play);vsync_commit();
 if(vi!=0 || vb!=0) $fatal(1,"auto wrap");
 auto_key=0;repeat(60) @(negedge clk);auto_key=1;wait(!auto_play);
 repeat(180) @(negedge clk);
 // Stall the sector transport. Last displayed image must survive the timeout.
 dut.sd_card_top_m0.stall=1;next_press();wait(status==14);
 if(!displayed || !video_valid || vb!=0) $fatal(1,"lost old frame on timeout");
 dut.sd_card_top_m0.stall=0;next_press();vsync_commit();
 if(status==14 || !displayed || vb!=1) $fatal(1,"retry failed");
 rst=1;finish=0;dut.sd_card_top_m0.empty_card=1;
 repeat(5) @(negedge clk);rst=0;
 wait(status==15);
 if(displayed || video_valid) $fatal(1,"empty card displayed stale frame");
 if(SCALE) $display("PASS tb_player_scaled: scan, both completion orders, auto wrap, safe banks, I/O timeout/retry, empty card");
 else $display("PASS tb_player: scan, both completion orders, auto wrap, safe banks, I/O timeout/retry, empty card");$finish;
end
endmodule

module sd_card_top(input clk,rst,output SD_nCS,SD_DCLK,SD_MOSI,input SD_MISO,
 output reg sd_init_done=0,input sd_sec_read,input [31:0] sd_sec_read_addr,
 output reg [7:0] sd_sec_read_data=0,output reg sd_sec_read_data_valid=0,sd_sec_read_end=0,
 input sd_sec_write,input [31:0] sd_sec_write_addr,input [7:0] sd_sec_write_data,
 output sd_sec_write_data_req,sd_sec_write_end);
reg stall=0,empty_card=0;
integer phase=0,index=0;
reg [31:0] addr;
assign SD_nCS=1;assign SD_DCLK=0;assign SD_MOSI=1;
assign sd_sec_write_data_req=0;assign sd_sec_write_end=0;
function automatic [7:0] value(input integer p);
 begin
 value=0;
 case(p)
 0:value="B";1:value="M";2:value=78;10:value=54;14:value=40;
 18:value=4;22:value=2;26:value=1;28:value=24;
 default:if(p>=54 && p<78) case((p-54)%3)
 0:value=8'h56;1:value=8'h34;2:value=8'h12;endcase
 endcase
 end
endfunction
always @(negedge clk) begin
 if(rst) begin phase=0;sd_init_done=0;sd_sec_read_data_valid=0;sd_sec_read_end=0;end
 else begin
 sd_init_done=1;sd_sec_read_data_valid=0;sd_sec_read_end=0;
 if(!stall) case(phase)
 0:if(sd_sec_read) begin addr=sd_sec_read_addr;index=0;phase=1;end
 1:begin
    sd_sec_read_data=(!empty_card && (addr==2 || addr==4))?value(index):0;
    sd_sec_read_data_valid=1;index=index+1;
    if(index==512) phase=2;
 end
 2:begin sd_sec_read_end=1;phase=3;end
 3:phase=0;
 endcase
 end
end
endmodule

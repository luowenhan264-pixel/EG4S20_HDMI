`timescale 1ns/1ps
`include "global_def.v"
// Test the real frame controllers at the new clock rates. FIFO occupancy and
// SDRAM return latency are behavioral models; this is not an electrical test.
module tb_memory_schedule #(parameter FAST=0);
reg mem_clk=0,sd_clk=0,video_clk=0;
always #10 mem_clk=~mem_clk; // 50 MHz
always #5 sd_clk=~sd_clk;   // 100 MHz
initial begin #13;forever #20 video_clk=~video_clk;end // asynchronous phase
reg rst=1,rreq=0,wreq=0,start_video=0,start_feed=0;
wire rack,wack,rdone,wdone,rbusy,wbusy,ren,wen,rclr,wclr;
wire [20:0] raddr,waddr;
integer issued=0,returned=0,consumed=0,fed=0,written=0,divider=0;
integer video_tick=0;
reg [7:0] rdpipe=0;
reg [9:0] rused0=0,rused1=0,wused0=0,wused1=0;
reg saw_rdone=0,saw_wdone=0;
wire active_pixel=start_video && video_tick/800>=35 && video_tick/800<515 &&
                   video_tick%800>=144 && video_tick%800<784;
frame_fifo_read #(.BURST_SIZE(256)) reader(
 .rst(rst),.mem_clk(mem_clk),.Sdr_init_done(!rst),.Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),
 .Sdr_rd_en(rdpipe[7]),.App_wr_busy(wbusy),.O_rd_busy(rbusy),.App_rd_en(ren),.App_rd_addr(raddr),
 .read_req(rreq),.read_req_ack(rack),.read_finish(rdone),.read_addr_0(21'd0),
 .read_addr_1(21'd0),.read_addr_2(21'd0),.read_addr_3(21'd0),.read_addr_index(2'd0),
 .read_len(21'd307200),.fifo_aclr(rclr),.wrusedw(rused1));
frame_fifo_write #(.WRITE_V_FLIP(!FAST),.BURST_SIZE(256),.FRAME_HEIGHT(4)) writer(
 .rst(rst),.mem_clk(mem_clk),.Sdr_init_done(!rst),.Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),
 .App_rd_busy(rbusy),.O_wr_busy(wbusy),.App_wr_en(wen),.App_wr_addr(waddr),
 .write_req(wreq),.write_req_ack(wack),.write_finish(wdone),.write_addr_0(21'd307200),
 .write_addr_1(21'd0),.write_addr_2(21'd0),.write_addr_3(21'd0),.write_addr_index(2'd0),
 .write_len(21'd2560),.fifo_aclr(wclr),.rdusedw(wused1));
always @(posedge mem_clk) begin
 if(!rst) begin
   rused0<=returned-consumed;rused1<=rused0;
   wused0<=fed-written;wused1<=wused0;
   rdpipe<={rdpipe[6:0],ren};
   if(ren) begin
     if(raddr!==issued || wen) $fatal(1,"read address/arbitration");
     issued<=issued+1;
   end
   if(rdpipe[7]) begin
     if(returned-consumed>=512) $fatal(1,"read FIFO overflow");
     returned<=returned+1;
   end
   if(wen) begin
     if(fed-written<=0) $fatal(1,"write FIFO underflow");
     if(waddr!==(FAST ? 307200+written : 307200+(3-written/640)*640+written%640)) $fatal(1,"frame address %0d",written);
     written<=written+1;
   end
   if(rdone) saw_rdone<=1;
   if(wdone) saw_wdone<=1;
 end
end
always @(posedge sd_clk) if(start_feed && fed<2560) begin
 if(divider==(FAST ? 13:95) && (!FAST || fed-written<480)) begin
   divider<=0;
   if(fed-written>=512) $fatal(1,"write FIFO overflow");
   fed<=fed+1;
 end else if(divider<(FAST ? 13:95)) divider<=divider+1;
end
always @(posedge video_clk) if(start_video) begin
 if(video_tick<420000) video_tick<=video_tick+1;
 if(active_pixel) begin
   if(returned-consumed<=0) $fatal(1,"video underflow at pixel %0d",consumed);
   consumed<=consumed+1;
 end
end
initial begin
 if(`SDR_CLK_PERIOD!=20 || `SELF_REFRESH_INTERVAL!=781) $fatal(1,"SDRAM refresh constants");
 repeat(8) @(negedge mem_clk);rst=0;rreq=1;wreq=1;
 wait(rack && wack);@(negedge mem_clk);rreq=0;wreq=0;
 wait(!rack && !wack);repeat(8) @(negedge mem_clk);
 start_feed=1;start_video=1;
 wait(video_tick==420000);repeat(20) @(negedge mem_clk);
 if(!saw_rdone || !saw_wdone || issued!=307200 || returned!=307200 || consumed!=307200 || written!=2560)
   $fatal(1,"incomplete frame traffic %0d %0d %0d %0d",issued,returned,consumed,written);
 if(FAST) $display("PASS tb_memory_scale: fast scaled pixels, top-down writes, 50MHz memory/25MHz video, no FIFO under/overflow");
 else $display("PASS tb_memory_schedule: 50MHz memory/25MHz video, 307200 pixels, concurrent TF writes, no FIFO under/overflow, vertical flip, refresh constants");
 $finish;
end
initial begin #20000000;$fatal(1,"memory scheduling watchdog");end
endmodule

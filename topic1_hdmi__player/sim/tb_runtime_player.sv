`timescale 1ns/1ps
module tb_runtime_player;
reg clk=0,rst=1,n=1,a=1,finish=0,write_ack=0;
always #5 clk=~clk;
wire np,ap,menu,mode,displayed,auto_play,req,we,commit_req,commit_ack,valid;
wire [2:0] field;
wire [1:0] period,volume,img,wb,db,vb,vi;
wire [31:0] ms,data;wire [3:0] status;
integer writes=0,loads=0,base_loads;
player_controls #(.CLK_FREQ_HZ(1000),.DEBOUNCE_MS(2),.LONG_MS(16))
 controls(clk,rst,n,a,np,ap,menu,field,period,volume,mode,ms,,,);
sd_card_bmp #(.CLK_FREQ_HZ(1000),.SCAN_MAX_SECTOR(6),.IO_TIMEOUT_MS(1500),.EXTERNAL_CONTROL(1)) dut(
 .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.state_code(status),
 .bmp_width(16'd4),.bmp_height(16'd2),.display_valid(displayed),.img_idx(img),.auto_play_en(auto_play),
 .write_finish_toggle(finish),.write_buf_idx(wb),.disp_buf_idx(db),
 .display_req_toggle(commit_req),.display_ack_toggle(commit_ack),
 .write_req(req),.write_req_ack(write_ack),.write_en(we),.write_data(data),
 .SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1),
 .control_next(np),.control_auto(ap),.control_pause(menu),.control_period_ms(ms));
player_frame_commit #(.FADE_ENABLE(0))
 commit(clk,rst,1'b1,commit_req,db,img,commit_ack,vb,vi,valid,,);
always @(posedge clk) begin
 write_ack<=req;
 if(we) begin writes<=writes+1;if(writes%8==7)finish<=~finish;end
 if(dut.load_start)loads<=loads+1;
 if(valid && we && wb==vb)$fatal(1,"write displayed bank");
end
task tap(input integer key);
 begin @(negedge clk);if(key==0)n=0;else a=0;
 repeat(7)@(negedge clk);n=1;a=1;repeat(8)@(negedge clk);end
endtask
task long_auto;
 begin @(negedge clk);a=0;repeat(35)@(negedge clk);a=1;repeat(8)@(negedge clk);end
endtask
initial begin
 repeat(5)@(negedge clk);rst=0;wait(displayed);repeat(8)@(negedge clk);
 tap(1);if(!auto_play)$fatal(1,"short auto");base_loads=loads;
 repeat(100)@(negedge clk);long_auto();if(!menu)$fatal(1,"menu open");
 repeat(2200)@(negedge clk);if(loads!=base_loads)$fatal(1,"auto advances in menu");
 tap(1);if(ms!=5000)$fatal(1,"runtime period");long_auto();
 repeat(4500)@(negedge clk);if(loads!=base_loads)$fatal(1,"period ignored");
 wait(loads==base_loads+1);wait(dut.state==5);tap(1);
 if(auto_play)$fatal(1,"auto off");base_loads=loads;
 tap(0);wait(loads==base_loads+1);wait(dut.state==5);
 // Change presets while paused, exit, then require a fresh full interval.
 long_auto();tap(1);tap(1);if(ms!=2000)$fatal(1,"period cycle");
 long_auto();tap(1);base_loads=loads;
 repeat(1850)@(negedge clk);if(loads!=base_loads)$fatal(1,"stale elapsed timer");
 wait(loads==base_loads+1);
 $display("PASS tb_runtime_player: real keys/menu + scheduler, pause, runtime 5s/2s timing, manual/auto, safe banks");$finish;
end
initial begin #1000000;$fatal(1,"watchdog status=%h",status);end
endmodule

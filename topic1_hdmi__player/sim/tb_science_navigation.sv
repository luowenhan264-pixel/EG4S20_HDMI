`timescale 1ns/1ps
module tb_science_navigation;
reg clk=0,rst=1,n=1,p=1,a=1,finish=0,ack=0;always #5 clk=~clk;
wire next_,prev_,auto_,menu,ready,valid,displayed,playing,req,we,cr,ca,sub;
wire [1:0] page,img,wb,db,vb,choice,cp,vol,period;
wire [2:0] field,con;wire [3:0] bri,status;wire [31:0] data;
integer writes=0,loads=0;
science_controls #(.CLK_FREQ_HZ(1000),.DEBOUNCE_MS(2),.LONG_MS(16)) controls(
 clk,rst,n,p,a,page,ready,next_,prev_,auto_,menu,field,choice,cp,vol,period,bri,con,sub);
sd_card_bmp #(.CLK_FREQ_HZ(1000),.EXTERNAL_CONTROL(1),.PREV_ENABLE(1),.USE_FIXED_SECTORS(1),
 .IMG_COUNT(4),.IMG_SECTOR0(2),.IMG_SECTOR1(4),.IMG_SECTOR2(2),.IMG_SECTOR3(4)) dut(
 .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.state_code(status),
 .bmp_width(16'd4),.bmp_height(16'd2),.display_valid(displayed),.img_idx(img),.auto_play_en(playing),
 .write_finish_toggle(finish),.write_buf_idx(wb),.disp_buf_idx(db),.display_req_toggle(cr),.display_ack_toggle(ca),
 .write_req(req),.write_req_ack(ack),.write_en(we),.write_data(data),.write_ready(1'b1),
 .SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1),.control_next(next_),.control_prev(prev_),
 .navigation_ready(ready),.control_auto(auto_),.control_pause(menu),.control_period_ms(32'd10000));
player_frame_commit #(.FADE_ENABLE(0)) commit(clk,rst,1'b1,cr,db,img,ca,vb,page,valid,,);
always @(posedge clk)begin
 ack<=req;if(we)begin writes++;if(writes%8==0)finish<=~finish;end
 if(valid&&we&&wb==vb)$fatal(1,"write displayed buffer");
 if(dut.load_start)loads++;
end
task tap(input integer k);begin
 @(negedge clk);case(k)0:n=0;1:p=0;2:a=0;endcase
 repeat(7)@(negedge clk);n=1;p=1;a=1;repeat(8)@(negedge clk);
end endtask
task navigate(input integer k,expected);integer before_;begin
 before_=loads;tap(k);wait(loads>before_);wait(ready);repeat(10)@(negedge clk);
 if(page!=expected||cp!=expected)$fatal(1,"page direction expected %d got %d",expected,page);
 if(choice!=((page==1||page==2)?1:0))$fatal(1,"page default");
end endtask
initial begin
 repeat(5)@(negedge clk);rst=0;wait(ready);repeat(10)@(negedge clk);
 if(page!=0||playing)$fatal(1,"startup");
 navigate(1,3);navigate(1,2);tap(2);if(choice!=2)$fatal(1,"amplitude experiment");
 navigate(1,1);navigate(1,0);navigate(0,1);navigate(0,2);navigate(0,3);navigate(0,0);
 dut.sd_card_top_m0.stall=1;tap(0);repeat(30)@(negedge clk);
 tap(1);tap(2);if(choice!=0)$fatal(1,"busy experimental input leaked");
 dut.sd_card_top_m0.stall=0;wait(ready);repeat(20)@(negedge clk);
 if(page!=1)$fatal(1,"busy key queued unwanted reverse");
 $display("PASS tb_science_navigation: real buttons, previous/next four-page wrap, default options, busy guard, safe frame banks");$finish;
end
initial begin #5000000;$fatal(1,"watchdog %d",status);end
endmodule

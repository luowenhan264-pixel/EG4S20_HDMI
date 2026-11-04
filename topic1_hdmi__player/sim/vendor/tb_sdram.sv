`timescale 1ns/1ps
module tb_sdram;
reg clk=0; always #10 clk=~clk;
wire shift_clk;assign #8 shift_clk=clk;
reg rst=1,we=0,re=0;
reg [20:0] wa=0,ra=0;
reg [31:0] din=0;
wire init,refresh,busy,rv;
wire [31:0] dout;
integer i,received=0,refreshes=0;
sdram dut(.Clk(clk),.Clk_sft(shift_clk),.Rst(rst),.Sdr_init_done(init),
 .Sdr_init_ref_vld(refresh),.Sdr_busy(busy),.App_wr_en(we),.App_wr_addr(wa),
 .App_wr_dm(4'd0),.App_wr_din(din),.App_rd_en(re),.App_rd_addr(ra),
 .Sdr_rd_en(rv),.Sdr_rd_dout(dout));
reg refresh_old=0;
always @(posedge clk) begin
 refresh_old<=refresh;
 if(init && refresh && !refresh_old) refreshes<=refreshes+1;
 if(rv) begin
   if(dout!==(32'h5a000000 ^ received)) $fatal(1,"SDRAM read %0d got %h",received,dout);
   received<=received+1;
 end
end
initial begin
 repeat(10) @(negedge clk);rst=0;
 wait(init);repeat(10) @(negedge clk);
 for(i=0;i<256;i=i+1) begin we=1;wa=i;din=32'h5a000000^i;@(negedge clk);end
 we=0;
 repeat(1000) @(negedge clk);
 for(i=0;i<256;i=i+1) begin re=1;ra=i;@(negedge clk);end
 re=0;
 repeat(100) @(negedge clk);
 if(received!=256 || refreshes==0) $fatal(1,"readback/refresh incomplete: %0d/%0d",received,refreshes);
 $display("PASS tb_sdram: 50 MHz +8 ns, write/read 256 words across refresh");$finish;
end
initial begin #5000000;$fatal(1,"SDRAM initialization watchdog");end
endmodule

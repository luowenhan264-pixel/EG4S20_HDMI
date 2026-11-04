`timescale 1ns/1ps
module tb_science_controls;
reg clk=0,rst=1,n=1,p=1,a=1,ready=1;always #5 clk=~clk;
reg [1:0] page=0;
wire np,pp,ap,menu,sub;wire [2:0] field,con;wire [1:0] choice,cp,vol,period;wire [3:0] bri;
integer nc=0,pc=0,ac=0,i;
science_controls #(.CLK_FREQ_HZ(1000),.DEBOUNCE_MS(2),.LONG_MS(16)) dut(
 clk,rst,n,p,a,page,ready,np,pp,ap,menu,field,choice,cp,vol,period,bri,con,sub);
always @(posedge clk)begin if(np)nc++;if(pp)pc++;if(ap)ac++;end
task tap(input integer k);begin
 @(negedge clk);case(k)0:n=0;1:p=0;2:a=0;endcase
 repeat(7)@(negedge clk);n=1;p=1;a=1;repeat(8)@(negedge clk);
end endtask
task hold_action;begin a=0;repeat(40)@(negedge clk);a=1;repeat(8)@(negedge clk);end endtask
initial begin
 repeat(5)@(negedge clk);rst=0;repeat(5)@(negedge clk);
 if(vol!=2||period!=1||choice||menu)$fatal(1,"defaults");
 n=0;@(negedge clk);n=1;repeat(8)@(negedge clk);if(nc)$fatal(1,"bounce");
 tap(0);tap(1);if(nc!=1||pc!=1)$fatal(1,"page directions");
 for(i=0;i<4;i++)tap(2);if(choice!=0||ac)$fatal(1,"wave cycle or auto leak");
 page=1;repeat(5)@(negedge clk);if(choice!=1||cp!=1)$fatal(1,"pitch default");
 tap(2);if(choice!=2)$fatal(1,"880");tap(2);if(choice!=0)$fatal(1,"pitch wrap");
 page=2;repeat(5)@(negedge clk);if(choice!=1)$fatal(1,"amp default");
 ready=0;tap(2);tap(0);tap(1);if(choice!=1||nc!=1||pc!=1)$fatal(1,"busy input");ready=1;
 hold_action();if(!menu||choice!=1)$fatal(1,"long/short exclusivity");
 tap(1);if(field!=5)$fatal(1,"reverse menu wrap");tap(0);if(field!=0)$fatal(1,"forward menu wrap");
 tap(2);if(vol!=3)$fatal(1,"vol");tap(0);tap(2);if(bri!=5)$fatal(1,"bri");
 tap(0);tap(2);if(con!=3)$fatal(1,"con");tap(0);tap(2);if(sub)$fatal(1,"subtitle");
 tap(0);tap(2);if(ac!=1)$fatal(1,"auto menu");
 hold_action();if(menu||choice!=1||nc!=1||pc!=1)$fatal(1,"menu leaked");
 n=0;p=0;repeat(30)@(negedge clk);n=1;repeat(4)@(negedge clk);p=1;repeat(8)@(negedge clk);
 if(nc!=1||pc!=1)$fatal(1,"chord");
 page=3;repeat(5)@(negedge clk);if(choice!=0)$fatal(1,"music default");
 $display("PASS tb_science_controls: directions, debounce, long exclusivity, four-page defaults, menu, busy guard, chords");$finish;
end
initial begin #200000;$fatal(1,"watchdog");end
endmodule

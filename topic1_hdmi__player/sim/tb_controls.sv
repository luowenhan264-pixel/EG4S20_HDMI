`timescale 1ns/1ps
module tb_controls;
reg clk=0,dclk=0,rst=1,n=1,a=1;
always #5 clk=~clk;always #17 dclk=~dclk;
wire np,ap,menu,mode;
wire [2:0] field;
wire [1:0] period,volume;
wire [31:0] ms;wire [3:0] brightness;wire [2:0] contrast;wire subtitle;
integer nc=0,ac=0;
player_controls #(.CLK_FREQ_HZ(1000),.DEBOUNCE_MS(2),.LONG_MS(16))
    dut(clk,rst,n,a,np,ap,menu,field,period,volume,mode,ms,brightness,contrast,subtitle);
reg [7:0] cfg=0;wire [7:0] received;
player_config_cdc mailbox(clk,rst,cfg,dclk,rst,received);
always @(posedge clk) begin if(np)nc=nc+1;if(ap)ac=ac+1;end
always @(posedge dclk) begin
 #1;if(!rst && received!=0 && received!=8'h5a && received!=8'ha5 && received!=8'hff)
     $fatal(1,"torn CDC snapshot: %h",received);
end
task tap(input integer which);
 begin @(negedge clk);if(which==0)n=0;else a=0;
 repeat(7) @(negedge clk);n=1;a=1;repeat(8) @(negedge clk);end
endtask
task long_auto;
 begin @(negedge clk);a=0;repeat(50) @(negedge clk);a=1;repeat(8) @(negedge clk);end
endtask
integer k;
initial begin
 repeat(5) @(negedge clk);rst=0;repeat(8) @(negedge clk);
 if(menu || field || period || volume!=3 || !mode || ms!=2000) $fatal(1,"defaults");
 // Bounce shorter than debounce must not produce an action.
 n=0;@(negedge clk);n=1;repeat(8) @(negedge clk);
 if(nc || ac) $fatal(1,"bounce");
 tap(0);tap(1);if(nc!=1 || ac!=1) $fatal(1,"short action");
 long_auto();if(!menu || nc!=1 || ac!=1) $fatal(1,"long opened menu plus accidental action");
 tap(1);if(period!=1 || ms!=5000) $fatal(1,"period5");
 tap(1);if(period!=2 || ms!=10000) $fatal(1,"period10");
 tap(1);if(period!=0 || ms!=2000) $fatal(1,"period wrap");
 tap(0);if(field!=1) $fatal(1,"select volume");
 for(k=0;k<4;k=k+1) begin tap(1);if(volume!==2'(k))$fatal(1,"volume cycle");end
 tap(0);tap(1);if(field!=2 || mode) $fatal(1,"sound mode");
 tap(0);if(field!=3 || brightness!=4 || contrast!=2 || !subtitle)$fatal(1,"display defaults");
 for(k=0;k<9;k=k+1) begin tap(1);if(brightness!=(5+k)%9)$fatal(1,"brightness wrap");end
 tap(0);for(k=0;k<5;k=k+1) begin tap(1);if(contrast!=(3+k)%5)$fatal(1,"contrast wrap");end
 tap(0);tap(1);if(field!=5 || subtitle)$fatal(1,"subtitle toggle");
 tap(0);if(field!=0)$fatal(1,"six field wrap");
 if(nc!=1 || ac!=1) $fatal(1,"menu leaked playback actions");
 long_auto();if(menu || ac!=1) $fatal(1,"exit long");
 n=0;a=0;repeat(30) @(negedge clk);n=1;repeat(5) @(negedge clk);a=1;
 repeat(10) @(negedge clk);if(menu || nc!=1 || ac!=1) $fatal(1,"chord leakage");
 cfg=8'h5a;repeat(3) @(negedge clk);cfg=8'ha5;
 repeat(4) @(negedge clk);cfg=8'hff;repeat(80) @(negedge clk);
 if(received!=8'hff) $fatal(1,"CDC latest value lost");
 rst=1;cfg=0;repeat(5) @(negedge clk);rst=0;repeat(20) @(negedge clk);
 if(received || menu || volume!=3 || !mode || brightness!=4 || contrast!=2 || !subtitle) $fatal(1,"reset defaults");
 $display("PASS tb_controls: debounce, short/long exclusivity, menu, presets, chord, coherent CDC and reset");$finish;
end
initial begin #200000;$fatal(1,"watchdog");end
endmodule

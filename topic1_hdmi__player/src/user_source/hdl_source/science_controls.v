// Board keys: KEY2 next, KEY3 previous, KEY4 experiment/menu.
module science_controls #(
 parameter integer CLK_FREQ_HZ=100000000, DEBOUNCE_MS=20, LONG_MS=800
)(input clk,rst,key_next,key_prev,key_action,input [1:0] page,input ready,
 output reg next_pulse,prev_pulse,auto_pulse,
 output reg menu_open,output reg [2:0] field,
 output reg [1:0] choice,choice_page,volume,period_sel,
 output reg [3:0] brightness,output reg [2:0] contrast,output reg subtitle_enable);
localparam DIV=CLK_FREQ_HZ<1000 ? 1:CLK_FREQ_HZ/1000;
localparam DW=DIV<2 ? 1:$clog2(DIV);
reg [DW-1:0] divider;
wire tick=divider==DIV-1;
wire ns,ps,as_,nl,pl,al,nd,pd,ad;
reg chord;
wire multi=(nd&&pd)||(nd&&ad)||(pd&&ad);
player_button #(.DEBOUNCE_MS(DEBOUNCE_MS),.LONG_MS(LONG_MS))
 nb(clk,rst,tick,key_next,nd,ns,nl),
 pb(clk,rst,tick,key_prev,pd,ps,pl),
 ab(clk,rst,tick,key_action,ad,as_,al);
always @(posedge clk or posedge rst) begin
 if(rst) begin
  divider<=0;chord<=0;next_pulse<=0;prev_pulse<=0;auto_pulse<=0;
  menu_open<=0;field<=0;choice<=0;choice_page<=0;volume<=2;
  period_sel<=1;brightness<=4;contrast<=2;subtitle_enable<=1;
 end else begin
  divider<=tick ? 0:divider+1'b1;
  next_pulse<=0;prev_pulse<=0;auto_pulse<=0;
  if(multi)chord<=1;else if(!nd&&!pd&&!ad)chord<=0;
  if(page!=choice_page)begin choice_page<=page;choice<=(page==1||page==2)?1:0;end
  if(!chord&&!multi)begin
   if(al)begin menu_open<=~menu_open;field<=0;end
   else if(menu_open)begin
    if(ns)field<=field==5 ? 0:field+1'b1;
    if(ps)field<=field==0 ? 5:field-1'b1;
    if(as_)case(field)
     0:volume<=volume+1'b1;
     1:brightness<=brightness==8 ? 0:brightness+1'b1;
     2:contrast<=contrast==4 ? 0:contrast+1'b1;
     3:subtitle_enable<=~subtitle_enable;
     4:auto_pulse<=1;
     5:period_sel<=period_sel==2 ? 0:period_sel+1'b1;
    endcase
   end else if(ready)begin
    next_pulse<=ns;prev_pulse<=ps;
    if(as_&&page==choice_page)choice<=page==1 && choice==2 ? 0:choice+1'b1;
   end
  end
 end
end
endmodule

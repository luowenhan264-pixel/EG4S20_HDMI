// Active-low key: debounce both edges, short on release, long exactly once.
module player_button #(
    parameter integer DEBOUNCE_MS=20, LONG_MS=800
)(input clk,rst,tick_ms,button_in,
  output down, output reg short_pulse,long_pulse);
reg [1:0] sync;
reg stable,long_sent;
reg [15:0] debounce_count,held_ms;
assign down=~stable;
always @(posedge clk or posedge rst) begin
    if(rst) begin
        sync<=3;stable<=1;long_sent<=0;debounce_count<=0;held_ms<=0;
        short_pulse<=0;long_pulse<=0;
    end else begin
        sync<={sync[0],button_in};short_pulse<=0;long_pulse<=0;
        if(tick_ms) begin
            if(sync[1]==stable) debounce_count<=0;
            else if(debounce_count==DEBOUNCE_MS-1) begin
                debounce_count<=0;stable<=sync[1];held_ms<=0;
                if(!sync[1]) long_sent<=0;
                else if(!long_sent) short_pulse<=1;
            end else debounce_count<=debounce_count+1'b1;
            if(!stable && !(sync[1]!=stable && debounce_count==DEBOUNCE_MS-1)) begin
                if(!long_sent) begin
                    if(held_ms==LONG_MS-1) begin long_sent<=1;long_pulse<=1;end
                    else held_ms<=held_ms+1'b1;
                end
            end
        end
    end
end
endmodule

module player_controls #(
    parameter integer CLK_FREQ_HZ=100000000, DEBOUNCE_MS=20, LONG_MS=800,
    parameter [1:0] DEFAULT_PERIOD_SEL=0
)(input clk,rst,key_next,key_auto,
  output reg next_pulse,auto_pulse,
  output reg menu_open,
  output reg [2:0] menu_field,
  output reg [1:0] period_sel,volume,
  output reg two_note,
  output [31:0] period_ms,
  output reg [3:0] brightness,output reg [2:0] contrast,output reg subtitle_enable);
localparam integer MS_CYCLES=CLK_FREQ_HZ<1000 ? 1 : CLK_FREQ_HZ/1000;
localparam integer DIV_BITS=MS_CYCLES<2 ? 1 : $clog2(MS_CYCLES);
reg [DIV_BITS-1:0] divider;
wire tick_ms=divider==MS_CYCLES-1;
wire next_short,auto_short,next_long,auto_long,next_down,auto_down;
reg chord;
player_button #(.DEBOUNCE_MS(DEBOUNCE_MS),.LONG_MS(LONG_MS))
    next_button(clk,rst,tick_ms,key_next,next_down,next_short,next_long),
    auto_button(clk,rst,tick_ms,key_auto,auto_down,auto_short,auto_long);
assign period_ms=period_sel==0 ? 32'd2000 : period_sel==1 ? 32'd5000 : 32'd10000;
always @(posedge clk or posedge rst) begin
    if(rst) begin
        divider<=0;next_pulse<=0;auto_pulse<=0;menu_open<=0;menu_field<=0;
        period_sel<=DEFAULT_PERIOD_SEL>2 ? 0 : DEFAULT_PERIOD_SEL;
        volume<=3;two_note<=1;chord<=0;brightness<=4;contrast<=2;subtitle_enable<=1;
    end else begin
        if(tick_ms) divider<=0;else divider<=divider+1'b1;
        next_pulse<=0;auto_pulse<=0;
        if(next_down && auto_down) chord<=1;
        else if(!next_down && !auto_down) chord<=0;
        // Simultaneous presses are ignored through both releases.
        if(!chord && !(next_down && auto_down)) begin
            if(auto_long) begin menu_open<=~menu_open;menu_field<=0;end
            else if(menu_open) begin
                if(next_short) menu_field<=menu_field==5 ? 0 : menu_field+1'b1;
                if(auto_short) case(menu_field)
                    0: period_sel<=period_sel==2 ? 0 : period_sel+1'b1;
                    1: volume<=volume+1'b1;
                    2: two_note<=~two_note;
                    3: brightness<=brightness==8 ? 0 : brightness+1'b1;
                    4: contrast<=contrast==4 ? 0 : contrast+1'b1;
                    5: subtitle_enable<=~subtitle_enable;
                    default: menu_field<=0;
                endcase
            end else begin
                next_pulse<=next_short;auto_pulse<=auto_short;
            end
        end
    end
end
endmodule

// Coherent snapshot mailbox. Both resets derive from the same board reset.
// Source holds payload until ACK. Updates while busy coalesce to latest value.
module player_config_cdc #(parameter WIDTH=8, parameter [WIDTH-1:0] RESET_VALUE=0)(
    input src_clk,src_rst,input [WIDTH-1:0] src_value,
    input dst_clk,dst_rst,output reg [WIDTH-1:0] dst_value
);
reg [WIDTH-1:0] held,data_d0,data_d1;
reg request,ack;
(* syn_preserve=1 *) reg [2:0] request_sync,ack_sync;
always @(posedge src_clk or posedge src_rst) begin
    if(src_rst) begin held<=RESET_VALUE;request<=0;ack_sync<=0;end
    else begin
        ack_sync<={ack_sync[1:0],ack};
        if(ack_sync[2]==request && src_value!=held) begin
            held<=src_value;request<=~request;
        end
    end
end
always @(posedge dst_clk or posedge dst_rst) begin
    if(dst_rst) begin
        request_sync<=0;ack<=0;data_d0<=RESET_VALUE;data_d1<=RESET_VALUE;dst_value<=RESET_VALUE;
    end else begin
        request_sync<={request_sync[1:0],request};data_d0<=held;data_d1<=data_d0;
        if(request_sync[2]!=ack) begin dst_value<=data_d1;ack<=request_sync[2];end
    end
end
endmodule

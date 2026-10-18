// 640x480 OSD：左上角色条/色块显示图序号、自动播放、状态码（无需字模 ROM）
module osd_overlay_640x480 (
    input                       video_clk,
    input                       rst,
    input                       hs,
    input                       vs,
    input                       de,
    input  [1:0]                img_idx,
    input                       auto_play_en,
    input  [3:0]                state_code,
    input  [23:0]               vout_data_raw,
    output reg [23:0]           osd_rgb
);

localparam [9:0] BAR_Y0  = 10'd8;
localparam [9:0] BAR_Y1  = 10'd28;
localparam [9:0] BOX_W   = 10'd28;
localparam [9:0] BOX_GAP = 10'd6;
localparam [9:0] BOX0_X  = 10'd8;
localparam [9:0] AUTO_X  = 10'd140;
localparam [9:0] AUTO_W  = 10'd40;
localparam [9:0] STAT_X  = 10'd196;
localparam [9:0] STAT_W  = 10'd12;

reg        de_d;
reg        vs_d;
reg [9:0]  x_cnt;
reg [9:0]  y_cnt;

wire       vs_fall = vs_d & ~vs;
wire [9:0] x_cur   = de ? (de_d ? (x_cnt + 10'd1) : 10'd0) : 10'd0;
wire [9:0] y_cur   = y_cnt;

wire       in_bar_y = (y_cur >= BAR_Y0) && (y_cur < BAR_Y1);

wire [9:0] box1_x0 = BOX0_X + (BOX_W + BOX_GAP);
wire [9:0] box2_x0 = BOX0_X + 2*(BOX_W + BOX_GAP);
wire [9:0] box3_x0 = BOX0_X + 3*(BOX_W + BOX_GAP);

wire in_box0 = (x_cur >= BOX0_X) && (x_cur < (BOX0_X + BOX_W));
wire in_box1 = (x_cur >= box1_x0) && (x_cur < (box1_x0 + BOX_W));
wire in_box2 = (x_cur >= box2_x0) && (x_cur < (box2_x0 + BOX_W));
wire in_box3 = (x_cur >= box3_x0) && (x_cur < (box3_x0 + BOX_W));
wire in_idx_box = in_bar_y && (in_box0 | in_box1 | in_box2 | in_box3);

wire [1:0] box_sel =
    in_box0 ? 2'd0 :
    in_box1 ? 2'd1 :
    in_box2 ? 2'd2 :
              2'd3;

wire in_auto_box = in_bar_y && (x_cur >= AUTO_X) && (x_cur < (AUTO_X + AUTO_W));

wire [9:0] st0_x0 = STAT_X;
wire [9:0] st1_x0 = STAT_X + (STAT_W + 10'd2);
wire [9:0] st2_x0 = STAT_X + 2*(STAT_W + 10'd2);
wire [9:0] st3_x0 = STAT_X + 3*(STAT_W + 10'd2);

wire in_st0 = (x_cur >= st0_x0) && (x_cur < (st0_x0 + STAT_W));
wire in_st1 = (x_cur >= st1_x0) && (x_cur < (st1_x0 + STAT_W));
wire in_st2 = (x_cur >= st2_x0) && (x_cur < (st2_x0 + STAT_W));
wire in_st3 = (x_cur >= st3_x0) && (x_cur < (st3_x0 + STAT_W));
wire in_stat_box = in_bar_y && (in_st0 | in_st1 | in_st2 | in_st3);

wire [23:0] color_dim_white = 24'h606060;
wire [23:0] color_hi_yellow = 24'hFFFF00;
wire [23:0] color_auto_on   = 24'h00C000;
wire [23:0] color_auto_off  = 24'hC00000;
wire [23:0] color_stat_on   = 24'h00A0FF;
wire [23:0] color_stat_off  = 24'h202020;

wire [23:0] idx_color  = (box_sel == img_idx) ? color_hi_yellow : color_dim_white;
wire [23:0] auto_color = auto_play_en ? color_auto_on : color_auto_off;
wire [23:0] stat_color =
    in_st0 ? (state_code[3] ? color_stat_on : color_stat_off) :
    in_st1 ? (state_code[2] ? color_stat_on : color_stat_off) :
    in_st2 ? (state_code[1] ? color_stat_on : color_stat_off) :
             (state_code[0] ? color_stat_on : color_stat_off);

wire [23:0] mix_rgb =
    in_idx_box  ? idx_color  :
    in_auto_box ? auto_color :
    in_stat_box ? stat_color :
                  vout_data_raw;

always @(posedge video_clk or posedge rst) begin
    if (rst) begin
        de_d    <= 1'b0;
        vs_d    <= 1'b0;
        x_cnt   <= 10'd0;
        y_cnt   <= 10'd0;
        osd_rgb <= 24'd0;
    end else begin
        de_d <= de;
        vs_d <= vs;

        if (vs_fall) begin
            x_cnt <= 10'd0;
            y_cnt <= 10'd0;
        end else if (de) begin
            x_cnt <= x_cur;
        end else if (de_d && !de) begin
            // 行结束：准备下一行
            x_cnt <= 10'd0;
            if (y_cnt < 10'd511)
                y_cnt <= y_cnt + 10'd1;
        end

        if (de)
            osd_rgb <= mix_rgb;
        else
            osd_rgb <= 24'd0;
    end
end

endmodule

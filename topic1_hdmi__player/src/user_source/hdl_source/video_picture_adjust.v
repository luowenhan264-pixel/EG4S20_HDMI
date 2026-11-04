// Two-stage signed RGB transform. Contrast is centered on 128.
// brightness 0..8 => -64..+64 (step 16); contrast 0..4 => 50..150%.
// Controls must be frame-latched by the caller. Saturation never wraps.
module video_picture_adjust(
    input clk,rst,hs,vs,de,input [23:0] rgb,
    input [3:0] brightness,input [2:0] contrast,
    output reg hs_out,vs_out,de_out,output reg [23:0] rgb_out
);
wire signed [15:0] r_center=$signed({1'b0,rgb[23:16]})-16'sd128;
wire signed [15:0] g_center=$signed({1'b0,rgb[15:8]})-16'sd128;
wire signed [15:0] b_center=$signed({1'b0,rgb[7:0]})-16'sd128;
wire signed [15:0] coefficient=16'sd2+$signed({1'b0,contrast});
wire signed [15:0] bias=($signed({1'b0,brightness})-16'sd4)*16'sd16+16'sd128;
reg signed [15:0] r_mul,g_mul,b_mul,bias_d;
reg h_d,v_d,d_d;
function [7:0] saturate;
    input signed [15:0] value;
    begin saturate=value<0 ? 8'd0 : value>255 ? 8'd255 : value[7:0];end
endfunction
always @(posedge clk or posedge rst) begin
    if(rst) begin
        r_mul<=0;g_mul<=0;b_mul<=0;bias_d<=128;
        h_d<=0;v_d<=0;d_d<=0;hs_out<=0;vs_out<=0;de_out<=0;rgb_out<=0;
    end else begin
        r_mul<=r_center*coefficient;g_mul<=g_center*coefficient;b_mul<=b_center*coefficient;
        bias_d<=bias;h_d<=hs;v_d<=vs;d_d<=de;
        hs_out<=h_d;vs_out<=v_d;de_out<=d_d;
        rgb_out<=d_d ? {saturate((r_mul>>>2)+bias_d),
                       saturate((g_mul>>>2)+bias_d),saturate((b_mul>>>2)+bias_d)} : 24'd0;
    end
end
endmodule

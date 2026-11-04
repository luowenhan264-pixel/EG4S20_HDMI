// One pixel of latency, including sync/DE. Gain 0..32 gives exact black/full
// brightness endpoints and 31 intermediate levels without a division unit.
module video_fade_rgb(
    input clk, rst, hs, vs, de,
    input [23:0] rgb,
    input [5:0] gain,
    output reg hs_out, vs_out, de_out,
    output [23:0] rgb_out
);
reg [13:0] red_product, green_product, blue_product;
wire [5:0] bounded_gain = gain>32 ? 6'd32 : gain;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        hs_out<=0; vs_out<=0; de_out<=0;
        red_product<=0; green_product<=0; blue_product<=0;
    end else begin
        hs_out<=hs; vs_out<=vs; de_out<=de;
        red_product<=de ? rgb[23:16]*bounded_gain : 14'd0;
        green_product<=de ? rgb[15:8]*bounded_gain : 14'd0;
        blue_product<=de ? rgb[7:0]*bounded_gain : 14'd0;
    end
end
assign rgb_out={red_product[12:5],green_product[12:5],blue_product[12:5]};
endmodule

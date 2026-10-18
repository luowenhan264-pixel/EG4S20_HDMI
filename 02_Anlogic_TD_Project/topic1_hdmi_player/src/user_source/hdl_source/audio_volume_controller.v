// =============================================================================
// Module: audio_volume_controller
// Description: Digital Audio Attenuator & Volume Multiplier
// Features:
//   - 16-step linear volume scaling (0..15)
//   - Digital mute capability
//   - Zero-distortion signed 24-bit fractional multiplier
// =============================================================================
module audio_volume_controller (
    input  wire                 clk,
    input  wire                 rst,
    input  wire [3:0]           vol_level,       // 0..15
    input  wire                 vol_mute,        // 1: Mute, 0: Normal
    input  wire                 audio_valid_in,
    input  wire signed [23:0]   audio_left_in,
    input  wire signed [23:0]   audio_right_in,
    output reg                  audio_valid_out,
    output reg  signed [23:0]   audio_left_out,
    output reg  signed [23:0]   audio_right_out
);

    // Multiplier: Signed 24-bit * Unsigned 5-bit (1..16) -> 29-bit
    wire [4:0] gain = vol_mute ? 5'd0 : (vol_level + 5'd1);

    wire signed [28:0] left_mult  = audio_left_in  * $signed({1'b0, gain});
    wire signed [28:0] right_mult = audio_right_in * $signed({1'b0, gain});

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            audio_valid_out <= 1'b0;
            audio_left_out  <= 24'sd0;
            audio_right_out <= 24'sd0;
        end else begin
            audio_valid_out <= audio_valid_in;
            if (vol_mute || (vol_level == 4'd0)) begin
                audio_left_out  <= 24'sd0;
                audio_right_out <= 24'sd0;
            end else begin
                // Shift right by 4 (divide by 16)
                audio_left_out  <= left_mult[27:4];
                audio_right_out <= right_mult[27:4];
            end
        end
    end

endmodule

// =============================================================================
// Module: osd_text_overlay
// Description: Professional Hardware OSD Overlay Subsystem with 8x16 ASCII Font
// Features:
//   - Translucent dark glass background banner (Alpha 50% blending)
//   - Decorative cyan/gold double-border
//   - Line 0: "EG4S20 HDMI PLAYER"
//   - Line 1: "IMG: 0X/04  AUTO: ON/OFF"
//   - Line 2: "VOL: [||||||||  ] XX%"
//   - Line 3: "BUF: PINGPONG  FX: FADE/CUT/WIPE"
//   - Real-time dynamic string generation & single-cycle pixel pipeline
// =============================================================================
module osd_text_overlay (
    input  wire        video_clk,
    input  wire        rst,
    input  wire        hs,
    input  wire        vs,
    input  wire        de,
    input  wire [1:0]  img_idx,          // Current image index (0..3)
    input  wire        auto_play_en,     // 1: Auto slideshow active, 0: Manual
    input  wire [3:0]  vol_level,        // Volume level (0..15)
    input  wire [1:0]  fx_mode,          // 0: Direct Cut, 1: Fade, 2: Venetian/Wipe
    input  wire [3:0]  state_code,       // SD card / SDRAM state code
    input  wire        osd_en,           // 1: OSD visible, 0: hidden
    input  wire [23:0] bg_rgb,           // Background pixel from image/transition engine
    output reg  [23:0] osd_rgb           // Final output pixel with OSD
);

    // Coordinate Counters
    reg        de_d, vs_d;
    reg [9:0]  x_cnt;
    reg [9:0]  y_cnt;
    wire       vs_fall = vs_d & ~vs;

    always @(posedge video_clk or posedge rst) begin
        if (rst) begin
            de_d  <= 1'b0;
            vs_d  <= 1'b0;
            x_cnt <= 10'd0;
            y_cnt <= 10'd0;
        end else begin
            de_d <= de;
            vs_d <= vs;
            if (vs_fall) begin
                x_cnt <= 10'd0;
                y_cnt <= 10'd0;
            end else if (de) begin
                x_cnt <= x_cnt + 10'd1;
            end else if (de_d && !de) begin
                x_cnt <= 10'd0;
                if (y_cnt < 10'd520)
                    y_cnt <= y_cnt + 10'd1;
            end
        end
    end

    // OSD Bounding Box: X in [16, 287], Y in [12, 87]
    localparam [9:0] BOX_X0 = 10'd16;
    localparam [9:0] BOX_X1 = 10'd287;
    localparam [9:0] BOX_Y0 = 10'd12;
    localparam [9:0] BOX_Y1 = 10'd87;

    wire in_box = (x_cnt >= BOX_X0) && (x_cnt <= BOX_X1) &&
                  (y_cnt >= BOX_Y0) && (y_cnt <= BOX_Y1);

    wire is_border = in_box && (
        (x_cnt == BOX_X0) || (x_cnt == BOX_X1) ||
        (y_cnt == BOX_Y0) || (y_cnt == BOX_Y1)
    );

    // Text Lines Configuration (4 lines, each 16 pixels high)
    // Line 0: Y in [16, 31]
    // Line 1: Y in [34, 49]
    // Line 2: Y in [52, 67]
    // Line 3: Y in [70, 85]
    wire in_line0 = (y_cnt >= 10'd16) && (y_cnt <= 10'd31);
    wire in_line1 = (y_cnt >= 10'd34) && (y_cnt <= 10'd49);
    wire in_line2 = (y_cnt >= 10'd52) && (y_cnt <= 10'd67);
    wire in_line3 = (y_cnt >= 10'd70) && (y_cnt <= 10'd85);
    wire in_any_line = in_line0 | in_line1 | in_line2 | in_line3;

    // Character column calculation (each char is 8 pixels wide)
    // Left text margin at X = 24
    wire [9:0] text_x_rel = (x_cnt >= 10'd24) ? (x_cnt - 10'd24) : 10'd0;
    wire [4:0] char_col   = text_x_rel[7:3];   // Character index (0..31)
    wire [2:0] char_x_bit = text_x_rel[2:0];   // 0..7 bit within char
    wire [3:0] char_row =
        in_line0 ? (y_cnt - 10'd16) :
        in_line1 ? (y_cnt - 10'd34) :
        in_line2 ? (y_cnt - 10'd52) :
                   (y_cnt - 10'd70);

    // Dynamic Character Selector based on Line and Column
    reg [7:0] char_code;
    reg [23:0] text_color;

    // Dynamic digit conversions
    wire [7:0] ascii_img_cur = 8'h31 + {6'd0, img_idx}; // '1', '2', '3', '4'

    // Volume percentage (approx = vol_level * 6.6% -> 0..100)
    reg [7:0] ascii_vol_ten, ascii_vol_unit;
    always @(*) begin
        case (vol_level)
            4'd0:  begin ascii_vol_ten = 8'h30; ascii_vol_unit = 8'h30; end // 00%
            4'd1:  begin ascii_vol_ten = 8'h30; ascii_vol_unit = 8'h37; end // 07%
            4'd2:  begin ascii_vol_ten = 8'h31; ascii_vol_unit = 8'h33; end // 13%
            4'd3:  begin ascii_vol_ten = 8'h32; ascii_vol_unit = 8'h30; end // 20%
            4'd4:  begin ascii_vol_ten = 8'h32; ascii_vol_unit = 8'h37; end // 27%
            4'd5:  begin ascii_vol_ten = 8'h33; ascii_vol_unit = 8'h33; end // 33%
            4'd6:  begin ascii_vol_ten = 8'h34; ascii_vol_unit = 8'h30; end // 40%
            4'd7:  begin ascii_vol_ten = 8'h34; ascii_vol_unit = 8'h37; end // 47%
            4'd8:  begin ascii_vol_ten = 8'h35; ascii_vol_unit = 8'h33; end // 53%
            4'd9:  begin ascii_vol_ten = 8'h36; ascii_vol_unit = 8'h30; end // 60%
            4'd10: begin ascii_vol_ten = 8'h36; ascii_vol_unit = 8'h37; end // 67%
            4'd11: begin ascii_vol_ten = 8'h37; ascii_vol_unit = 8'h33; end // 73%
            4'd12: begin ascii_vol_ten = 8'h38; ascii_vol_unit = 8'h30; end // 80%
            4'd13: begin ascii_vol_ten = 8'h38; ascii_vol_unit = 8'h37; end // 87%
            4'd14: begin ascii_vol_ten = 8'h39; ascii_vol_unit = 8'h33; end // 93%
            4'd15: begin ascii_vol_ten = 8'h39; ascii_vol_unit = 8'h39; end // 99%
        endcase
    end

    // Line 0: "EG4S20 HDMI PLAYER" (Length: 18)
    // Line 1: "IMG: 0X/04  AUTO: ON " (Length: 20)
    // Line 2: "VOL: [||||||||  ] XX%" (Length: 21)
    // Line 3: "BUF: PINGPONG  FX: FADE" (Length: 22)
    always @(*) begin
        char_code = 8'h20; // default space
        text_color = 24'hFFFFFF;

        if (in_line0) begin
            text_color = 24'h00FFFF; // Cyan
            case (char_col)
                5'd0:  char_code = "E";
                5'd1:  char_code = "G";
                5'd2:  char_code = "4";
                5'd3:  char_code = "S";
                5'd4:  char_code = "2";
                5'd5:  char_code = "0";
                5'd6:  char_code = " ";
                5'd7:  char_code = "H";
                5'd8:  char_code = "D";
                5'd9:  char_code = "M";
                5'd10: char_code = "I";
                5'd11: char_code = " ";
                5'd12: char_code = "P";
                5'd13: char_code = "L";
                5'd14: char_code = "A";
                5'd15: char_code = "Y";
                5'd16: char_code = "E";
                5'd17: char_code = "R";
                default: char_code = " ";
            endcase
        end else if (in_line1) begin
            text_color = auto_play_en ? 24'h00FF66 : 24'hFFFF00; // Green or Yellow
            case (char_col)
                5'd0:  char_code = "I";
                5'd1:  char_code = "M";
                5'd2:  char_code = "G";
                5'd3:  char_code = ":";
                5'd4:  char_code = " ";
                5'd5:  char_code = "0";
                5'd6:  char_code = ascii_img_cur;
                5'd7:  char_code = "/";
                5'd8:  char_code = "0";
                5'd9:  char_code = "4";
                5'd10: char_code = " ";
                5'd11: char_code = " ";
                5'd12: char_code = "A";
                5'd13: char_code = "U";
                5'd14: char_code = "T";
                5'd15: char_code = "O";
                5'd16: char_code = ":";
                5'd17: char_code = " ";
                5'd18: char_code = auto_play_en ? "O" : "O";
                5'd19: char_code = auto_play_en ? "N" : "F";
                5'd20: char_code = auto_play_en ? " " : "F";
                default: char_code = " ";
            endcase
        end else if (in_line2) begin
            text_color = 24'hFFFFFF; // White
            case (char_col)
                5'd0:  char_code = "V";
                5'd1:  char_code = "O";
                5'd2:  char_code = "L";
                5'd3:  char_code = ":";
                5'd4:  char_code = " ";
                5'd5:  char_code = "[";
                // 10 bar slots (col 6..15)
                5'd6:  char_code = (vol_level >= 4'd1)  ? "|" : " ";
                5'd7:  char_code = (vol_level >= 4'd3)  ? "|" : " ";
                5'd8:  char_code = (vol_level >= 4'd4)  ? "|" : " ";
                5'd9:  char_code = (vol_level >= 4'd6)  ? "|" : " ";
                5'd10: char_code = (vol_level >= 4'd8)  ? "|" : " ";
                5'd11: char_code = (vol_level >= 4'd9)  ? "|" : " ";
                5'd12: char_code = (vol_level >= 4'd11) ? "|" : " ";
                5'd13: char_code = (vol_level >= 4'd12) ? "|" : " ";
                5'd14: char_code = (vol_level >= 4'd14) ? "|" : " ";
                5'd15: char_code = (vol_level >= 4'd15) ? "|" : " ";
                5'd16: char_code = "]";
                5'd17: char_code = " ";
                5'd18: char_code = ascii_vol_ten;
                5'd19: char_code = ascii_vol_unit;
                5'd20: char_code = "%";
                default: char_code = " ";
            endcase
        end else if (in_line3) begin
            text_color = 24'hFFA500; // Gold / Orange
            case (char_col)
                5'd0:  char_code = "B";
                5'd1:  char_code = "U";
                5'd2:  char_code = "F";
                5'd3:  char_code = ":";
                5'd4:  char_code = "2";
                5'd5:  char_code = "X";
                5'd6:  char_code = " ";
                5'd7:  char_code = " ";
                5'd8:  char_code = "F";
                5'd9:  char_code = "X";
                5'd10: char_code = ":";
                5'd11: char_code = " ";
                5'd12: char_code = (fx_mode == 2'd0) ? "C" : (fx_mode == 2'd1) ? "F" : "W";
                5'd13: char_code = (fx_mode == 2'd0) ? "U" : (fx_mode == 2'd1) ? "A" : "I";
                5'd14: char_code = (fx_mode == 2'd0) ? "T" : (fx_mode == 2'd1) ? "D" : "P";
                5'd15: char_code = (fx_mode == 2'd0) ? " " : (fx_mode == 2'd1) ? "E" : "E";
                default: char_code = " ";
            endcase
        end
    end

    // Font ROM lookup
    wire [7:0] font_bits;
    font_rom_8x16 u_font_rom (
        .char_code  (char_code),
        .char_row   (char_row),
        .row_pixels (font_bits)
    );

    // Pixel bit from font (bit 7 is leftmost)
    wire font_pixel = font_bits[3'd7 - char_x_bit];

    // Translucent dark background calculation (50% blend of background)
    wire [23:0] bg_translucent = {
        1'b0, bg_rgb[23:17],
        1'b0, bg_rgb[15:9],
        1'b0, bg_rgb[7:1]
    };

    // Color compositing pipeline
    wire [23:0] border_color = 24'h00D0FF; // Neon Cyan

    always @(posedge video_clk or posedge rst) begin
        if (rst) begin
            osd_rgb <= 24'd0;
        end else if (!de) begin
            osd_rgb <= 24'd0;
        end else if (!osd_en) begin
            osd_rgb <= bg_rgb;
        end else if (is_border) begin
            osd_rgb <= border_color;
        end else if (in_any_line && font_pixel && (x_cnt >= 10'd24) && (x_cnt < 10'd280)) begin
            osd_rgb <= text_color;
        end else if (in_box) begin
            osd_rgb <= bg_translucent;
        end else begin
            osd_rgb <= bg_rgb;
        end
    end

endmodule

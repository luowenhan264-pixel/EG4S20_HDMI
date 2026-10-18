// =============================================================================
// Module: font_rom_8x16
// Description: Synthesizable 8x16 ASCII Font ROM for OSD Subsystem
// Supported characters: '0'-'9', 'A'-'Z', ' ', ':', '/', '[', ']', '|', '-', '%', '.'
// =============================================================================
module font_rom_8x16 (
    input  wire [7:0] char_code,  // ASCII character code (0x20..0x7E)
    input  wire [3:0] char_row,   // Row index within character (0..15)
    output reg  [7:0] row_pixels  // 8 horizontal pixels (bit 7 is leftmost)
);

always @(*) begin
    case (char_code)
        // Space ' ' (0x20)
        8'h20: row_pixels = 8'h00;

        // '%' (0x25)
        8'h25: begin
            case (char_row)
                4'd2:  row_pixels = 8'b01100010;
                4'd3:  row_pixels = 8'b01100100;
                4'd4:  row_pixels = 8'b00001000;
                4'd5:  row_pixels = 8'b00010000;
                4'd6:  row_pixels = 8'b00100000;
                4'd7:  row_pixels = 8'b01000110;
                4'd8:  row_pixels = 8'b10000110;
                default: row_pixels = 8'h00;
            endcase
        end

        // '-' (0x2D)
        8'h2D: begin
            case (char_row)
                4'd7:  row_pixels = 8'b01111110;
                4'd8:  row_pixels = 8'b01111110;
                default: row_pixels = 8'h00;
            endcase
        end

        // '.' (0x2E)
        8'h2E: begin
            case (char_row)
                4'd11: row_pixels = 8'b00011000;
                4'd12: row_pixels = 8'b00011000;
                default: row_pixels = 8'h00;
            endcase
        end

        // '/' (0x2F)
        8'h2F: begin
            case (char_row)
                4'd2:  row_pixels = 8'b00000010;
                4'd3:  row_pixels = 8'b00000100;
                4'd4:  row_pixels = 8'b00001000;
                4'd5:  row_pixels = 8'b00010000;
                4'd6:  row_pixels = 8'b00100000;
                4'd7:  row_pixels = 8'b01000000;
                4'd8:  row_pixels = 8'b10000000;
                default: row_pixels = 8'h00;
            endcase
        end

        // Digits '0' - '9' (0x30 - 0x39)
        8'h30: begin // '0'
            case (char_row)
                4'd2:  row_pixels = 8'b00111100;
                4'd3:  row_pixels = 8'b01100110;
                4'd4:  row_pixels = 8'b01100110;
                4'd5:  row_pixels = 8'b01100110;
                4'd6:  row_pixels = 8'b01100110;
                4'd7:  row_pixels = 8'b01100110;
                4'd8:  row_pixels = 8'b01100110;
                4'd9:  row_pixels = 8'b00111100;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h31: begin // '1'
            case (char_row)
                4'd2:  row_pixels = 8'b00011000;
                4'd3:  row_pixels = 8'b00111000;
                4'd4:  row_pixels = 8'b00011000;
                4'd5:  row_pixels = 8'b00011000;
                4'd6:  row_pixels = 8'b00011000;
                4'd7:  row_pixels = 8'b00011000;
                4'd8:  row_pixels = 8'b00011000;
                4'd9:  row_pixels = 8'b01111110;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h32: begin // '2'
            case (char_row)
                4'd2:  row_pixels = 8'b00111100;
                4'd3:  row_pixels = 8'b01100110;
                4'd4:  row_pixels = 8'b00000110;
                4'd5:  row_pixels = 8'b00001100;
                4'd6:  row_pixels = 8'b00011000;
                4'd7:  row_pixels = 8'b00110000;
                4'd8:  row_pixels = 8'b01100000;
                4'd9:  row_pixels = 8'b01111110;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h33: begin // '3'
            case (char_row)
                4'd2:  row_pixels = 8'b00111100;
                4'd3:  row_pixels = 8'b01100110;
                4'd4:  row_pixels = 8'b00000110;
                4'd5:  row_pixels = 8'b00011100;
                4'd6:  row_pixels = 8'b00000110;
                4'd7:  row_pixels = 8'b00000110;
                4'd8:  row_pixels = 8'b01100110;
                4'd9:  row_pixels = 8'b00111100;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h34: begin // '4'
            case (char_row)
                4'd2:  row_pixels = 8'b00001100;
                4'd3:  row_pixels = 8'b00011100;
                4'd4:  row_pixels = 8'b00101100;
                4'd5:  row_pixels = 8'b01001100;
                4'd6:  row_pixels = 8'b01111110;
                4'd7:  row_pixels = 8'b00001100;
                4'd8:  row_pixels = 8'b00001100;
                4'd9:  row_pixels = 8'b00001100;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h35: begin // '5'
            case (char_row)
                4'd2:  row_pixels = 8'b01111110;
                4'd3:  row_pixels = 8'b01100000;
                4'd4:  row_pixels = 8'b01111100;
                4'd5:  row_pixels = 8'b00000110;
                4'd6:  row_pixels = 8'b00000110;
                4'd7:  row_pixels = 8'b00000110;
                4'd8:  row_pixels = 8'b01100110;
                4'd9:  row_pixels = 8'b00111100;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h36: begin // '6'
            case (char_row)
                4'd2:  row_pixels = 8'b00111100;
                4'd3:  row_pixels = 8'b01100000;
                4'd4:  row_pixels = 8'b01100000;
                4'd5:  row_pixels = 8'b01111100;
                4'd6:  row_pixels = 8'b01100110;
                4'd7:  row_pixels = 8'b01100110;
                4'd8:  row_pixels = 8'b01100110;
                4'd9:  row_pixels = 8'b00111100;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h37: begin // '7'
            case (char_row)
                4'd2:  row_pixels = 8'b01111110;
                4'd3:  row_pixels = 8'b00000110;
                4'd4:  row_pixels = 8'b00001100;
                4'd5:  row_pixels = 8'b00011000;
                4'd6:  row_pixels = 8'b00110000;
                4'd7:  row_pixels = 8'b00110000;
                4'd8:  row_pixels = 8'b00110000;
                4'd9:  row_pixels = 8'b00110000;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h38: begin // '8'
            case (char_row)
                4'd2:  row_pixels = 8'b00111100;
                4'd3:  row_pixels = 8'b01100110;
                4'd4:  row_pixels = 8'b01100110;
                4'd5:  row_pixels = 8'b00111100;
                4'd6:  row_pixels = 8'b01100110;
                4'd7:  row_pixels = 8'b01100110;
                4'd8:  row_pixels = 8'b01100110;
                4'd9:  row_pixels = 8'b00111100;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h39: begin // '9'
            case (char_row)
                4'd2:  row_pixels = 8'b00111100;
                4'd3:  row_pixels = 8'b01100110;
                4'd4:  row_pixels = 8'b01100110;
                4'd5:  row_pixels = 8'b01100110;
                4'd6:  row_pixels = 8'b00111110;
                4'd7:  row_pixels = 8'b00000110;
                4'd8:  row_pixels = 8'b00000110;
                4'd9:  row_pixels = 8'b00111100;
                default: row_pixels = 8'h00;
            endcase
        end

        // ':' (0x3A)
        8'h3A: begin
            case (char_row)
                4'd4:  row_pixels = 8'b00011000;
                4'd5:  row_pixels = 8'b00011000;
                4'd7:  row_pixels = 8'b00011000;
                4'd8:  row_pixels = 8'b00011000;
                default: row_pixels = 8'h00;
            endcase
        end

        // Letters 'A' - 'Z' (0x41 - 0x5A)
        8'h41: begin // 'A'
            case (char_row)
                4'd2:  row_pixels = 8'b00111100;
                4'd3:  row_pixels = 8'b01100110;
                4'd4:  row_pixels = 8'b01100110;
                4'd5:  row_pixels = 8'b01111110;
                4'd6:  row_pixels = 8'b01100110;
                4'd7:  row_pixels = 8'b01100110;
                4'd8:  row_pixels = 8'b01100110;
                4'd9:  row_pixels = 8'b01100110;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h42: begin // 'B'
            case (char_row)
                4'd2:  row_pixels = 8'b01111100;
                4'd3:  row_pixels = 8'b01100110;
                4'd4:  row_pixels = 8'b01100110;
                4'd5:  row_pixels = 8'b01111100;
                4'd6:  row_pixels = 8'b01100110;
                4'd7:  row_pixels = 8'b01100110;
                4'd8:  row_pixels = 8'b01100110;
                4'd9:  row_pixels = 8'b01111100;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h43: begin // 'C'
            case (char_row)
                4'd2:  row_pixels = 8'b00111100;
                4'd3:  row_pixels = 8'b01100110;
                4'd4:  row_pixels = 8'b01100000;
                4'd5:  row_pixels = 8'b01100000;
                4'd6:  row_pixels = 8'b01100000;
                4'd7:  row_pixels = 8'b01100000;
                4'd8:  row_pixels = 8'b01100110;
                4'd9:  row_pixels = 8'b00111100;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h44: begin // 'D'
            case (char_row)
                4'd2:  row_pixels = 8'b01111000;
                4'd3:  row_pixels = 8'b01101100;
                4'd4:  row_pixels = 8'b01100110;
                4'd5:  row_pixels = 8'b01100110;
                4'd6:  row_pixels = 8'b01100110;
                4'd7:  row_pixels = 8'b01100110;
                4'd8:  row_pixels = 8'b01101100;
                4'd9:  row_pixels = 8'b01111000;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h45: begin // 'E'
            case (char_row)
                4'd2:  row_pixels = 8'b01111110;
                4'd3:  row_pixels = 8'b01100000;
                4'd4:  row_pixels = 8'b01100000;
                4'd5:  row_pixels = 8'b01111100;
                4'd6:  row_pixels = 8'b01100000;
                4'd7:  row_pixels = 8'b01100000;
                4'd8:  row_pixels = 8'b01100000;
                4'd9:  row_pixels = 8'b01111110;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h46: begin // 'F'
            case (char_row)
                4'd2:  row_pixels = 8'b01111110;
                4'd3:  row_pixels = 8'b01100000;
                4'd4:  row_pixels = 8'b01100000;
                4'd5:  row_pixels = 8'b01111100;
                4'd6:  row_pixels = 8'b01100000;
                4'd7:  row_pixels = 8'b01100000;
                4'd8:  row_pixels = 8'b01100000;
                4'd9:  row_pixels = 8'b01100000;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h47: begin // 'G'
            case (char_row)
                4'd2:  row_pixels = 8'b00111100;
                4'd3:  row_pixels = 8'b01100110;
                4'd4:  row_pixels = 8'b01100000;
                4'd5:  row_pixels = 8'b01101110;
                4'd6:  row_pixels = 8'b01100110;
                4'd7:  row_pixels = 8'b01100110;
                4'd8:  row_pixels = 8'b01100110;
                4'd9:  row_pixels = 8'b00111100;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h48: begin // 'H'
            case (char_row)
                4'd2:  row_pixels = 8'b01100110;
                4'd3:  row_pixels = 8'b01100110;
                4'd4:  row_pixels = 8'b01100110;
                4'd5:  row_pixels = 8'b01111110;
                4'd6:  row_pixels = 8'b01100110;
                4'd7:  row_pixels = 8'b01100110;
                4'd8:  row_pixels = 8'b01100110;
                4'd9:  row_pixels = 8'b01100110;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h49: begin // 'I'
            case (char_row)
                4'd2:  row_pixels = 8'b01111110;
                4'd3:  row_pixels = 8'b00011000;
                4'd4:  row_pixels = 8'b00011000;
                4'd5:  row_pixels = 8'b00011000;
                4'd6:  row_pixels = 8'b00011000;
                4'd7:  row_pixels = 8'b00011000;
                4'd8:  row_pixels = 8'b00011000;
                4'd9:  row_pixels = 8'b01111110;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h4B: begin // 'K'
            case (char_row)
                4'd2:  row_pixels = 8'b01100110;
                4'd3:  row_pixels = 8'b01101100;
                4'd4:  row_pixels = 8'b01111000;
                4'd5:  row_pixels = 8'b01110000;
                4'd6:  row_pixels = 8'b01111000;
                4'd7:  row_pixels = 8'b01101100;
                4'd8:  row_pixels = 8'b01100110;
                4'd9:  row_pixels = 8'b01100011;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h4C: begin // 'L'
            case (char_row)
                4'd2:  row_pixels = 8'b01100000;
                4'd3:  row_pixels = 8'b01100000;
                4'd4:  row_pixels = 8'b01100000;
                4'd5:  row_pixels = 8'b01100000;
                4'd6:  row_pixels = 8'b01100000;
                4'd7:  row_pixels = 8'b01100000;
                4'd8:  row_pixels = 8'b01100000;
                4'd9:  row_pixels = 8'b01111110;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h4D: begin // 'M'
            case (char_row)
                4'd2:  row_pixels = 8'b01100011;
                4'd3:  row_pixels = 8'b01110111;
                4'd4:  row_pixels = 8'b01111111;
                4'd5:  row_pixels = 8'b01101011;
                4'd6:  row_pixels = 8'b01100011;
                4'd7:  row_pixels = 8'b01100011;
                4'd8:  row_pixels = 8'b01100011;
                4'd9:  row_pixels = 8'b01100011;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h4E: begin // 'N'
            case (char_row)
                4'd2:  row_pixels = 8'b01100011;
                4'd3:  row_pixels = 8'b01110011;
                4'd4:  row_pixels = 8'b01111011;
                4'd5:  row_pixels = 8'b01101111;
                4'd6:  row_pixels = 8'b01100111;
                4'd7:  row_pixels = 8'b01100011;
                4'd8:  row_pixels = 8'b01100011;
                4'd9:  row_pixels = 8'b01100011;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h4F: begin // 'O'
            case (char_row)
                4'd2:  row_pixels = 8'b00111100;
                4'd3:  row_pixels = 8'b01100110;
                4'd4:  row_pixels = 8'b01100110;
                4'd5:  row_pixels = 8'b01100110;
                4'd6:  row_pixels = 8'b01100110;
                4'd7:  row_pixels = 8'b01100110;
                4'd8:  row_pixels = 8'b01100110;
                4'd9:  row_pixels = 8'b00111100;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h50: begin // 'P'
            case (char_row)
                4'd2:  row_pixels = 8'b01111100;
                4'd3:  row_pixels = 8'b01100110;
                4'd4:  row_pixels = 8'b01100110;
                4'd5:  row_pixels = 8'b01111100;
                4'd6:  row_pixels = 8'b01100000;
                4'd7:  row_pixels = 8'b01100000;
                4'd8:  row_pixels = 8'b01100000;
                4'd9:  row_pixels = 8'b01100000;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h52: begin // 'R'
            case (char_row)
                4'd2:  row_pixels = 8'b01111100;
                4'd3:  row_pixels = 8'b01100110;
                4'd4:  row_pixels = 8'b01100110;
                4'd5:  row_pixels = 8'b01111100;
                4'd6:  row_pixels = 8'b01101100;
                4'd7:  row_pixels = 8'b01100110;
                4'd8:  row_pixels = 8'b01100110;
                4'd9:  row_pixels = 8'b01100011;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h53: begin // 'S'
            case (char_row)
                4'd2:  row_pixels = 8'b00111100;
                4'd3:  row_pixels = 8'b01100110;
                4'd4:  row_pixels = 8'b01100000;
                4'd5:  row_pixels = 8'b00111100;
                4'd6:  row_pixels = 8'b00000110;
                4'd7:  row_pixels = 8'b00000110;
                4'd8:  row_pixels = 8'b01100110;
                4'd9:  row_pixels = 8'b00111100;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h54: begin // 'T'
            case (char_row)
                4'd2:  row_pixels = 8'b01111110;
                4'd3:  row_pixels = 8'b00011000;
                4'd4:  row_pixels = 8'b00011000;
                4'd5:  row_pixels = 8'b00011000;
                4'd6:  row_pixels = 8'b00011000;
                4'd7:  row_pixels = 8'b00011000;
                4'd8:  row_pixels = 8'b00011000;
                4'd9:  row_pixels = 8'b00011000;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h55: begin // 'U'
            case (char_row)
                4'd2:  row_pixels = 8'b01100110;
                4'd3:  row_pixels = 8'b01100110;
                4'd4:  row_pixels = 8'b01100110;
                4'd5:  row_pixels = 8'b01100110;
                4'd6:  row_pixels = 8'b01100110;
                4'd7:  row_pixels = 8'b01100110;
                4'd8:  row_pixels = 8'b01100110;
                4'd9:  row_pixels = 8'b00111100;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h56: begin // 'V'
            case (char_row)
                4'd2:  row_pixels = 8'b01100110;
                4'd3:  row_pixels = 8'b01100110;
                4'd4:  row_pixels = 8'b01100110;
                4'd5:  row_pixels = 8'b01100110;
                4'd6:  row_pixels = 8'b01100110;
                4'd7:  row_pixels = 8'b00111100;
                4'd8:  row_pixels = 8'b00111100;
                4'd9:  row_pixels = 8'b00011000;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h57: begin // 'W'
            case (char_row)
                4'd2:  row_pixels = 8'b01100011;
                4'd3:  row_pixels = 8'b01100011;
                4'd4:  row_pixels = 8'b01100011;
                4'd5:  row_pixels = 8'b01100011;
                4'd6:  row_pixels = 8'b01101011;
                4'd7:  row_pixels = 8'b01111111;
                4'd8:  row_pixels = 8'b01110111;
                4'd9:  row_pixels = 8'b00110011;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h58: begin // 'X'
            case (char_row)
                4'd2:  row_pixels = 8'b01100110;
                4'd3:  row_pixels = 8'b01100110;
                4'd4:  row_pixels = 8'b00111100;
                4'd5:  row_pixels = 8'b00011000;
                4'd6:  row_pixels = 8'b00111100;
                4'd7:  row_pixels = 8'b01100110;
                4'd8:  row_pixels = 8'b01100110;
                4'd9:  row_pixels = 8'b01100110;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h59: begin // 'Y'
            case (char_row)
                4'd2:  row_pixels = 8'b01100110;
                4'd3:  row_pixels = 8'b01100110;
                4'd4:  row_pixels = 8'b00111100;
                4'd5:  row_pixels = 8'b00011000;
                4'd6:  row_pixels = 8'b00011000;
                4'd7:  row_pixels = 8'b00011000;
                4'd8:  row_pixels = 8'b00011000;
                4'd9:  row_pixels = 8'b00011000;
                default: row_pixels = 8'h00;
            endcase
        end
        8'h5A: begin // 'Z'
            case (char_row)
                4'd2:  row_pixels = 8'b01111110;
                4'd3:  row_pixels = 8'b00000110;
                4'd4:  row_pixels = 8'b00001100;
                4'd5:  row_pixels = 8'b00011000;
                4'd6:  row_pixels = 8'b00110000;
                4'd7:  row_pixels = 8'b01100000;
                4'd8:  row_pixels = 8'b01100000;
                4'd9:  row_pixels = 8'b01111110;
                default: row_pixels = 8'h00;
            endcase
        end

        // '[' (0x5B)
        8'h5B: begin
            case (char_row)
                4'd2:  row_pixels = 8'b00111100;
                4'd3:  row_pixels = 8'b00110000;
                4'd4:  row_pixels = 8'b00110000;
                4'd5:  row_pixels = 8'b00110000;
                4'd6:  row_pixels = 8'b00110000;
                4'd7:  row_pixels = 8'b00110000;
                4'd8:  row_pixels = 8'b00110000;
                4'd9:  row_pixels = 8'b00111100;
                default: row_pixels = 8'h00;
            endcase
        end

        // ']' (0x5D)
        8'h5D: begin
            case (char_row)
                4'd2:  row_pixels = 8'b00111100;
                4'd3:  row_pixels = 8'b00001100;
                4'd4:  row_pixels = 8'b00001100;
                4'd5:  row_pixels = 8'b00001100;
                4'd6:  row_pixels = 8'b00001100;
                4'd7:  row_pixels = 8'b00001100;
                4'd8:  row_pixels = 8'b00001100;
                4'd9:  row_pixels = 8'b00111100;
                default: row_pixels = 8'h00;
            endcase
        end

        // '|' (0x7C)
        8'h7C: begin
            case (char_row)
                4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd7, 4'd8, 4'd9: row_pixels = 8'b00011000;
                default: row_pixels = 8'h00;
            endcase
        end

        default: row_pixels = 8'h00;
    endcase
end

endmodule

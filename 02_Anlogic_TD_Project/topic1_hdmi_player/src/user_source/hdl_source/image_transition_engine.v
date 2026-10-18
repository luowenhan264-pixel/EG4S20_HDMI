// =============================================================================
// Module: image_transition_engine
// Description: Real-time FPGA Hardware Video Transition Engine
// Modes:
//   2'b00: Direct Cut (Instantaneous Buffer Switch)
//   2'b01: Cinematic Fade-to-Black & Fade-In (Smooth 48-frame Alpha ramp)
//   2'b10: Venetian Blinds / Curtain Wipe Effect (Hardware scanline mask)
// =============================================================================
module image_transition_engine (
    input  wire        video_clk,
    input  wire        rst,
    input  wire        vs,
    input  wire        hs,
    input  wire        de,
    input  wire [1:0]  fx_mode,          // 0: CUT, 1: FADE, 2: BLINDS
    input  wire [1:0]  target_buf_idx,   // Desired display buffer index from playlist
    output reg  [1:0]  active_buf_idx,   // Currently active buffer index fed to SDRAM
    output reg         in_transition,    // High when transition is actively executing
    input  wire [23:0] raw_rgb,          // Raw 24-bit RGB from SDRAM frame buffer
    output reg         vs_out,
    output reg         hs_out,
    output reg         de_out,
    output reg  [23:0] fx_rgb            // Processed 24-bit RGB with transition applied
);

    // Vsync Edge Detector & Active Frame End Detector
    reg vs_d;
    wire vs_fall = vs_d & ~vs;

    // Line and Column Coordinates
    reg [9:0] x_cnt, y_cnt;
    reg de_d;

    // Advance transition state right after the last active line (line 479),
    // which is 10 lines (8,000 cycles) BEFORE video_vs falls and latches active_buf_idx in SDRAM reader
    wire frame_end_tick = (de_d && !de && (y_cnt == 10'd479));

    always @(posedge video_clk or posedge rst) begin
        if (rst) begin
            vs_d  <= 1'b0;
            de_d  <= 1'b0;
            x_cnt <= 10'd0;
            y_cnt <= 10'd0;
        end else begin
            vs_d <= vs;
            de_d <= de;
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

    // Transition State Machine
    localparam [2:0] S_IDLE       = 3'd0;
    localparam [2:0] S_FADE_OUT   = 3'd1;
    localparam [2:0] S_SWAP       = 3'd2;
    localparam [2:0] S_FADE_IN    = 3'd3;
    localparam [2:0] S_BLIND_RUN  = 3'd4;

    reg [2:0] state;
    reg [7:0] alpha;             // 0..255 brightness scaling factor
    reg [5:0] frame_cnt;         // Frame countdown counter
    reg [1:0] pending_buf_idx;
    reg [4:0] blind_width;       // 0..16 pixel stripe width

    // Frame-level State Machine updated at End of Active Frame (before next Vsync read_req)
    always @(posedge video_clk or posedge rst) begin
        if (rst) begin
            state           <= S_IDLE;
            active_buf_idx  <= 2'd0;
            pending_buf_idx <= 2'd0;
            alpha           <= 8'd255;
            frame_cnt       <= 6'd0;
            blind_width     <= 5'd0;
            in_transition   <= 1'b0;
        end else if (frame_end_tick) begin
            case (state)
                S_IDLE: begin
                    alpha         <= 8'd255;
                    blind_width   <= 5'd0;
                    in_transition <= 1'b0;

                    // Trigger transition when target buffer changes
                    if (target_buf_idx != active_buf_idx) begin
                        pending_buf_idx <= target_buf_idx;
                        in_transition   <= 1'b1;

                        case (fx_mode)
                            2'b00: begin // Direct Cut
                                active_buf_idx <= target_buf_idx;
                                state          <= S_IDLE;
                                in_transition  <= 1'b0;
                            end

                            2'b01: begin // Fade to Black
                                state     <= S_FADE_OUT;
                                frame_cnt <= 6'd24; // 24 frames fade-out (~0.4s)
                                alpha     <= 8'd255;
                            end

                            2'b10: begin // Venetian Blinds
                                state       <= S_BLIND_RUN;
                                frame_cnt   <= 6'd32;
                                blind_width <= 5'd0;
                            end

                            default: begin
                                active_buf_idx <= target_buf_idx;
                                state          <= S_IDLE;
                                in_transition  <= 1'b0;
                            end
                        endcase
                    end
                end

                S_FADE_OUT: begin
                    // Alpha linearly ramps from 255 down to ~0
                    if (frame_cnt > 6'd0) begin
                        frame_cnt <= frame_cnt - 6'd1;
                        if (alpha >= 8'd10)
                            alpha <= alpha - 8'd10;
                        else
                            alpha <= 8'd0;
                    end else begin
                        state <= S_SWAP;
                        alpha <= 8'd0;
                    end
                end

                S_SWAP: begin
                    // Switch the buffer while completely black
                    active_buf_idx <= pending_buf_idx;
                    state          <= S_FADE_IN;
                    frame_cnt      <= 6'd24; // 24 frames fade-in (~0.4s)
                    alpha          <= 8'd0;
                end

                S_FADE_IN: begin
                    // Alpha linearly ramps from 0 up to 255
                    if (frame_cnt > 6'd0) begin
                        frame_cnt <= frame_cnt - 6'd1;
                        if (alpha <= 8'd245)
                            alpha <= alpha + 8'd10;
                        else
                            alpha <= 8'd255;
                    end else begin
                        alpha <= 8'd255;
                        state <= S_IDLE;
                        in_transition <= 1'b0;
                    end
                end

                S_BLIND_RUN: begin
                    // Venetian blinds: curtain strips open up
                    if (frame_cnt > 6'd16) begin
                        // Phase 1: closing blinds (increasing dark stripes)
                        frame_cnt   <= frame_cnt - 6'd1;
                        blind_width <= blind_width + 5'd1;
                    end else if (frame_cnt == 6'd16) begin
                        // Midpoint: switch buffer
                        active_buf_idx <= pending_buf_idx;
                        frame_cnt      <= frame_cnt - 6'd1;
                        blind_width    <= 5'd16;
                    end else if (frame_cnt > 6'd0) begin
                        // Phase 2: opening blinds revealing new image
                        frame_cnt   <= frame_cnt - 6'd1;
                        blind_width <= blind_width - 5'd1;
                    end else begin
                        blind_width   <= 5'd0;
                        state         <= S_IDLE;
                        in_transition <= 1'b0;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // Pixel Processing Pipeline
    // 1. Fade calculation: (raw * alpha) >> 8
    wire [15:0] r_mult = raw_rgb[23:16] * alpha;
    wire [15:0] g_mult = raw_rgb[15:8]  * alpha;
    wire [15:0] b_mult = raw_rgb[7:0]   * alpha;

    wire [23:0] fade_pixel = {r_mult[15:8], g_mult[15:8], b_mult[15:8]};

    // 2. Venetian Blinds Mask calculation:
    // Stripes repeat every 32 lines. If line within stripe < blind_width: darken or black
    wire [4:0] stripe_y = y_cnt[4:0];
    wire is_blind_mask = (stripe_y < blind_width);

    always @(posedge video_clk or posedge rst) begin
        if (rst) begin
            vs_out <= 1'b0;
            hs_out <= 1'b0;
            de_out <= 1'b0;
            fx_rgb <= 24'd0;
        end else begin
            vs_out <= vs;
            hs_out <= hs;
            de_out <= de;
            if (!de) begin
                fx_rgb <= 24'd0;
            end else begin
                case (state)
                    S_IDLE: begin
                        fx_rgb <= raw_rgb;
                    end

                    S_FADE_OUT, S_SWAP, S_FADE_IN: begin
                        fx_rgb <= fade_pixel;
                    end

                    S_BLIND_RUN: begin
                        if (is_blind_mask)
                            fx_rgb <= 24'h000000;
                        else
                            fx_rgb <= raw_rgb;
                    end

                    default: fx_rgb <= raw_rgb;
                endcase
            end
        end
    end

endmodule

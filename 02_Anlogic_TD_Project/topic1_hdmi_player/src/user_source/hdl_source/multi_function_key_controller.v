// =============================================================================
// Module: multi_function_key_controller
// Description: Multi-function key controller with hardware debounce and short/long press detection
// Mapping:
//   - KEY1 Short Press (<1s): Switch to Next Image
//   - KEY1 Long Press  (>=1s): Cycle Transition Effect (Direct -> Fade -> Blinds)
//   - KEY2 Short Press (<1s): Toggle Auto Slideshow (ON / OFF)
//   - KEY2 Long Press  (>=1s): Toggle OSD Overlay Visibility (ON / OFF)
// =============================================================================
module multi_function_key_controller #(
    parameter CLK_FREQ_HZ = 50_000_000
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        key1_raw,        // Board KEY1 (B2)
    input  wire        key2_raw,        // Board KEY2 (C1)

    output reg         next_img_trig,   // Single-cycle pulse for next image
    output reg  [1:0]  fx_mode,         // 0: CUT, 1: FADE, 2: BLINDS
    output reg         auto_play_trig,  // Toggle pulse for auto slideshow
    output reg         osd_toggle_trig, // Toggle pulse for OSD
    output reg  [3:0]  vol_level        // Volume level (0..15)
);

    localparam DEBOUNCE_TICKS = CLK_FREQ_HZ / 50;  // 20 ms
    localparam LONG_PRESS_TICKS = CLK_FREQ_HZ;     // 1.0 s

    // -------------------------------------------------------------------------
    // KEY 1 Debounce & Press Timer
    // -------------------------------------------------------------------------
    reg [1:0]  k1_sync;
    reg [21:0] k1_debounce_cnt;
    reg        k1_stable;
    reg [25:0] k1_press_cnt;
    reg        k1_long_fired;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            k1_sync         <= 2'b11;
            k1_debounce_cnt <= 22'd0;
            k1_stable       <= 1'b1;
            k1_press_cnt    <= 26'd0;
            k1_long_fired   <= 1'b0;
            next_img_trig   <= 1'b0;
            fx_mode         <= 2'b01; // Default: Cinematic Fade Mode
        end else begin
            next_img_trig <= 1'b0;
            k1_sync <= {k1_sync[0], key1_raw};

            // 20ms Debounce Filter
            if (k1_sync[1] != k1_stable) begin
                k1_debounce_cnt <= k1_debounce_cnt + 22'd1;
                if (k1_debounce_cnt >= DEBOUNCE_TICKS) begin
                    k1_stable       <= k1_sync[1];
                    k1_debounce_cnt <= 22'd0;
                end
            end else begin
                k1_debounce_cnt <= 22'd0;
            end

            // Short / Long Press Detection (Active Low when pressed)
            if (!k1_stable) begin
                if (k1_press_cnt < LONG_PRESS_TICKS) begin
                    k1_press_cnt <= k1_press_cnt + 26'd1;
                end else if (!k1_long_fired) begin
                    // Long press fired at 1.0s threshold: cycle transition mode
                    k1_long_fired <= 1'b1;
                    if (fx_mode == 2'd2)
                        fx_mode <= 2'd0;
                    else
                        fx_mode <= fx_mode + 2'd1;
                end
            end else begin
                // Released: Check if it was a short press
                if (k1_press_cnt > 26'd500_000 && !k1_long_fired) begin
                    next_img_trig <= 1'b1; // Trigger next image
                end
                k1_press_cnt  <= 26'd0;
                k1_long_fired <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // KEY 2 Debounce & Press Timer
    // -------------------------------------------------------------------------
    reg [1:0]  k2_sync;
    reg [21:0] k2_debounce_cnt;
    reg        k2_stable;
    reg [25:0] k2_press_cnt;
    reg        k2_long_fired;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            k2_sync         <= 2'b11;
            k2_debounce_cnt <= 22'd0;
            k2_stable       <= 1'b1;
            k2_press_cnt    <= 26'd0;
            k2_long_fired   <= 1'b0;
            auto_play_trig  <= 1'b0;
            osd_toggle_trig <= 1'b0;
            vol_level       <= 4'd12; // Default 80% volume
        end else begin
            auto_play_trig  <= 1'b0;
            osd_toggle_trig <= 1'b0;
            k2_sync <= {k2_sync[0], key2_raw};

            if (k2_sync[1] != k2_stable) begin
                k2_debounce_cnt <= k2_debounce_cnt + 22'd1;
                if (k2_debounce_cnt >= DEBOUNCE_TICKS) begin
                    k2_stable       <= k2_sync[1];
                    k2_debounce_cnt <= 22'd0;
                end
            end else begin
                k2_debounce_cnt <= 22'd0;
            end

            if (!k2_stable) begin
                if (k2_press_cnt < LONG_PRESS_TICKS) begin
                    k2_press_cnt <= k2_press_cnt + 26'd1;
                end else if (!k2_long_fired) begin
                    // Long press fired: toggle OSD visibility
                    k2_long_fired   <= 1'b1;
                    osd_toggle_trig <= 1'b1;
                end
            end else begin
                // Released: Short press toggles auto slideshow
                if (k2_press_cnt > 26'd500_000 && !k2_long_fired) begin
                    auto_play_trig <= 1'b1;
                end
                k2_press_cnt  <= 26'd0;
                k2_long_fired <= 1'b0;
            end
        end
    end

endmodule

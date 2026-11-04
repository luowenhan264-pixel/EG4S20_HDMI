// Bounded raw-sector discovery, NOT a FAT reader. BMP files must be contiguous.
module sd_card_bmp #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter [2:0] IMG_COUNT = 4,
    parameter USE_FIXED_SECTORS = 0,
    parameter [31:0] SCAN_MAX_SECTOR = 131071,
    parameter [31:0] IMG_SECTOR0 = 0, IMG_SECTOR1 = 2048,
    parameter [31:0] IMG_SECTOR2 = 4096, IMG_SECTOR3 = 6144,
    parameter [31:0] AUTO_PERIOD_MS = 2000,
    parameter integer IO_TIMEOUT_MS = 3000,
    parameter EXTERNAL_CONTROL = 0,
    parameter SCALE_ENABLE = 0,
    parameter PREV_ENABLE = 0
)(
    input clk, rst, key_next, key_auto,
    output [3:0] state_code,
    input [15:0] bmp_width, bmp_height,
    output reg display_valid,
    output reg [1:0] img_idx,
    output reg auto_play_en,
    input write_finish_toggle,
    output reg [1:0] write_buf_idx, disp_buf_idx,
    output reg display_req_toggle,
    input display_ack_toggle,
    output write_req,
    input write_req_ack,
    output write_en,
    output [31:0] write_data,
    output SD_nCS, SD_DCLK, SD_MOSI,
    input SD_MISO,
    input control_next, control_auto, control_pause,
    input [31:0] control_period_ms,
    input write_ready, input control_prev, output navigation_ready
);
localparam INIT=0, SCAN=1, START_LOAD=2, LOADING=3, COMMIT=4, IDLE=5, ERROR=6, EMPTY=7;
localparam integer MS_CYCLES = (CLK_FREQ_HZ < 1000) ? 1 : CLK_FREQ_HZ/1000;
localparam [31:0] PERIOD = (AUTO_PERIOD_MS == 0) ? 1 : AUTO_PERIOD_MS;
localparam [2:0] TARGET = (IMG_COUNT < 1) ? 1 : ((IMG_COUNT > 4) ? 4 : IMG_COUNT);
reg [2:0] state;
assign navigation_ready=state==IDLE || state==ERROR || state==EMPTY;
reg [31:0] sectors [0:3];
reg [2:0] found_count;
reg [1:0] load_idx;
reg scan_start, load_start, load_abort;
reg [31:0] load_sector;
reg next_pending, prev_pending, source_done, memory_done;
wire prev_press=PREV_ENABLE ? control_prev : 1'b0;
reg [31:0] ms_div, elapsed_ms, idle_ms;
reg [4:0] reset_hold;
reg [2:0] finish_sync, commit_sync;
wire tick_ms = ms_div == MS_CYCLES-1;
wire finish_pulse = finish_sync[2] ^ finish_sync[1];
wire transport_rst = rst | (reset_hold != 0);
wire key_next_press, key_auto_press, legacy_next_press, legacy_auto_press;
wire pause_auto = EXTERNAL_CONTROL ? control_pause : 1'b0;
wire [31:0] effective_period = EXTERNAL_CONTROL ?
    (control_period_ms==0 ? 32'd1 : control_period_ms) : PERIOD;
reg [31:0] previous_period;
wire period_changed=effective_period!=previous_period;
assign key_next_press=EXTERNAL_CONTROL ? control_next : legacy_next_press;
assign key_auto_press=EXTERNAL_CONTROL ? control_auto : legacy_auto_press;
wire sd_init_done, bmp_ready, scan_done, found_valid, load_done, load_error;
wire [31:0] found_sector;
wire [2:0] found_total;
wire [3:0] reader_state;
wire sec_read, sec_valid, sec_end;
wire [31:0] sec_addr;
wire [7:0] sec_data;
wire [23:0] pixel;
wire [1:0] next_idx = ({1'b0,img_idx}+3'd1 >= found_count) ? 2'd0 : img_idx+2'd1;
wire [1:0] prev_idx = img_idx==0 ? found_count-1'b1 : img_idx-1'b1;
assign write_data = {pixel,8'b0};
assign state_code = (state==ERROR) ? 4'he : (state==EMPTY) ? 4'hf :
                    (state==COMMIT) ? 4'd5 : (state==INIT) ? 4'd0 : reader_state;

key_press_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .DEBOUNCE_MS(50))
    next_key(clk, rst, key_next, legacy_next_press),
    auto_key(clk, rst, key_auto, legacy_auto_press);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state<=INIT; scan_start<=0; load_start<=0; load_abort<=0;
        found_count<=0; load_idx<=0; load_sector<=0;
        sectors[0]<=0; sectors[1]<=0; sectors[2]<=0; sectors[3]<=0;
        display_valid<=0; img_idx<=0; auto_play_en<=0;
        write_buf_idx<=0; disp_buf_idx<=0; display_req_toggle<=0;
        finish_sync<=0; commit_sync<=0; source_done<=0; memory_done<=0;
        ms_div<=0; elapsed_ms<=0; idle_ms<=0; reset_hold<=0; next_pending<=0; prev_pending<=0;
        previous_period<=PERIOD;
    end else begin
        finish_sync <= {finish_sync[1:0],write_finish_toggle};
        commit_sync <= {commit_sync[1:0],display_ack_toggle};
        scan_start<=0; load_start<=0; load_abort<=0;
        if (reset_hold != 0) reset_hold<=reset_hold-1'b1;
        if (tick_ms) ms_div<=0; else ms_div<=ms_div+1'b1;
        if (key_next_press && state!=ERROR && state!=EMPTY) begin next_pending<=1;prev_pending<=0;end
        if(prev_press && state!=ERROR && state!=EMPTY)begin prev_pending<=1;next_pending<=0;end
        if (key_auto_press && found_count>1) auto_play_en<=~auto_play_en;
        previous_period<=effective_period;
        if (state!=IDLE || !auto_play_en || key_auto_press || pause_auto || period_changed) elapsed_ms<=0;
        else if (tick_ms && elapsed_ms<effective_period) elapsed_ms<=elapsed_ms+1'b1;
        // Progress watchdog: scanning duration is unbounded, stalled I/O is not.
        if (sec_valid || sec_end || finish_pulse || write_en ||
            (state!=INIT && state!=SCAN && state!=LOADING)) idle_ms<=0;
        else if (tick_ms && idle_ms<IO_TIMEOUT_MS) idle_ms<=idle_ms+1'b1;
        case (state)
        INIT: if (sd_init_done && reset_hold==0 && bmp_ready) begin
            load_idx<=0; next_pending<=0; prev_pending<=0;
            if (USE_FIXED_SECTORS) begin
                sectors[0]<=IMG_SECTOR0; sectors[1]<=IMG_SECTOR1;
                sectors[2]<=IMG_SECTOR2; sectors[3]<=IMG_SECTOR3;
                found_count<=TARGET; state<=START_LOAD;
            end else begin
                found_count<=0; scan_start<=1; state<=SCAN;
            end
        end
        SCAN: begin
            if (found_valid && found_total>=1 && found_total<=4)
                sectors[found_total-1'b1]<=found_sector;
            if (scan_done && !scan_start) begin
                found_count<=found_total;
                if (found_total==0) state<=EMPTY; else state<=START_LOAD;
            end
        end
        START_LOAD: if (bmp_ready) begin
            load_sector<=sectors[load_idx];
            write_buf_idx<=display_valid ? (disp_buf_idx ^ 2'd1) : 2'd0;
            load_start<=1; source_done<=0; memory_done<=0;
            idle_ms<=0; state<=LOADING;
        end
        LOADING: begin
            if (load_done) source_done<=1;
            if (finish_pulse) memory_done<=1;
            if (load_error) begin
                load_abort<=1; reset_hold<=16; auto_play_en<=0; state<=ERROR;
            end else if (source_done && memory_done) begin
                // Stable bundled data held until the pixel-domain frame-boundary ACK.
                disp_buf_idx<=write_buf_idx; img_idx<=load_idx;
                display_req_toggle<=~display_req_toggle; state<=COMMIT;
            end
        end
        COMMIT: if (commit_sync[2]==display_req_toggle) begin
            display_valid<=1; elapsed_ms<=0; state<=IDLE;
        end
        IDLE: if (prev_pending || next_pending || (auto_play_en && !key_auto_press && !pause_auto && !period_changed && elapsed_ms>=effective_period)) begin
            load_idx<=prev_pending ? prev_idx:next_idx; next_pending<=0; prev_pending<=0; elapsed_ms<=0; state<=START_LOAD;
        end
        ERROR, EMPTY: if (key_next_press || prev_press) begin
            reset_hold<=16; load_abort<=1; idle_ms<=0;
            auto_play_en<=0; next_pending<=0; prev_pending<=0; state<=INIT;
        end
        default: state<=ERROR;
        endcase
        if ((state==INIT || state==SCAN || state==LOADING) && idle_ms>=IO_TIMEOUT_MS) begin
            load_abort<=1; reset_hold<=16; auto_play_en<=0;
            source_done<=0; memory_done<=0; state<=ERROR;
        end
    end
end
generate if(SCALE_ENABLE) begin : scaled_reader
bmp_scale_read bmp_read_m0(
    .clk(clk), .rst(transport_rst), .ready(bmp_ready),
    .scan_start(scan_start), .scan_start_sector(32'd0),
    .scan_max_sector(SCAN_MAX_SECTOR), .scan_target_count(TARGET),
    .scan_done(scan_done), .scan_found_valid(found_valid),
    .scan_found_sector(found_sector), .scan_found_total(found_total),
    .load_start(load_start), .load_abort(load_abort), .load_sector(load_sector),
    .load_done(load_done), .load_error(load_error),
    .sd_init_done(sd_init_done), .state_code(reader_state),
    .bmp_width(bmp_width), .bmp_height(bmp_height),
    .write_req(write_req), .write_req_ack(write_req_ack),
    .sd_sec_read(sec_read), .sd_sec_read_addr(sec_addr),
    .sd_sec_read_data(sec_data), .sd_sec_read_data_valid(sec_valid),
    .sd_sec_read_end(sec_end), .bmp_data_wr_en(write_en), .bmp_data(pixel), .pixel_ready(write_ready)
);
end else begin : fixed_reader
bmp_read bmp_read_m0(
    .clk(clk), .rst(transport_rst), .ready(bmp_ready),
    .scan_start(scan_start), .scan_start_sector(32'd0),
    .scan_max_sector(SCAN_MAX_SECTOR), .scan_target_count(TARGET),
    .scan_done(scan_done), .scan_found_valid(found_valid),
    .scan_found_sector(found_sector), .scan_found_total(found_total),
    .load_start(load_start), .load_abort(load_abort), .load_sector(load_sector),
    .load_done(load_done), .load_error(load_error),
    .sd_init_done(sd_init_done), .state_code(reader_state),
    .bmp_width(bmp_width), .bmp_height(bmp_height),
    .write_req(write_req), .write_req_ack(write_req_ack),
    .sd_sec_read(sec_read), .sd_sec_read_addr(sec_addr),
    .sd_sec_read_data(sec_data), .sd_sec_read_data_valid(sec_valid),
    .sd_sec_read_end(sec_end), .bmp_data_wr_en(write_en), .bmp_data(pixel)
);
end endgenerate
sd_card_top sd_card_top_m0(
    .clk(clk), .rst(transport_rst), .SD_nCS(SD_nCS), .SD_DCLK(SD_DCLK),
    .SD_MOSI(SD_MOSI), .SD_MISO(SD_MISO), .sd_init_done(sd_init_done),
    .sd_sec_read(sec_read), .sd_sec_read_addr(sec_addr),
    .sd_sec_read_data(sec_data), .sd_sec_read_data_valid(sec_valid),
    .sd_sec_read_end(sec_end), .sd_sec_write(1'b0),
    .sd_sec_write_addr(32'd0), .sd_sec_write_data(8'd0),
    .sd_sec_write_data_req(), .sd_sec_write_end()
);
endmodule

module key_press_debounce #(
    parameter integer CLK_FREQ_HZ=100_000_000, DEBOUNCE_MS=20
)(input clk, rst, button_in, output reg press_pulse);
localparam integer CYCLES = ((CLK_FREQ_HZ/1000)*DEBOUNCE_MS < 1) ? 1 : (CLK_FREQ_HZ/1000)*DEBOUNCE_MS;
reg [1:0] sync;
reg stable;
reg [31:0] count;
always @(posedge clk or posedge rst) begin
    if (rst) begin sync<=3; stable<=1; count<=0; press_pulse<=0; end
    else begin
        sync<={sync[0],button_in}; press_pulse<=0;
        if (sync[1]==stable) count<=0;
        else if (count==CYCLES-1) begin
            press_pulse<=stable && !sync[1]; stable<=sync[1]; count<=0;
        end else count<=count+1'b1;
    end
end
endmodule


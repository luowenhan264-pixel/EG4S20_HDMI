
module top(
    input                       clk,
    input                       rst_n,
    input                       key1,           // Board KEY2 / B2: next page
    input                       key_prev,       // Board KEY3 / B1: previous page
    input                       key2,           // Board KEY4 / C1: experiment/menu

    output [5:0]                seg_sel,
    output [7:0]                seg_data,

    // HDMI TMDS
    output                      HDMI_CLK_P,
    output                      HDMI_D2_P,
    output                      HDMI_D1_P,
    output                      HDMI_D0_P,

    // HDMI DDC
    output                      HDMI_DDC_SCL,
    inout                       HDMI_DDC_SDA,

    // TF card SPI
    output                      sd_ncs,
    output                      sd_dclk,
    output                      sd_mosi,
    input                       sd_miso
);

parameter MEM_DATA_BITS = 32;
parameter ADDR_BITS     = 21;
parameter BUSRT_BITS    = 10;
parameter FRAME_PIXELS  = 24'd307200;   // 640*480
parameter BUF0_ADDR     = 24'd0;
parameter BUF1_ADDR     = FRAME_PIXELS;

// Default: discover contiguous BMPs in the first 64 MiB. Fixed mode is optional.
parameter USE_FIXED_SECTORS = 0;
parameter [31:0] SCAN_MAX_SECTOR = 32'd131071;
parameter [2:0]  IMG_COUNT      = 3'd4;
parameter [31:0] IMG_SECTOR0    = 32'd0;
parameter [31:0] IMG_SECTOR1    = 32'd2048;
parameter [31:0] IMG_SECTOR2    = 32'd4096;
parameter [31:0] IMG_SECTOR3    = 32'd6144;
parameter [1:0] DEFAULT_PERIOD_SEL = 0; // 0=2 s, 1=5 s, 2=10 s
parameter FADE_ENABLE = 1;
parameter integer FADE_FRAMES_PER_STEP = 1; // 32 steps each way, about 1.1 s total
parameter AUDIO_LINK_ENABLE = 1; // picture-specific cue; 0 restores legacy scale
parameter integer AUDIO_CUE_SAMPLES = 12000; // about 250 ms at Fs=MCLK/256

wire Sdr_init_done;
wire Sdr_init_ref_vld;
wire Sdr_busy;

wire sd_card_clk;
wire ext_mem_clk;
wire ext_mem_clk_sft;
wire video_clk;
wire hdmi_5x_clk;

wire hs;
wire vs;
wire de;

wire [23:0] vout_data_raw;
wire [23:0] osd_rgb;
wire [23:0] vout_data;
wire        display_valid;

wire [3:0]  state_code;
wire [6:0]  seg_data_0;
wire [1:0]  img_idx;
wire        auto_play_en;

wire        video_read_req;
wire        video_read_req_ack;
wire        video_read_en;
wire [31:0] video_read_data;

wire        sd_card_write_en;
wire [31:0] sd_card_write_data;
wire        sd_card_write_req;
wire        sd_card_write_req_ack;
wire        frame_write_finish;
reg         frame_write_toggle_mem;

wire [1:0]  write_buf_idx;
wire [1:0]  disp_buf_idx;
wire display_req_toggle, display_ack_toggle;
wire [1:0] video_buf_idx, video_img_idx;
wire video_display_valid, frame_start;
wire osd_vs, osd_de;
wire fade_hs, fade_vs, fade_de;
wire [23:0] fade_rgb;
wire [5:0] fade_gain;
wire control_next,control_prev,control_auto,settings_open;
wire navigation_ready;
wire [1:0] control_choice,control_page,page_sd;
wire [1:0] active_audio_page,active_audio_choice;
wire [23:0] scope_background;
wire scope_ready;
wire [2:0] settings_field;
wire [1:0] settings_period,settings_volume;
wire [3:0] settings_brightness;
wire [2:0] settings_contrast;
wire settings_subtitle;
wire adjust_hs,adjust_vs,adjust_de;
wire [23:0] adjust_rgb;
wire [31:0] settings_period_ms;
localparam [20:0] SETTINGS_RESET={4'd0,1'b1,3'd2,4'd4,1'b0,3'd0,2'd1,2'd2,1'b0};
wire [20:0] settings_video_cdc;
reg [20:0] settings_video;
wire [1:0] settings_audio_volume;
wire picture_audio_mode;
wire settings_hs,settings_vs,settings_de;
wire [23:0] settings_rgb;

wire App_rd_en;
wire [ADDR_BITS-1:0] App_rd_addr;
wire Sdr_rd_en;
wire [MEM_DATA_BITS-1:0] Sdr_rd_dout;
wire App_wr_en;
wire [ADDR_BITS-1:0] App_wr_addr;
wire [MEM_DATA_BITS-1:0] App_wr_din;
wire [3:0] App_wr_dm;

wire hs_0;
wire vs_0;
wire de_0;

// HDMI 1.4b 音频发射相关
wire        audio_pll_lock;
wire        audio_mclk;
wire        audio_i2s_bclk;
wire        audio_i2s_lrck;
wire        audio_i2s_dout;
wire        audio_valid;
wire        picture_audio_toggle;
wire [1:0]  picture_audio_image;
wire [23:0] audio_left_data;
wire [23:0] audio_right_data;
wire        acr_valid;
wire [19:0] acr_cts;
wire [19:0] acr_n;

wire        axis_s_user;
wire        axis_s_valid;
wire        axis_s_last;
wire [23:0] axis_s_data;
wire        axis_s_ready;

wire        edid_trig;
wire        edid_valid;
wire [7:0]  edid_data;

wire [9:0]  tmds_ch0_data;
wire [9:0]  tmds_ch1_data;
wire [9:0]  tmds_ch2_data;
wire [9:0]  tmds_clk_data;

// ex4 风格 POR：sys/video PLL lock + ~20ms，并保留 audio_pll_lock
wire sys_pll_lock;
wire video_pll_lock;
wire rst_all;
wire rst_sd, rst_mem, rst_video, rst_audio, rst_serial;

reg [19:0] rst_cnt = 20'd0;
reg rst_all_reg = 1'b1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rst_cnt <= 20'd0;
        rst_all_reg <= 1'b1;
    end else if (sys_pll_lock && video_pll_lock && audio_pll_lock) begin
        if (rst_cnt < 20'd1_000_000) begin
            rst_cnt <= rst_cnt + 1'b1;
            rst_all_reg <= 1'b1;
        end else begin
            rst_all_reg <= 1'b0;
        end
    end else begin
        rst_cnt <= 20'd0;
        rst_all_reg <= 1'b1;
    end
end

assign rst_all = rst_all_reg | ~rst_n | ~sys_pll_lock | ~video_pll_lock | ~audio_pll_lock;
player_reset_sync reset_sd(sd_card_clk, rst_all, rst_sd);
player_reset_sync reset_mem(ext_mem_clk, rst_all, rst_mem);
player_reset_sync reset_video(video_clk, rst_all, rst_video);
player_reset_sync reset_audio(audio_mclk, rst_all, rst_audio);
player_reset_sync reset_serial(hdmi_5x_clk, rst_all, rst_serial);

sys_pll sys_pll_m0(
    .refclk     (clk),
    .reset      (1'b0),
    .extlock    (sys_pll_lock),
    .clk0_out   (sd_card_clk),
    .clk1_out   (ext_mem_clk),
    .clk2_out   (ext_mem_clk_sft)
);

video_pll video_pll_m0(
    .refclk     (clk),
    .reset      (1'b0),
    .extlock    (video_pll_lock),
    .clk0_out   (video_clk),
    .clk1_out   (hdmi_5x_clk)
);

PLL_HDMI_AUDIO u_audio_pll(
    .refclk     (clk),
    .reset      (1'b0),
    .extlock    (audio_pll_lock),
    .clk0_out   (),
    .clk1_out   (),
    .clk2_out   (audio_mclk)
);

always @(posedge ext_mem_clk or posedge rst_mem) begin
    if (rst_mem)
        frame_write_toggle_mem <= 1'b0;
    else if (frame_write_finish)
        frame_write_toggle_mem <= ~frame_write_toggle_mem;
end

// ===================== TF playlist + 双缓冲 =====================
science_controls controls(
 .clk(sd_card_clk),.rst(rst_sd),.key_next(key1),.key_prev(key_prev),.key_action(key2),
 .page(page_sd),.ready(navigation_ready),.next_pulse(control_next),.prev_pulse(control_prev),
 .auto_pulse(control_auto),.menu_open(settings_open),.field(settings_field),
 .choice(control_choice),.choice_page(control_page),.volume(settings_volume),.period_sel(settings_period),
 .brightness(settings_brightness),.contrast(settings_contrast),.subtitle_enable(settings_subtitle)
);
assign settings_period_ms=settings_period==0 ? 2000:settings_period==1 ? 5000:10000;
player_config_cdc #(.WIDTH(2)) page_to_controls(
 .src_clk(video_clk),.src_rst(rst_video),.src_value(video_img_idx),
 .dst_clk(sd_card_clk),.dst_rst(rst_sd),.dst_value(page_sd));
player_config_cdc #(.WIDTH(21),.RESET_VALUE(SETTINGS_RESET)) settings_to_video(
 .src_clk(sd_card_clk),.src_rst(rst_sd),
 .src_value({control_page,control_choice,settings_subtitle,settings_contrast,settings_brightness,settings_open,settings_field,settings_period,settings_volume,1'b0}),
 .dst_clk(video_clk),.dst_rst(rst_video),.dst_value(settings_video_cdc)
);
wire [1:0] experiment_choice=settings_video[20:19]==video_img_idx ? settings_video[18:17]:
 (video_img_idx==1 || video_img_idx==2) ? 2'd1:2'd0;
always @(posedge video_clk or posedge rst_video)
    if(rst_video) settings_video<=SETTINGS_RESET;
    else if(frame_start) settings_video<=settings_video_cdc;
player_config_cdc #(.WIDTH(2),.RESET_VALUE(2'b11)) settings_to_audio(
    .src_clk(video_clk),.src_rst(rst_video),.src_value(settings_video[2:1]),
    .dst_clk(audio_mclk),.dst_rst(rst_audio),.dst_value(settings_audio_volume)
);
wire sd_card_write_ready;
sd_card_bmp #(
    .CLK_FREQ_HZ    (100_000_000),
    .IMG_COUNT      (IMG_COUNT),
    .USE_FIXED_SECTORS(USE_FIXED_SECTORS),
    .SCAN_MAX_SECTOR(SCAN_MAX_SECTOR),
    .IMG_SECTOR0    (IMG_SECTOR0),
    .IMG_SECTOR1    (IMG_SECTOR1),
    .IMG_SECTOR2    (IMG_SECTOR2),
    .IMG_SECTOR3    (IMG_SECTOR3),
    .EXTERNAL_CONTROL(1),
    .SCALE_ENABLE(1),.PREV_ENABLE(1)
) sd_card_bmp_m0(
    .clk               (sd_card_clk),
    .rst               (rst_sd),
    .key_next          (key1),
    .key_auto          (key2),
    .control_next(control_next),.control_prev(control_prev),.navigation_ready(navigation_ready),.control_auto(control_auto),
    .control_pause(settings_open),.control_period_ms(settings_period_ms),
    .state_code        (state_code),
    .bmp_width         (16'd640),
    .bmp_height        (16'd480),
    .display_valid     (display_valid),
    .img_idx           (img_idx),
    .auto_play_en      (auto_play_en),

    .write_finish_toggle(frame_write_toggle_mem),
    .write_buf_idx     (write_buf_idx),
    .disp_buf_idx      (disp_buf_idx),
    .display_req_toggle(display_req_toggle),
    .display_ack_toggle(display_ack_toggle),

    .write_req         (sd_card_write_req),
    .write_req_ack     (sd_card_write_req_ack),
    .write_en          (sd_card_write_en),
    .write_ready       (sd_card_write_ready),
    .write_data        (sd_card_write_data),
    .SD_nCS            (sd_ncs),
    .SD_DCLK           (sd_dclk),
    .SD_MOSI           (sd_mosi),
    .SD_MISO           (sd_miso)
);

seg_decoder seg_decoder_m0(
    .bin_data          (state_code),
    .seg_data          (seg_data_0)
);

seg_scan seg_scan_m0(
    .clk               (clk),
    .rst_n             (rst_n),
    .seg_sel           (seg_sel),
    .seg_data          (seg_data),
    .seg_data_0        ({1'b1,7'b1111_111}),
    .seg_data_1        ({1'b1,7'b1111_111}),
    .seg_data_2        ({1'b1,7'b1111_111}),
    .seg_data_3        ({1'b1,7'b1111_111}),
    .seg_data_4        ({1'b1,7'b1111_111}),
    .seg_data_5        ({1'b1,seg_data_0})
);

video_timing_data video_timing_data_m0(
    .video_clk         (video_clk),
    .rst               (rst_video),
    .frame_start       (frame_start),
    .read_req          (video_read_req),
    .read_req_ack      (video_read_req_ack),
    .hs                (hs_0),
    .vs                (vs_0),
    .de                (de_0)
);

video_delay video_delay_m0(
    .video_clk         (video_clk),
    .rst               (rst_video),
    .read_en           (video_read_en),
    .read_data         (video_read_data[31:8]),
    .hs                (hs_0),
    .vs                (vs_0),
    .de                (de_0),
    .hs_r              (hs),
    .vs_r              (vs),
    .de_r              (de),
    .vout_data         (vout_data_raw)
);

// sd_card_clk -> video_clk 轻量同步（OSD 显示用）
reg [1:0] img_idx_sync0, img_idx_sync1;
reg       auto_play_sync0, auto_play_sync1;
reg [3:0] state_code_sync0, state_code_sync1;

always @(posedge video_clk or posedge rst_video) begin
    if (rst_video) begin
        img_idx_sync0    <= 2'd0;
        img_idx_sync1    <= 2'd0;
        auto_play_sync0  <= 1'b0;
        auto_play_sync1  <= 1'b0;
        state_code_sync0 <= 4'd0;
        state_code_sync1 <= 4'd0;
    end else begin
        img_idx_sync0    <= img_idx;
        img_idx_sync1    <= img_idx_sync0;
        auto_play_sync0  <= auto_play_en;
        auto_play_sync1  <= auto_play_sync0;
        state_code_sync0 <= state_code;
        state_code_sync1 <= state_code_sync0;
    end
end

video_picture_adjust picture_adjust(
    .clk(video_clk),.rst(rst_video),.hs(hs),.vs(vs),.de(de),.rgb(vout_data_raw),
    .brightness(settings_video[12:9]),.contrast(settings_video[15:13]),
    .hs_out(adjust_hs),.vs_out(adjust_vs),.de_out(adjust_de),.rgb_out(adjust_rgb)
);
video_fade_rgb fade_pixels(
    .clk(video_clk), .rst(rst_video), .hs(adjust_hs), .vs(adjust_vs), .de(adjust_de),
    .rgb(video_display_valid ? adjust_rgb : 24'd0), .gain(fade_gain),
    .hs_out(fade_hs), .vs_out(fade_vs), .de_out(fade_de), .rgb_out(fade_rgb)
);

wire scope_hs,scope_vs,scope_de;
wire [23:0] scope_rgb;
science_scope audio_scope(
 .clk(video_clk),.rst(rst_video),.enable(video_display_valid),
 .hs(fade_hs),.vs(fade_vs),.de(fade_de),.rgb(fade_rgb),
 .audio_valid(audio_valid && scope_ready),.audio_left(video_img_idx==3 ? scope_background:audio_left_data),.audio_right(audio_right_data),
 .trigger_enable(video_img_idx!=3),.config_tag({video_display_valid,video_img_idx,experiment_choice,settings_video[2:1]}),
 .hs_out(scope_hs),.vs_out(scope_vs),.de_out(scope_de),.rgb_out(scope_rgb)
);
science_osd settings_overlay(
 .clk(video_clk),.rst(rst_video),.hs(scope_hs),.vs(scope_vs),.de(scope_de),.rgb(scope_rgb),
 .page(video_img_idx),.choice(experiment_choice),.volume(settings_video[2:1]),.period_sel(settings_video[4:3]),
 .menu_open(settings_video[8]),.field(settings_video[7:5]),.contrast(settings_video[15:13]),
 .brightness(settings_video[12:9]),.auto_play(auto_play_sync1),.subtitle_enable(settings_video[16]),
 .loading(state_code_sync1!=1),.hs_out(settings_hs),.vs_out(osd_vs),.de_out(osd_de),.rgb_out(osd_rgb)
);
assign vout_data=osd_rgb;

player_frame_commit #(.FADE_ENABLE(FADE_ENABLE), .FRAMES_PER_STEP(FADE_FRAMES_PER_STEP)) frame_commit(
    .clk(video_clk), .rst(rst_video), .frame_start(frame_start),
    .request_toggle(display_req_toggle), .requested_bank(disp_buf_idx),
    .requested_image(img_idx), .ack_toggle(display_ack_toggle),
    .active_bank(video_buf_idx), .active_image(video_img_idx), .valid(video_display_valid),
    .fade_gain(fade_gain), .busy()
);

frame_read_write #(
    .WRITE_V_FLIP     (0), // Scaler already emits top-down rows
    .FRAME_WIDTH      (640),
    .FRAME_HEIGHT     (480)
) frame_read_write_m0(
    .mem_clk           (ext_mem_clk),
    .rst               (rst_mem),
    .Sdr_init_done     (Sdr_init_done),
    .Sdr_init_ref_vld  (Sdr_init_ref_vld),
    .Sdr_busy          (Sdr_busy),

    .App_rd_en         (App_rd_en),
    .App_rd_addr       (App_rd_addr),
    .Sdr_rd_en         (Sdr_rd_en),
    .Sdr_rd_dout       (Sdr_rd_dout),

    .read_clk          (video_clk),
    .read_req          (video_read_req),
    .read_req_ack      (video_read_req_ack),
    .read_finish       (),
    .read_addr_0       (BUF0_ADDR),
    .read_addr_1       (BUF1_ADDR),
    .read_addr_2       (24'd0),
    .read_addr_3       (24'd0),
    .read_addr_index   (video_buf_idx),
    .read_len          (FRAME_PIXELS),
    .read_en           (video_read_en),
    .read_data         (video_read_data),

    .App_wr_en         (App_wr_en),
    .App_wr_addr       (App_wr_addr),
    .App_wr_din        (App_wr_din),
    .App_wr_dm         (App_wr_dm),

    .write_clk         (sd_card_clk),
    .write_req         (sd_card_write_req),
    .write_req_ack     (sd_card_write_req_ack),
    .write_finish      (frame_write_finish),
    .write_addr_0      (BUF0_ADDR),
    .write_addr_1      (BUF1_ADDR),
    .write_addr_2      (24'd0),
    .write_addr_3      (24'd0),
    .write_addr_index  (write_buf_idx),
    .write_len         (FRAME_PIXELS),
    .write_en          (sd_card_write_en),
    .write_ready       (sd_card_write_ready),
    .write_data        (sd_card_write_data)
);

sdram U3(
    .Clk               (ext_mem_clk),
    .Clk_sft           (ext_mem_clk_sft),
    .Rst               (rst_mem),
    .Sdr_init_done     (Sdr_init_done),
    .Sdr_init_ref_vld  (Sdr_init_ref_vld),
    .Sdr_busy          (Sdr_busy),
    .App_wr_en         (App_wr_en),
    .App_wr_addr       (App_wr_addr),
    .App_wr_dm         (App_wr_dm),
    .App_wr_din        (App_wr_din),
    .App_rd_en         (App_rd_en),
    .App_rd_addr       (App_rd_addr),
    .Sdr_rd_en         (Sdr_rd_en),
    .Sdr_rd_dout       (Sdr_rd_dout)
);

player_picture_event audio_picture_event(
    .clk(video_clk), .rst(rst_video), .valid(video_display_valid),
    .bank(video_buf_idx), .image_id(video_img_idx),
    .event_toggle(picture_audio_toggle), .event_image(picture_audio_image),
    .two_note(settings_video[0]),.event_two_note(picture_audio_mode)
);

generate if (AUDIO_LINK_ENABLE) begin : linked_audio
hdmi_audio_link_i2s #(.CUE_SAMPLES(AUDIO_CUE_SAMPLES)) cue(
    .I_mclk(audio_mclk), .I_rst(rst_audio),
    .I_event_toggle(1'b0), .I_image_id(2'd0),
    .I_volume(settings_audio_volume),.I_two_note(picture_audio_mode),
    .O_i2s_BCLK(audio_i2s_bclk), .O_i2s_LRCK(audio_i2s_lrck),
    .O_i2s_DOUT(audio_i2s_dout)
);
end else begin : legacy_audio
hdmi_audio_tone_i2s_64fs #(
    .PHASE_INC (32'd39370534),
    .AMP       (24'sd2000000)
) u_hdmi_audio_tone_i2s_64fs (
    .I_mclk      (audio_mclk),
    .I_rst       (rst_audio),
    .O_i2s_BCLK  (audio_i2s_bclk),
    .O_i2s_LRCK  (audio_i2s_lrck),
    .O_i2s_DOUT  (audio_i2s_dout)
);
end endgenerate

wire cue_audio_valid;
wire [23:0] cue_audio_left,cue_audio_right;
I2S_receiver u_I2S_receiver(
    .I_clk              (video_clk),
    .I_rst              (rst_video),
    .I_i2s_BCLK         (audio_i2s_bclk),
    .I_i2s_LRCK         (audio_i2s_lrck),
    .I_i2s_DOUT         (audio_i2s_dout),
    .O_audio_valid      (cue_audio_valid),
    .O_audio_left_data  (cue_audio_left),
    .O_audio_right_data (cue_audio_right)
);

science_audio experiment_audio(
 .clk(video_clk),.rst(rst_video),.sample_valid(cue_audio_valid),
 .enable(video_display_valid && fade_gain==32),.page(video_img_idx),.choice(experiment_choice),.volume(settings_video[2:1]),
 .audio_valid(audio_valid),.audio_left(audio_left_data),.audio_right(audio_right_data),
 .scope_background(scope_background),.active_page(active_audio_page),.active_choice(active_audio_choice),.scope_ready(scope_ready)
);

audio_arc_calculate #(
    .ACR_N         (6144)
) u_audio_arc_calculate (
    .I_clk         (video_clk),
    .I_rst         (rst_video),
    .I_audio_valid (audio_valid),
    .O_acr_valid   (acr_valid),
    .O_acr_cts     (acr_cts),
    .O_acr_n       (acr_n)
);

video_rgb_to_axis_640x480 u_video_rgb_to_axis_640x480(
    .I_clk         (video_clk),
    .I_rst         (rst_video),
    .I_vs          (osd_vs),
    .I_de          (osd_de),
    .I_rgb         (vout_data),
    .O_video_user  (axis_s_user),
    .O_video_valid (axis_s_valid),
    .O_video_last  (axis_s_last),
    .O_video_data  (axis_s_data)
);

startup_pulse #(
    .CNT_MAX(20'd100000)
) u_startup_pulse (
    .I_clk   (video_clk),
    .I_rst   (rst_video),
    .O_pulse (edid_trig)
);

hdmi_1_4b_transmitter_core_wrapper #(
    .DEVICE                 ( "EG"       ),
    .HTOTAL                 ( 800        ),
    .HSA                    ( 96         ),
    .HFP                    ( 16         ),
    .HBP                    ( 48         ),
    .HACTIVE                ( 640        ),
    .VTOTAL                 ( 525        ),
    .VSA                    ( 2          ),
    .VFP                    ( 10         ),
    .VBP                    ( 33         ),
    .VACTIVE                ( 480        ),
    .VIDEO_VIC              ( 1          ),
    .VIDEO_TPG              ( "Disable"  ),
    .VIDEO_FORMAT           ( "RGB"      ),
    .AUDIO_SAMPLE_RATE      ( "48K"      ),
    .IIC_SCL_DIV            ( 250        )
) u_hdmi_1_4b_transmitter_core_wrapper(
    .I_pixel_clk        (video_clk),
    .I_rst              (rst_video),
    .I_edid_read_trig   (edid_trig),
    .O_edid_read_valid  (edid_valid),
    .O_edid_read_data   (edid_data),

    .I_axis_s_user      (axis_s_user),
    .I_axis_s_valid     (axis_s_valid),
    .I_axis_s_last      (axis_s_last),
    .I_axis_s_data      (axis_s_data),
    .O_axis_s_ready     (axis_s_ready),

    .I_audio_valid      (audio_valid),
    .I_audio_left_data  (audio_left_data),
    .I_audio_right_data (audio_right_data),
    .I_acr_valid        (acr_valid),
    .I_acr_cts          (acr_cts),
    .I_acr_n            (acr_n),

    .O_video_locked     (),
    .O_ddc_scl          (HDMI_DDC_SCL),
    .IO_ddc_sda         (HDMI_DDC_SDA),

    .O_ch0_tmds_data    (tmds_ch0_data),
    .O_ch1_tmds_data    (tmds_ch1_data),
    .O_ch2_tmds_data    (tmds_ch2_data),
    .O_clk_tmds_data    (tmds_clk_data)
);

hdmi_phy_wrapper #(
    .DEVICE ( "EG" )
) u_hdmi2phy_wrapper(
    .I_pixel_clk        (video_clk),
    .I_serial_clk       (hdmi_5x_clk),
    .I_rst              (rst_serial),
    .I_pixel_rst        (rst_video),
    .I_tmds_channel_0   (tmds_ch0_data),
    .I_tmds_channel_1   (tmds_ch1_data),
    .I_tmds_channel_2   (tmds_ch2_data),
    .I_tmds_channel_clk (tmds_clk_data),
    .O_tmds_ch0_p       (HDMI_D0_P),
    .O_tmds_ch1_p       (HDMI_D1_P),
    .O_tmds_ch2_p       (HDMI_D2_P),
    .O_tmds_clk_p       (HDMI_CLK_P)
);

endmodule

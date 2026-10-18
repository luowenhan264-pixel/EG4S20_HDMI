
module top(
    input                       clk,
    input                       rst_n,
    input                       key1,           // 手动下一张
    input                       key2,           // 自动播放 开/关

    output [3:0]                led_data,       // 板载 4 颗用户指示灯 (B12, C10, A3, A4)

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

// playlist 默认扇区（需与烧卡布局一致；等间距占位）
parameter [2:0]  IMG_COUNT      = 3'd4;
parameter [31:0] IMG_SECTOR0    = 32'd0;
parameter [31:0] IMG_SECTOR1    = 32'd2048;
parameter [31:0] IMG_SECTOR2    = 32'd4096;
parameter [31:0] IMG_SECTOR3    = 32'd6144;
parameter [31:0] AUTO_PERIOD_MS = 32'd2000;

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
wire        audio_valid_raw;
wire [23:0] audio_left_data_raw;
wire [23:0] audio_right_data_raw;
wire        audio_valid;
wire [23:0] audio_left_data;
wire [23:0] audio_right_data;
wire        acr_valid;
wire [19:0] acr_cts;
wire [19:0] acr_n;

// 多功能按键控制信号
wire        next_img_trig;
wire [1:0]  fx_mode;
wire        vis_mode;
wire        auto_play_trig;
wire        osd_toggle_trig;
wire        osd_enable;
wire [3:0]  vol_level;

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

reg [19:0] rst_cnt = 20'd0;
reg rst_all_reg = 1'b1;

always @(posedge clk) begin
    if (!rst_n) begin
        rst_cnt <= 20'd0;
        rst_all_reg <= 1'b1;
    end else if (!rst_all_reg) begin
        rst_all_reg <= 1'b0;
    end else if (sys_pll_lock && video_pll_lock) begin
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

assign rst_all = rst_all_reg | ~audio_pll_lock;

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

always @(posedge ext_mem_clk or posedge rst_all) begin
    if (rst_all)
        frame_write_toggle_mem <= 1'b0;
    else if (frame_write_finish)
        frame_write_toggle_mem <= ~frame_write_toggle_mem;
end

// ===================== TF playlist + 双缓冲 =====================
sd_card_bmp #(
    .CLK_FREQ_HZ        (100_000_000),
    .IMG_COUNT          (IMG_COUNT),
    .IMG_SECTOR0        (IMG_SECTOR0),
    .IMG_SECTOR1        (IMG_SECTOR1),
    .IMG_SECTOR2        (IMG_SECTOR2),
    .IMG_SECTOR3        (IMG_SECTOR3),
    .AUTO_PERIOD_MS     (AUTO_PERIOD_MS),
    .USE_EXT_TRIG_PULSE (1'b1)
) sd_card_bmp_m0(
    .clk               (sd_card_clk),
    .rst               (rst_all),
    .key_next          (next_img_trig),
    .key_auto          (auto_play_trig),
    .state_code        (state_code),
    .bmp_width         (16'd640),
    .bmp_height        (16'd480),
    .display_valid     (display_valid),
    .img_idx           (img_idx),
    .auto_play_en      (auto_play_en),

    .write_finish_toggle(frame_write_toggle_mem),
    .write_buf_idx     (write_buf_idx),
    .disp_buf_idx      (disp_buf_idx),

    .write_req         (sd_card_write_req),
    .write_req_ack     (sd_card_write_req_ack),
    .write_en          (sd_card_write_en),
    .write_data        (sd_card_write_data),
    .SD_nCS            (sd_ncs),
    .SD_DCLK           (sd_dclk),
    .SD_MOSI           (sd_mosi),
    .SD_MISO           (sd_miso)
);

// ===================== 多功能按键控制器（短按/长按消抖，运行于 sd_card_clk 100MHz 域） =====================
multi_function_key_controller #(
    .CLK_FREQ_HZ       (100_000_000)
) u_key_ctrl (
    .clk               (sd_card_clk),
    .rst_n             (~rst_all),
    .key1_raw          (key1),
    .key2_raw          (key2),
    .next_img_trig     (next_img_trig),
    .fx_mode           (fx_mode),
    .vis_mode          (vis_mode),
    .auto_play_trig    (auto_play_trig),
    .osd_toggle_trig   (osd_toggle_trig),
    .osd_en            (osd_enable),
    .vol_level         (vol_level)
);

// 板载用户指示灯与心跳
reg [25:0] heartbeat_cnt = 26'd0;
always @(posedge clk) heartbeat_cnt <= heartbeat_cnt + 26'd1;

wire [1:0] active_read_buf_idx;
wire       in_transition;

assign led_data[0] = heartbeat_cnt[24];                                  // LED0: 1.5Hz 心跳闪烁
assign led_data[1] = sys_pll_lock & video_pll_lock & audio_pll_lock;     // LED1: 全 PLL 锁定常亮
assign led_data[2] = auto_play_en;                                       // LED2: 自动轮播激活指示
assign led_data[3] = (state_code != 4'd1) | in_transition;               // LED3: SD卡读图或转场中

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
    .rst               (rst_all),
    .read_req          (video_read_req),
    .read_req_ack      (video_read_req_ack),
    .hs                (hs_0),
    .vs                (vs_0),
    .de                (de_0)
);

video_delay video_delay_m0(
    .video_clk         (video_clk),
    .rst               (rst_all),
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

// sd_card_clk -> video_clk 跨时钟域双级同步器
reg [1:0] img_idx_sync0,       img_idx_sync1;
reg [1:0] disp_buf_idx_sync0,  disp_buf_idx_sync1;
reg       display_valid_sync0, display_valid_sync1;
reg       auto_play_sync0,     auto_play_sync1;
reg [3:0] state_code_sync0,    state_code_sync1;
reg [1:0] fx_mode_sync0,       fx_mode_sync1;
reg       vis_mode_sync0,      vis_mode_sync1;
reg [3:0] vol_level_sync0,     vol_level_sync1;
reg       osd_en_sync0,        osd_en_sync1;

always @(posedge video_clk or posedge rst_all) begin
    if (rst_all) begin
        img_idx_sync0       <= 2'd0;
        img_idx_sync1       <= 2'd0;
        disp_buf_idx_sync0  <= 2'd0;
        disp_buf_idx_sync1  <= 2'd0;
        display_valid_sync0 <= 1'b0;
        display_valid_sync1 <= 1'b0;
        auto_play_sync0     <= 1'b0;
        auto_play_sync1     <= 1'b0;
        state_code_sync0    <= 4'd0;
        state_code_sync1    <= 4'd0;
        fx_mode_sync0       <= 2'd1;
        fx_mode_sync1       <= 2'd1;
        vis_mode_sync0      <= 1'b0;
        vis_mode_sync1      <= 1'b0;
        vol_level_sync0     <= 4'd12;
        vol_level_sync1     <= 4'd12;
        osd_en_sync0        <= 1'b1;
        osd_en_sync1        <= 1'b1;
    end else begin
        img_idx_sync0       <= img_idx;
        img_idx_sync1       <= img_idx_sync0;
        disp_buf_idx_sync0  <= disp_buf_idx;
        disp_buf_idx_sync1  <= disp_buf_idx_sync0;
        display_valid_sync0 <= display_valid;
        display_valid_sync1 <= display_valid_sync0;
        auto_play_sync0     <= auto_play_en;
        auto_play_sync1     <= auto_play_sync0;
        state_code_sync0    <= state_code;
        state_code_sync1    <= state_code_sync0;
        fx_mode_sync0       <= fx_mode;
        fx_mode_sync1       <= fx_mode_sync0;
        vis_mode_sync0      <= vis_mode;
        vis_mode_sync1      <= vis_mode_sync0;
        vol_level_sync0     <= vol_level;
        vol_level_sync1     <= vol_level_sync0;
        osd_en_sync0        <= osd_enable;
        osd_en_sync1        <= osd_en_sync0;
    end
end

// ===================== 视频处理流水线 Stage 1：硬件转场特效引擎 (Latency = +1 clk) =====================
wire        vs_s1, hs_s1, de_s1;
wire [23:0] fx_rgb;

image_transition_engine u_transition_engine (
    .video_clk         (video_clk),
    .rst               (rst_all),
    .vs                (vs),
    .hs                (hs),
    .de                (de),
    .fx_mode           (fx_mode_sync1),
    .target_buf_idx    (disp_buf_idx_sync1),
    .active_buf_idx    (active_read_buf_idx),
    .in_transition     (in_transition),
    .raw_rgb           (vout_data_raw),
    .vs_out            (vs_s1),
    .hs_out            (hs_s1),
    .de_out            (de_s1),
    .fx_rgb            (fx_rgb)
);

// ===================== 视频处理流水线 Stage 2：实时音频频谱与波形示波器 (Latency = +2 clk) =====================
wire        vs_s2, hs_s2, de_s2;
wire [23:0] vis_rgb;

audio_spectrum_visualizer u_audio_vis (
    .video_clk         (video_clk),
    .rst               (rst_all),
    .vs                (vs_s1),
    .hs                (hs_s1),
    .de                (de_s1),
    .vis_en            (osd_en_sync1),
    .vis_mode          (vis_mode_sync1), // 0: 示波器波形模式, 1: 16段柱状频谱模式 (KEY1长按切换)
    .audio_valid       (audio_valid_raw),
    .audio_pcm         (audio_left_data_raw),
    .bg_rgb            (fx_rgb),
    .vs_out            (vs_s2),
    .hs_out            (hs_s2),
    .de_out            (de_s2),
    .vis_rgb           (vis_rgb)
);

// ===================== 视频处理流水线 Stage 3：专业 ASCII 字符 OSD 叠加 (Latency = +3 clk) =====================
wire        vs_s3, hs_s3, de_s3;

osd_text_overlay u_osd_text (
    .video_clk         (video_clk),
    .rst               (rst_all),
    .hs                (hs_s2),
    .vs                (vs_s2),
    .de                (de_s2),
    .img_idx           (img_idx_sync1),
    .auto_play_en      (auto_play_sync1),
    .vol_level         (vol_level_sync1),
    .fx_mode           (fx_mode_sync1),
    .state_code        (state_code_sync1),
    .osd_en            (osd_en_sync1),
    .bg_rgb            (vis_rgb),
    .vs_out            (vs_s3),
    .hs_out            (hs_s3),
    .de_out            (de_s3),
    .osd_rgb           (osd_rgb)
);

assign vout_data = display_valid_sync1 ? osd_rgb : 24'd0;

frame_read_write #(
    .WRITE_V_FLIP     (1),
    .FRAME_WIDTH      (640),
    .FRAME_HEIGHT     (480)
) frame_read_write_m0(
    .mem_clk           (ext_mem_clk),
    .rst               (rst_all),
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
    .read_addr_index   (active_read_buf_idx),
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
    .write_data        (sd_card_write_data)
);

sdram U3(
    .Clk               (ext_mem_clk),
    .Clk_sft           (ext_mem_clk_sft),
    .Rst               (rst_all),
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

hdmi_audio_tone_i2s_64fs #(
    .PHASE_INC (32'd39370534),
    .AMP       (24'sd2000000)
) u_hdmi_audio_tone_i2s_64fs (
    .I_mclk      (audio_mclk),
    .I_rst       (rst_all),
    .O_i2s_BCLK  (audio_i2s_bclk),
    .O_i2s_LRCK  (audio_i2s_lrck),
    .O_i2s_DOUT  (audio_i2s_dout)
);

I2S_receiver u_I2S_receiver(
    .I_clk              (video_clk),
    .I_rst              (rst_all),
    .I_i2s_BCLK         (audio_i2s_bclk),
    .I_i2s_LRCK         (audio_i2s_lrck),
    .I_i2s_DOUT         (audio_i2s_dout),
    .O_audio_valid      (audio_valid_raw),
    .O_audio_left_data  (audio_left_data_raw),
    .O_audio_right_data (audio_right_data_raw)
);

audio_volume_controller u_audio_vol_ctrl (
    .clk             (video_clk),
    .rst             (rst_all),
    .vol_level       (vol_level_sync1),
    .vol_mute        (1'b0),
    .audio_valid_in  (audio_valid_raw),
    .audio_left_in   (audio_left_data_raw),
    .audio_right_in  (audio_right_data_raw),
    .audio_valid_out (audio_valid),
    .audio_left_out  (audio_left_data),
    .audio_right_out (audio_right_data)
);

audio_arc_calculate #(
    .ACR_N         (6144)
) u_audio_arc_calculate (
    .I_clk         (video_clk),
    .I_rst         (rst_all),
    .I_audio_valid (audio_valid),
    .O_acr_valid   (acr_valid),
    .O_acr_cts     (acr_cts),
    .O_acr_n       (acr_n)
);

video_rgb_to_axis_640x480 u_video_rgb_to_axis_640x480(
    .I_clk         (video_clk),
    .I_rst         (rst_all),
    .I_vs          (vs_s3),
    .I_de          (de_s3),
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
    .I_rst   (rst_all),
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
    .I_rst              (rst_all),
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
    .I_rst              (rst_all),
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

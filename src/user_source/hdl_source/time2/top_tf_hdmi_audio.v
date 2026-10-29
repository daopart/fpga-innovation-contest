module top(
    input                       clk,
    input                       rst_n,
    input                       key1,
    input                       key2,

    input                       key3,           // 亮度 -
    input                       key4,           // 亮度 +
    input                       key5,           // 对比度 -
    input                       key6,           // 对比度 +

    input                       key7,

    output [7:0]                seg_sel,
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

// ---------------- 全局信号 ----------------
wire        rst_all;

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

wire [23:0] zoom_rgb;
wire [23:0] trans_rgb;
wire [23:0] sub_rgb;
wire [23:0] wave_rgb;
wire [23:0] adj_rgb;            // 亮度/对比度调整后
wire [23:0] osd_rgb;            // 再叠加参数 OSD 后
wire        adj_de;             // 与 adj_rgb 对齐
wire        adj_vs;
wire        adj_hs;
wire signed [7:0] adj_bright;   // -32..+31
wire [8:0]  adj_gain;
wire        adj_show;           // 按键后约 1.5s 显示 OSD
wire [23:0] vout_data;
wire        trans_hs;
wire        trans_vs;
wire        trans_de;
wire        sub_hs;
wire        sub_vs;
wire        sub_de;
wire        wave_hs;
wire        wave_vs;
wire        wave_de;
wire        display_valid;

wire [3:0]  state_code;
wire [2:0]  img_count;          // SD 卡扫描到的图片数（显示用）

wire        wav_need;      // 音频缓冲偏空
wire        wav_found;     // 卡上找到 WAV
wire        wav_we;        // 样点写使能
wire [23:0] wav_data;      // 样点
wire        wav_mode;      // 当前在放 WAV（调试用）

wire [1:0]  filter_mode;

wire [3:0]  wav_track_cnt;
wire        wav_fmt_bad;
reg  [3:0]  wav_track_sel;
wire [6:0]  track_seg;

wire [6:0]  seg_data_0;

localparam DIAG_MODE = 1'b1;
wire        sd_init_done_d;
wire [1:0]  sd_retry_d;
wire [6:0]  sdinit_seg, retry_seg, dvalid_seg, rst_seg, wavf_seg, trkcnt_seg;

wire        video_read_empty;

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

wire [ADDR_BITS-1:0] wr_addr_0_c = BUF0_ADDR;
wire [ADDR_BITS-1:0] wr_addr_1_c = BUF1_ADDR;
wire [ADDR_BITS-1:0] wr_len_c    = FRAME_PIXELS;

// 缩放控制
wire        key1_next;
wire        key2_auto;
wire        zoom_in_tog;        // 长按 key1 -> 放大一档
wire        zoom_out_tog;       // 长按 key2 -> 缩小一档
wire [2:0]  zoom_level;

// 双击 -> 转场 / 字幕
wire        key1_short;
wire        key2_short;
wire        key1_dbl;
wire        key2_dbl;
wire [2:0]  trans_mode;
wire [2:0]  sub_page;
wire        sub_active;
wire [2:0]  trans_mode_v;       // 同步到 video_clk 域
wire [2:0]  sub_page_v;
wire        disp_buf_v;
wire        trans_busy;
reg         disp_tog;

wire        zoom_line_req;
wire        zoom_line_ack;
wire [20:0] zoom_line_addr;
wire        zoom_line_ren;
wire [31:0] zoom_line_rdata;

// HDMI 1.4b 音频发射相关
wire        sys_pll_lock;
wire        video_pll_lock;
wire        audio_pll_lock;
wire        audio_mclk;
wire        audio_i2s_bclk;
wire        audio_i2s_lrck;
wire        audio_i2s_dout;
wire        audio_valid;
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

// ===================== 统一复位 =====================

reg [19:0] rst_cnt;
reg        rst_all_reg;

wire all_pll_locked = sys_pll_lock & video_pll_lock & audio_pll_lock;
wire pll_lock_ok    = rst_n & all_pll_locked;

assign rst_all = rst_all_reg;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        rst_cnt <= 20'd0;
        rst_all_reg <= 1'b1;
    end else begin
        if (rst_all_reg) begin

            if (pll_lock_ok) begin
                if (rst_cnt >= 20'd999999) begin
                    rst_all_reg <= 1'b0; // 计满释放
                end else begin
                    rst_cnt <= rst_cnt + 20'd1;
                end
            end else begin
                rst_cnt <= 20'd0;
            end
        end else begin

            rst_all_reg <= 1'b0;
        end
    end
end

// ===================== 时钟 =====================
sys_pll sys_pll_m0(
    .refclk     (clk),
    .clk0_out   (sd_card_clk),
    .clk1_out   (ext_mem_clk),
    .clk2_out   (ext_mem_clk_sft),
    .reset      (1'b0),
    .extlock    (sys_pll_lock)
);

video_pll video_pll_m0(
    .refclk     (clk),
    .clk0_out   (video_clk),
    .clk1_out   (hdmi_5x_clk),
    .reset      (1'b0),
    .extlock    (video_pll_lock)
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

// ===================== 按键：短按换图 / 长按缩放 =====================
key_zoom_ctrl #(
    .CLK_FREQ_HZ (100_000_000),
    .DEBOUNCE_MS (10),
    .LONG_MS     (800),
    .PULSE_MS    (120)
) u_key_zoom_ctrl (
    .clk          (sd_card_clk),
    .rst          (rst_all),
    .key1         (key1),
    .key2         (key2),
    .next_press   (key1_next),
    .auto_press   (key2_auto),
    .zoom_in_tog  (zoom_in_tog),
    .zoom_out_tog (zoom_out_tog),
    .key1_short   (key1_short),
    .key2_short   (key2_short)
);

// ===================== 连按三下 KEY3：切换 TF 卡音乐 =====================

wire      track_evt;                 // 三连击脉冲（video_clk 域）
reg [2:0] track_evt_sync;            // 同步到 sd_card_clk 域
wire      track_evt_s = track_evt_sync[1] & ~track_evt_sync[2];

always @(posedge sd_card_clk or posedge rst_all) begin
    if (rst_all)
        track_evt_sync <= 3'b000;
    else
        track_evt_sync <= {track_evt_sync[1:0], track_evt};
end

always @(posedge sd_card_clk or posedge rst_all) begin
    if (rst_all)
        wav_track_sel <= 4'd1;       // 上电默认放第一首（音乐一上电就有）
    else if (track_evt_s) begin
        if (wav_track_sel >= wav_track_cnt)
            wav_track_sel <= 4'd0;
        else
            wav_track_sel <= wav_track_sel + 4'd1;
    end
end

seg_decoder seg_decoder_track(.bin_data(wav_track_sel), .seg_data(track_seg));

reg [3:0] wav_track_sel_d;
wire      wav_track_evt = (wav_track_sel != wav_track_sel_d);
always @(posedge sd_card_clk or posedge rst_all) begin
    if (rst_all)
        wav_track_sel_d <= 4'd1;
    else
        wav_track_sel_d <= wav_track_sel;
end

// ===================== 双击：切转场 / 切字幕页 =====================

key_event_detect #(
    .CLK_FREQ_HZ (100_000_000),
    .WIN_MS      (320)
) u_key1_dbl (
    .clk        (sd_card_clk),
    .rst        (rst_all),
    .short_i    (key1_short),
    .double_evt (key1_dbl),
    .triple_evt ()
);

key_event_detect #(
    .CLK_FREQ_HZ (100_000_000),
    .WIN_MS      (320)
) u_key2_dbl (
    .clk        (sd_card_clk),
    .rst        (rst_all),
    .short_i    (key2_short),
    .double_evt (key2_dbl),
    .triple_evt ()
);

wire img_evt;
reg [1:0] disp_idx_d;
always @(posedge sd_card_clk or posedge rst_all) begin
    if (rst_all) begin
        disp_idx_d <= 2'd0;
        disp_tog   <= 1'b0;
    end else begin
        disp_idx_d <= disp_buf_idx;
        if (disp_buf_idx != disp_idx_d)
            disp_tog <= ~disp_tog;
    end
end

assign img_evt = (disp_buf_idx != disp_idx_d);

effect_ctrl #(
    .CLK_FREQ_HZ (100_000_000),
    .HIDE_MS     (0),
    .PAGE_COUNT  (4)
) u_effect_ctrl (
    .clk         (sd_card_clk),
    .rst         (rst_all),
    .key1_double (key1_dbl),
    .key2_double (key2_dbl),
    .img_evt     (img_evt),
    .trans_mode  (trans_mode),
    .sub_page    (sub_page),
    .sub_active  (sub_active)
);

reg [2:0] trans_mode_sync1, trans_mode_sync;
reg [2:0] sub_page_sync1,  sub_page_sync;
reg       sub_act_sync1,   sub_act_sync;

always @(posedge video_clk or posedge rst_all) begin
    if (rst_all) begin
        trans_mode_sync1 <= 3'd0;
        trans_mode_sync <= 3'd0;
        sub_page_sync1   <= 3'd0;
        sub_page_sync   <= 3'd0;
        sub_act_sync1    <= 1'b0;
        sub_act_sync    <= 1'b0;
    end else begin
        trans_mode_sync1 <= trans_mode;
        trans_mode_sync <= trans_mode_sync1;
        sub_page_sync1   <= sub_page;
        sub_page_sync   <= sub_page_sync1;
        sub_act_sync1    <= sub_active;
        sub_act_sync    <= sub_act_sync1;
    end
end

assign trans_mode_v = trans_mode_sync;
assign sub_page_v   = sub_act_sync ? sub_page_sync : 3'd0;

// ===================== TF 多图扫描与缓存（双缓冲） =====================
sd_card_bmp #(
    .CLK_FREQ_HZ       (100_000_000),
    .SCAN_START_SECTOR (32'd0),
    .SCAN_MAX_SECTOR   (32'd131071),
    .SCAN_TARGET_COUNT (3'd4)
) sd_card_bmp_m0(
    .clk               (sd_card_clk),
    .rst               (rst_all),
    .key_next          (key1_next),
    .key_auto          (key2_auto),
    .state_code        (state_code),
    .img_count         (img_count),
    .O_sd_init_done    (sd_init_done_d),
    .O_sd_retry_cnt    (sd_retry_d),
    .I_wav_track       (wav_track_sel),
    .O_wav_track_cnt   (wav_track_cnt),
    .O_wav_fmt_bad     (wav_fmt_bad),
    .I_wav_need        (wav_need),
    .O_wav_found       (wav_found),
    .O_wav_we          (wav_we),
    .O_wav_data        (wav_data),
    .bmp_width         (16'd640),
    .bmp_height        (16'd480),
    .display_valid     (display_valid),

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

seg_decoder seg_decoder_m0(
    .bin_data          (state_code),
    .seg_data          (seg_data_0)
);

//-------------------------------------------------- 按键诊断显示

reg [6:0] key_s1;
reg [6:0] key_s2;
reg [3:0] key_code;

always @(posedge clk or posedge rst_all) begin
    if (rst_all) begin
        key_s1 <= 7'h7F;
        key_s2 <= 7'h7F;
    end else begin
        key_s1 <= {key7, key6, key5, key4, key3, key2, key1};
        key_s2 <= key_s1;
    end
end

always @(*) begin
    if      (!key_s2[0]) key_code = 4'd1;
    else if (!key_s2[1]) key_code = 4'd2;
    else if (!key_s2[2]) key_code = 4'd3;
    else if (!key_s2[3]) key_code = 4'd4;
    else if (!key_s2[4]) key_code = 4'd5;
    else if (!key_s2[5]) key_code = 4'd6;
    else if (!key_s2[6]) key_code = 4'd7;
    else                 key_code = 4'd0;
end

wire [6:0] key_seg;

reg  [3:0]  key_code_show;
reg  [26:0] key_hold_cnt;

always @(posedge clk or posedge rst_all) begin
    if (rst_all) begin
        key_code_show <= 4'd0;
        key_hold_cnt  <= 27'd0;
    end else if (key_code != 4'd0) begin
        key_code_show <= key_code;
        key_hold_cnt  <= 27'd100_000_000;      // 2s @50MHz
    end else if (key_hold_cnt != 27'd0) begin
        key_hold_cnt  <= key_hold_cnt - 27'd1;
    end else begin
        key_code_show <= 4'd0;
    end
end

seg_decoder seg_decoder_key(
    .bin_data          (key_code_show),
    .seg_data          (key_seg)
);

//-------------------------------------------------- 图片数量显示

reg [2:0] img_cnt_s1;
reg [2:0] img_cnt_s2;

always @(posedge clk or posedge rst_all) begin
    if (rst_all) begin
        img_cnt_s1 <= 3'd0;
        img_cnt_s2 <= 3'd0;
    end else begin
        img_cnt_s1 <= img_count;
        img_cnt_s2 <= img_cnt_s1;
    end
end

wire [6:0] imgcnt_seg;

seg_decoder seg_decoder_imgcnt(
    .bin_data          ({1'b0, img_cnt_s2}),
    .seg_data          (imgcnt_seg)
);

reg [2:0] zoom_lvl_s1;
reg [2:0] zoom_lvl_s2;
wire [6:0] zoom_seg;

always @(posedge clk or posedge rst_all) begin
    if (rst_all) begin
        zoom_lvl_s1 <= 3'd1;
        zoom_lvl_s2 <= 3'd1;
    end else begin
        zoom_lvl_s1 <= zoom_level;
        zoom_lvl_s2 <= zoom_lvl_s1;
    end
end

seg_decoder seg_decoder_zoom(
    .bin_data          ({1'b0, zoom_lvl_s2}),
    .seg_data          (zoom_seg)
);

wire [6:0] trans_seg;
wire [6:0] sub_seg;

seg_decoder seg_decoder_trans(
    .bin_data          ({1'b0, trans_mode_sync}),
    .seg_data          (trans_seg)
);

seg_decoder seg_decoder_sub(
    .bin_data          ({1'b0, sub_page_sync}),
    .seg_data          (sub_seg)
);

wire       flip_h;
wire       flip_v;
wire [1:0] flip_mode;
wire [6:0] flip_seg;

reg  [3:0] imgok_cnt;
wire [6:0] imgok_seg;

always @(posedge sd_card_clk or posedge rst_all) begin
    if (rst_all)
        imgok_cnt <= 4'd0;
    else if (img_evt)
        imgok_cnt <= (imgok_cnt == 4'd9) ? 4'd0 : (imgok_cnt + 4'd1);
end

seg_decoder seg_decoder_imgok(
    .bin_data          (imgok_cnt),
    .seg_data          (imgok_seg)
);

seg_decoder seg_decoder_flip(
    .bin_data          ({2'b00, flip_mode}),
    .seg_data          (flip_seg)
);

reg [1:0] filt_s1, filt_s2;
wire [6:0] filt_seg;
always @(posedge sd_card_clk or posedge rst_all) begin
    if (rst_all) begin
        filt_s1 <= 2'd0;
        filt_s2 <= 2'd0;
    end else begin
        filt_s1 <= filter_mode;
        filt_s2 <= filt_s1;
    end
end
seg_decoder seg_decoder_filter(.bin_data({2'd0, filt_s2}), .seg_data(filt_seg));

seg_decoder seg_decoder_sdinit(.bin_data({3'd0, sd_init_done_d}), .seg_data(sdinit_seg));
seg_decoder seg_decoder_retry (.bin_data({2'd0, sd_retry_d}),       .seg_data(retry_seg));
seg_decoder seg_decoder_trkcnt(.bin_data(wav_track_cnt),             .seg_data(trkcnt_seg));
seg_decoder seg_decoder_dvalid(.bin_data({3'd0, display_valid}),    .seg_data(dvalid_seg));
seg_decoder seg_decoder_rst   (.bin_data({3'd0, rst_all}),          .seg_data(rst_seg));
seg_decoder seg_decoder_wavf  (.bin_data({3'd0, wav_found}),        .seg_data(wavf_seg));

seg_scan seg_scan_m0(
    .clk               (clk),
    .rst_n             (rst_n),
    .seg_sel           (seg_sel),
    .seg_data          (seg_data),
    .seg_data_0        (DIAG_MODE ? {1'b1,sdinit_seg} : {1'b1,flip_seg}),    // 1: SD 初始化完成
    .seg_data_1        (DIAG_MODE ? (wav_fmt_bad ? 7'b1111001 : {1'b1,trkcnt_seg}) : {1'b1,filt_seg}),
    .seg_data_2        ({1'b1,key_seg}),                                     // 3: 按键诊断
    .seg_data_3        ({1'b1,imgcnt_seg}),                                  // 4: 图片数
    .seg_data_4        (DIAG_MODE ? {1'b1,dvalid_seg} : {1'b1,sub_seg}),
    .seg_data_5        (DIAG_MODE ? {1'b1,rst_seg}    : {1'b1,trans_seg}),   // 6: rst_all / 转场档
    .seg_data_6        ({1'b1,track_seg}),
    .seg_data_7        ({1'b1,seg_data_0})                                   // 8: SD 状态码
);

// ===================== 原图像时序（只保留时序产生） =====================
video_timing_data video_timing_data_m0(
    .video_clk         (video_clk),
    .rst               (rst_all),
    .read_req          (),
    .read_req_ack      (1'b0),
    .hs                (hs_0),
    .vs                (vs_0),
    .de                (de_0)
);

// ===================== 图片翻转（SW4 / C5，四档循环） =====================

flip_ctrl #(
    .CNT_DEB   (20'd400_000)            // 约 16ms @25MHz
) u_flip_ctrl (
    .clk       (video_clk),
    .rst       (rst_all),
    .key_flip  (key7),
    .flip_h    (flip_h),
    .flip_v    (flip_v),
    .flip_mode (flip_mode)
);

// ===================== 图像缩放：按行取源图 + 双 bank 行缓存 =====================
video_zoom #(
    .H_ACTIVE          (640),
    .V_ACTIVE          (480),
    .BUF0_ADDR         (BUF0_ADDR),
    .BUF1_ADDR         (BUF1_ADDR)
) video_zoom_m0(
    .video_clk         (video_clk),
    .rst               (rst_all),

    .hs_i              (hs_0),
    .vs_i              (vs_0),
    .de_i              (de_0),

    .hs_o              (hs),
    .vs_o              (vs),
    .de_o              (de),
    .rgb_o             (zoom_rgb),

    .buf_sel           (disp_buf_v),

    .line_req          (zoom_line_req),
    .line_ack          (zoom_line_ack),
    .line_addr         (zoom_line_addr),
    .line_empty        (video_read_empty),
    .line_ren          (zoom_line_ren),
    .line_rdata        (zoom_line_rdata),

    .zoom_in_tog       (zoom_in_tog),
    .zoom_out_tog      (zoom_out_tog),
    .zoom_level        (zoom_level),

    .flip_h_i          (flip_h),
    .flip_v_i          (flip_v)
);

// ===================== 转场（同时负责显示缓冲切换） =====================

video_transition #(
    .H_ACTIVE          (640),
    .V_ACTIVE          (480),
    .HALF_FRAMES       (18),           // 18+18 帧 ≈ 0.6s
    .X0                (0)
) u_video_transition (
    .clk               (video_clk),
    .rst               (rst_all),

    .disp_tog          (disp_tog),
    .disp_idx          (disp_buf_idx[0]),
    .disp_valid        (display_valid),
    .disp_buf          (disp_buf_v),
    .mode              (trans_mode_v),

    .hs_i              (hs),
    .vs_i              (vs),
    .de_i              (de),
    .rgb_i             (zoom_rgb),

    .hs_o              (trans_hs),
    .vs_o              (trans_vs),
    .de_o              (trans_de),
    .rgb_o             (trans_rgb),

    .busy              (trans_busy)
);

video_bright_contrast u_video_bright_contrast (
    .I_pix_clk (video_clk),
    .I_rst     (rst_all),
    .I_de      (trans_de),
    .I_vs      (trans_vs),
    .I_rgb     (trans_rgb),
    .I_bright  (adj_bright),
    .I_gain    (adj_gain),
    .I_filter  (filter_mode),
    .O_rgb     (adj_rgb),
    .O_de      (adj_de),
    .O_vs      (adj_vs)
);

reg [1:0] adj_hs_d;
always @(posedge video_clk or posedge rst_all) begin
    if (rst_all)
        adj_hs_d <= 2'b00;
    else
        adj_hs_d <= {adj_hs_d[0], trans_hs};
end
assign adj_hs = adj_hs_d[1];

adj_key_ctrl u_adj_key_ctrl (
    .I_clk     (video_clk),
    .I_rst     (rst_all),
    .I_key     ({key6, key5, key4, key3}),
    .O_bright  (adj_bright),
    .O_gain    (adj_gain),
    .O_filter  (filter_mode),
    .O_track_evt (track_evt),
    .O_show    (adj_show)
);

// ===================== 字幕（底部半透明黑条 + 点阵汉字） =====================
subtitle_overlay #(
    .H_ACTIVE          (640),
    .V_ACTIVE          (480),
    .BAND_Y            (400),
    .BAND_H            (60),
    .LINE_Y0           (404),
    .LINE_H            (28),            // 第 2 行 432..455
    .CHAR_W            (24),
    .PAGE_NUM          (4),
    .LINE_W            (3)              // 8 行文本 -> 3bit 行号
) u_subtitle_overlay (
    .clk               (video_clk),
    .rst               (rst_all),
    .page              (sub_page_v),

    .hs_i              (adj_hs),
    .vs_i              (adj_vs),
    .de_i              (adj_de),
    .rgb_i             (adj_rgb),

    .hs_o              (sub_hs),
    .vs_o              (sub_vs),
    .de_o              (sub_de),
    .rgb_o             (sub_rgb)
);

// ===================== 参数 OSD（亮度/对比度数值） =====================

adj_osd u_adj_osd (
    .I_pix_clk (video_clk),
    .I_rst     (rst_all),
    .I_de      (sub_de),
    .I_vs      (sub_vs),
    .I_rgb     (sub_rgb),
    .I_bright  (adj_bright),
    .I_gain    (adj_gain),
    .I_active  (adj_show),
    .O_rgb     (osd_rgb)
);

// ===================== 音频波形小窗口（右上角叠加） =====================
audio_wave #(
    .H_ACTIVE          (640),
    .X0                (430),
    .Y0                (10),
    .W                 (200),
    .H                 (72),
    .NB                (8),
    .BARS              (16),
    .PITCH             (12),
    .BARW              (8)
) u_audio_wave (
    .clk               (video_clk),
    .rst               (rst_all),
    .audio_l           (audio_left_data),
    .audio_valid       (audio_valid),
    .hs_i              (sub_hs),
    .vs_i              (sub_vs),
    .de_i              (sub_de),
    .rgb_i             (osd_rgb),
    .hs_o              (wave_hs),
    .vs_o              (wave_vs),
    .de_o              (wave_de),
    .rgb_o             (wave_rgb)
);

reg [1:0] dv_v;
always @(posedge video_clk or posedge rst_all) begin
    if (rst_all)
        dv_v <= 2'b00;
    else
        dv_v <= {dv_v[0], display_valid};
end

wire [23:0] boot_rgb;

boot_pattern #(
    .H_ACTIVE (640),
    .V_ACTIVE (480)
) u_boot_pattern (
    .clk    (video_clk),
    .rst    (rst_all),
    .hs_i   (adj_hs),
    .vs_i   (adj_vs),
    .de_i   (adj_de),
    .rgb_o  (boot_rgb)
);

assign vout_data = dv_v[1] ? wave_rgb : boot_rgb;

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
    .read_empty        (video_read_empty),

    .read_clk          (video_clk),
    .read_req          (zoom_line_req),
    .read_req_ack      (zoom_line_ack),
    .read_finish       (),
    .read_addr_0       (zoom_line_addr),
    .read_addr_1       (21'd0),
    .read_addr_2       (21'd0),
    .read_addr_3       (21'd0),
    .read_addr_index   (2'd0),
    .read_len          (21'd640),
    .read_en           (zoom_line_ren),
    .read_data         (zoom_line_rdata),

    .App_wr_en         (App_wr_en),
    .App_wr_addr       (App_wr_addr),
    .App_wr_din        (App_wr_din),
    .App_wr_dm         (App_wr_dm),

    .write_clk         (sd_card_clk),
    .write_req         (sd_card_write_req),
    .write_req_ack     (sd_card_write_req_ack),
    .write_finish      (frame_write_finish),
    .write_addr_0      (wr_addr_0_c),
    .write_addr_1      (wr_addr_1_c),
    .write_addr_2      (21'd0),
    .write_addr_3      (21'd0),
    .write_addr_index  (write_buf_idx),
    .write_len         (wr_len_c),
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

// ===================== 音频：《东南苦行山》旋律（ROM 音符表） =====================

hdmi_audio_melody_i2s_64fs #(
    .BPM       (72),        // 速度
    .NOTE_NUM  (142)
) u_hdmi_audio_melody_i2s_64fs (
    .I_mclk      (audio_mclk),
    .I_rst       (rst_all),
    .O_i2s_BCLK  (audio_i2s_bclk),
    .O_i2s_LRCK  (audio_i2s_lrck),
    .O_i2s_DOUT  (audio_i2s_dout),
    .I_wav_wr_clk (sd_card_clk),
    .I_wav_wr_en  (wav_we),
    .I_wav_wr_data(wav_data),
    .O_wav_need   (wav_need),
    .I_wav_only   (wav_track_sel != 4'd0),
    .I_wav_flush  (wav_track_evt),
    .O_wav_mode   (wav_mode)
);

I2S_receiver u_I2S_receiver(
    .I_clk              (video_clk),
    .I_rst              (rst_all),
    .I_i2s_BCLK         (audio_i2s_bclk),
    .I_i2s_LRCK         (audio_i2s_lrck),
    .I_i2s_DOUT         (audio_i2s_dout),
    .O_audio_valid      (audio_valid),
    .O_audio_left_data  (audio_left_data),
    .O_audio_right_data (audio_right_data)
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

// ===================== RGB/DE 转 AXIS 视频 =====================
video_rgb_to_axis_640x480 u_video_rgb_to_axis_640x480(
    .I_clk         (video_clk),
    .I_rst         (rst_all),
    .I_vs          (wave_vs),
    .I_de          (wave_de),
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

// ===================== 带音频的 HDMI 1.4b 发射 =====================
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

module sd_card_bmp #(
    parameter integer CLK_FREQ_HZ       = 100_000_000,
    parameter [31:0]  SCAN_START_SECTOR = 32'd0,
    parameter [31:0]  SCAN_MAX_SECTOR   = 32'd131071,
    parameter [2:0]   SCAN_TARGET_COUNT = 3'd4
)(
    input                       clk,
    input                       rst,
    input                       key_next,
    input                       key_auto,
    input  [15:0]               bmp_width,
    input  [15:0]               bmp_height,
    output reg                  display_valid,
    output      [3:0]           state_code,
    output      [2:0]           img_count,

    // ---- 诊断用（接数码管）----
    output wire                 O_sd_init_done,   // 1 = SD 卡初始化完成
    output wire [1:0]           O_sd_retry_cnt,   // 看门狗已经重试了几次

    input  wire [3:0]           I_wav_track,
    output wire [3:0]           O_wav_track_cnt,  // 卡上共找到几首
    input  wire                 I_wav_need,
    output wire                 O_wav_found,      // 已经在卡上找到 WAV 文件
    output wire                 O_wav_we,         // 写一个 24bit 样点到音频缓冲
    output wire [23:0]          O_wav_data,
    output wire                 O_wav_fmt_bad,

    input                       write_finish_toggle,
    output reg [1:0]            write_buf_idx,
    output reg [1:0]            disp_buf_idx,

    output                      write_req,
    input                       write_req_ack,
    output                      write_en,
    output [31:0]               write_data,
    output                      SD_nCS,
    output                      SD_DCLK,
    output                      SD_MOSI,
    input                       SD_MISO
);

wire key_next_press;
wire key_auto_press;

wire             sd_sec_read;
wire [31:0]      sd_sec_read_addr;
wire [7:0]       sd_sec_read_data;
wire             sd_sec_read_data_valid;
wire             sd_sec_read_end;
wire [3:0]       state_code_i;
wire             bmp_data_wr_en;
wire [23:0]      bmp_data;
wire             sd_init_done;
wire             bmp_ready;
wire             scan_done;
wire             scan_found_valid;
wire [31:0]      scan_found_sector;
wire [2:0]       scan_found_total;

wire        bmp_req, bmp_dvld, bmp_end;
wire [31:0] bmp_addr;
wire [7:0]  bmp_byte;
wire        wav_req, wav_dvld, wav_end, wav_grant, wav_found;
wire [3:0]  wav_track_cnt;
wire [31:0] wav_addr;
wire [7:0]  wav_byte;
wire        wav_we_i;
wire [23:0] wav_data_i;
wire        sd_sec_read_end_raw;
wire        wav_need_s;

reg  [1:0]  sd_owner;          // 0=空闲 1=bmp 2=wav
reg  [19:0] owner_tmo;
reg  [2:0]  wav_need_sync;

reg              scan_start_pulse;
reg              load_start_pulse;
reg [31:0]       load_sector;
reg              scan_kicked;
reg              first_image_committed;
reg              auto_play_en;
reg [31:0]       auto_cnt;
reg [2:0]        img_found_count;
reg [1:0]        img_idx;              // 当前真正显示中的图片编号
reg [1:0]        load_idx;             // 当前正在写入的图片编号
reg [1:0]        pending_buf_idx;      // 当前正在写入的目标缓冲区
reg [31:0]       img_sector0;
reg [31:0]       img_sector1;
reg [31:0]       img_sector2;
reg [31:0]       img_sector3;
reg              next_req_pending;
reg              load_busy;
reg [31:0]       load_timeout_cnt;

reg              load_abort;

reg              source_done_seen;
reg              write_done_seen;

reg [2:0]        wrfin_tgl_sync;
wire             write_finish_pulse;

wire auto_tick;
wire [1:0] next_from_current;

assign write_en   = bmp_data_wr_en;
assign write_data = {bmp_data[23:16], bmp_data[15:8], bmp_data[7:0], 8'b0};

assign auto_tick  = (auto_cnt == (CLK_FREQ_HZ / 4 - 1));
assign next_from_current = next_index_limited(img_idx, img_found_count);
assign write_finish_pulse = wrfin_tgl_sync[2] ^ wrfin_tgl_sync[1];
assign state_code = state_code_i;
assign img_count  = img_found_count;

key_press_debounce #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .DEBOUNCE_MS (10)
) u_key_next (
    .clk        (clk),
    .rst        (rst),
    .button_in  (key_next),
    .press_pulse(key_next_press)
);

key_press_debounce #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .DEBOUNCE_MS (10)
) u_key_auto (
    .clk        (clk),
    .rst        (rst),
    .button_in  (key_auto),
    .press_pulse(key_auto_press)
);

localparam [29:0] INIT_WD_MAX = 30'd1_000_000_000;   // 10s @100MHz
localparam [8:0]  RETRY_LEN   = 9'd255;              // 复位宽度 256 拍
localparam [1:0]  RETRY_MAX   = 2'd3;

reg [29:0] init_wd;
reg [8:0]  retry_cnt;
reg [1:0]  retry_times;

wire sd_retry = (retry_cnt != 9'd0);
wire sd_rst   = rst | sd_retry;                    // SD 控制器/读取器的复位

always @(posedge clk or posedge rst) begin
    if (rst) begin
        init_wd     <= 30'd0;
        retry_cnt   <= 9'd0;
        retry_times <= 2'd0;
    end else if (sd_init_done) begin
        init_wd     <= 30'd0;
        retry_cnt   <= 9'd0;
        retry_times <= 2'd0;
    end else if (retry_cnt != 9'd0) begin
        retry_cnt <= retry_cnt - 9'd1;
    end else if ((init_wd >= INIT_WD_MAX) && (retry_times < RETRY_MAX)) begin
        init_wd     <= 30'd0;
        retry_cnt   <= RETRY_LEN;
        retry_times <= retry_times + 2'd1;
    end else if (init_wd < INIT_WD_MAX) begin
        init_wd <= init_wd + 30'd1;
    end
end

function [1:0] next_index_limited;
    input [1:0] cur;
    input [2:0] count;
    begin
        case (count)
            3'd0: next_index_limited = 2'd0;
            3'd1: next_index_limited = 2'd0;
            3'd2: next_index_limited = (cur == 2'd1) ? 2'd0 : (cur + 2'd1);
            3'd3: next_index_limited = (cur == 2'd2) ? 2'd0 : (cur + 2'd1);
            default: next_index_limited = (cur == 2'd3) ? 2'd0 : (cur + 2'd1);
        endcase
    end
endfunction

function [31:0] sector_lut;
    input [1:0] idx;
    begin
        case (idx)
            2'd0: sector_lut = img_sector0;
            2'd1: sector_lut = img_sector1;
            2'd2: sector_lut = img_sector2;
            2'd3: sector_lut = img_sector3;
            default: sector_lut = img_sector0;
        endcase
    end
endfunction

function [1:0] next_buf_lut;
    input [1:0] cur_disp_buf;
    input       valid_now;
    begin
        if (!valid_now)
            next_buf_lut = 2'd0;                 // 首图固定写 buffer0
        else if (cur_disp_buf == 2'd0)
            next_buf_lut = 2'd1;
        else
            next_buf_lut = 2'd0;
    end
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        wrfin_tgl_sync        <= 3'b000;
        scan_start_pulse      <= 1'b0;
        load_start_pulse      <= 1'b0;
        load_sector           <= 32'd0;
        scan_kicked           <= 1'b0;
        first_image_committed <= 1'b0;
        auto_play_en          <= 1'b0;
        auto_cnt              <= 32'd0;
        img_found_count       <= 3'd0;
        img_idx               <= 2'd0;
        load_idx              <= 2'd0;
        pending_buf_idx       <= 2'd0;
        write_buf_idx         <= 2'd0;
        disp_buf_idx          <= 2'd0;
        img_sector0           <= 32'd0;
        img_sector1           <= 32'd0;
        img_sector2           <= 32'd0;
        img_sector3           <= 32'd0;
        next_req_pending      <= 1'b0;
        load_busy             <= 1'b0;
        load_timeout_cnt      <= 32'd0;
        load_abort            <= 1'b0;
        source_done_seen      <= 1'b0;
        write_done_seen       <= 1'b0;
        display_valid         <= 1'b0;
    end else begin
        wrfin_tgl_sync   <= {wrfin_tgl_sync[1:0], write_finish_toggle};
        scan_start_pulse <= 1'b0;
        load_start_pulse <= 1'b0;
        load_abort       <= 1'b0;

        if (!sd_init_done) begin
            scan_kicked           <= 1'b0;
            first_image_committed <= 1'b0;
            auto_play_en          <= 1'b0;
            auto_cnt              <= 32'd0;
            img_found_count       <= 3'd0;
            img_idx               <= 2'd0;
            load_idx              <= 2'd0;
            pending_buf_idx       <= 2'd0;
            write_buf_idx         <= 2'd0;
            disp_buf_idx          <= 2'd0;
            img_sector0           <= 32'd0;
            img_sector1           <= 32'd0;
            img_sector2           <= 32'd0;
            img_sector3           <= 32'd0;
            next_req_pending      <= 1'b0;
            load_busy             <= 1'b0;
            load_timeout_cnt      <= 32'd0;
            load_abort            <= 1'b0;
            source_done_seen      <= 1'b0;
            write_done_seen       <= 1'b0;
            display_valid         <= 1'b0;
        end else begin

            if (scan_found_valid) begin
                case (img_found_count)
                    3'd0: img_sector0 <= scan_found_sector;
                    3'd1: img_sector1 <= scan_found_sector;
                    3'd2: img_sector2 <= scan_found_sector;
                    3'd3: img_sector3 <= scan_found_sector;
                    default: ;
                endcase

                if (img_found_count < 3'd4)
                    img_found_count <= img_found_count + 3'd1;
            end

            if (load_busy && bmp_ready)
                source_done_seen <= 1'b1;

            if (load_busy && write_finish_pulse)
                write_done_seen <= 1'b1;

            if (load_busy && source_done_seen && write_done_seen) begin
                load_busy             <= 1'b0;
                load_timeout_cnt      <= 32'd0;
                source_done_seen      <= 1'b0;
                write_done_seen       <= 1'b0;
                disp_buf_idx          <= pending_buf_idx;
                img_idx               <= load_idx;
                display_valid         <= 1'b1;
                first_image_committed <= 1'b1;
            end else if (load_busy) begin
                if (load_timeout_cnt > 32'd200_000_000) begin

                    load_busy             <= 1'b0;
                    load_timeout_cnt      <= 32'd0;
                    source_done_seen      <= 1'b0;
                    write_done_seen       <= 1'b0;
                    load_abort            <= 1'b1;
                    img_idx               <= load_idx;

                end else begin
                    load_timeout_cnt <= load_timeout_cnt + 32'd1;
                end
            end else begin
                load_timeout_cnt <= 32'd0;
            end

            if (!scan_kicked && bmp_ready) begin
                scan_start_pulse      <= 1'b1;
                scan_kicked           <= 1'b1;
                first_image_committed <= 1'b0;
                auto_play_en          <= 1'b0;
                auto_cnt              <= 32'd0;
                img_found_count       <= 3'd0;
                img_idx               <= 2'd0;
                load_idx              <= 2'd0;
                pending_buf_idx       <= 2'd0;
                write_buf_idx         <= 2'd0;
                disp_buf_idx          <= 2'd0;
                next_req_pending      <= 1'b0;
                display_valid         <= 1'b0;
                load_busy             <= 1'b0;
                source_done_seen      <= 1'b0;
                write_done_seen       <= 1'b0;
            end else begin

                if (key_next_press && scan_done && (img_found_count > 3'd0))
                    next_req_pending <= 1'b1;

                // 自动播放开/关
                if (key_auto_press && scan_done && (img_found_count > 3'd1)) begin
                    auto_play_en <= ~auto_play_en;
                    auto_cnt     <= 32'd0;
                end

                if (scan_done && auto_play_en && display_valid && !load_busy && first_image_committed && (img_found_count > 3'd1)) begin
                    if (auto_tick)
                        auto_cnt <= 32'd0;
                    else
                        auto_cnt <= auto_cnt + 32'd1;
                end else begin
                    auto_cnt <= 32'd0;
                end

                // 首图自动加载到 buffer0
                if (scan_done && !first_image_committed && bmp_ready && !load_busy && (img_found_count != 3'd0)) begin
                    load_idx         <= 2'd0;
                    load_sector      <= img_sector0;
                    pending_buf_idx  <= 2'd0;
                    write_buf_idx    <= 2'd0;
                    load_start_pulse <= 1'b1;
                    load_busy        <= 1'b1;
                    source_done_seen <= 1'b0;
                    write_done_seen  <= 1'b0;
                    auto_cnt         <= 32'd0;
                end

                else if (scan_done && bmp_ready && display_valid && !load_busy && next_req_pending && (img_found_count != 3'd0)) begin
                    load_idx         <= next_from_current;
                    load_sector      <= sector_lut(next_from_current);
                    pending_buf_idx  <= next_buf_lut(disp_buf_idx, display_valid);
                    write_buf_idx    <= next_buf_lut(disp_buf_idx, display_valid);
                    load_start_pulse <= 1'b1;
                    load_busy        <= 1'b1;
                    source_done_seen <= 1'b0;
                    write_done_seen  <= 1'b0;
                    next_req_pending <= 1'b0;
                    auto_cnt         <= 32'd0;
                end

                else if (scan_done && bmp_ready && display_valid && !load_busy && auto_play_en && auto_tick && (img_found_count > 3'd1)) begin
                    load_idx         <= next_from_current;
                    load_sector      <= sector_lut(next_from_current);
                    pending_buf_idx  <= next_buf_lut(disp_buf_idx, display_valid);
                    write_buf_idx    <= next_buf_lut(disp_buf_idx, display_valid);
                    load_start_pulse <= 1'b1;
                    load_busy        <= 1'b1;
                    source_done_seen <= 1'b0;
                    write_done_seen  <= 1'b0;
                    auto_cnt         <= 32'd0;
                end
            end
        end
    end
end

bmp_read bmp_read_m0(
    .clk                    (clk),
    .rst                    (sd_rst),
    .ready                  (bmp_ready),

    .scan_start             (scan_start_pulse),
    .scan_start_sector      (SCAN_START_SECTOR),
    .scan_max_sector        (SCAN_MAX_SECTOR),
    .scan_target_count      (SCAN_TARGET_COUNT),
    .scan_done              (scan_done),
    .scan_found_valid       (scan_found_valid),
    .scan_found_sector      (scan_found_sector),
    .scan_found_total       (scan_found_total),

    .load_start             (load_start_pulse),
    .load_abort             (load_abort),
    .load_sector            (load_sector),

    .sd_init_done           (sd_init_done),
    .state_code             (state_code_i),
    .bmp_width              (bmp_width),
    .bmp_height             (bmp_height),
    .write_req              (write_req),
    .write_req_ack          (write_req_ack),
    .sd_sec_read            (bmp_req),
    .sd_sec_read_addr       (bmp_addr),
    .sd_sec_read_data       (bmp_byte),
    .sd_sec_read_data_valid (bmp_dvld),
    .sd_sec_read_end        (bmp_end),
    .bmp_data_wr_en         (bmp_data_wr_en),
    .bmp_data               (bmp_data)
);

always @(posedge clk or posedge rst) begin
    if (rst)
        wav_need_sync <= 3'b000;
    else
        wav_need_sync <= {wav_need_sync[1:0], I_wav_need};
end
assign wav_need_s = wav_need_sync[2];

// 一次只让一个主人用 SD
always @(posedge clk or posedge rst) begin
    if (rst) begin
        sd_owner  <= 2'd0;
        owner_tmo <= 20'd0;
    end else if (sd_owner == 2'd0) begin
        owner_tmo <= 20'd0;
        if (wav_req)
            sd_owner <= 2'd2;
        else if (bmp_req)
            sd_owner <= 2'd1;
    end else begin
        owner_tmo <= owner_tmo + 20'd1;

        if (sd_sec_read_end || owner_tmo[19])
            sd_owner <= 2'd0;
    end
end

assign wav_grant        = (sd_owner == 2'd2);
assign sd_sec_read      = (sd_owner != 2'd0);
assign sd_sec_read_addr = (sd_owner == 2'd2) ? wav_addr : bmp_addr;

assign bmp_byte = sd_sec_read_data;
assign bmp_dvld = sd_sec_read_data_valid && (sd_owner == 2'd1);
assign bmp_end  = sd_sec_read_end_raw && (sd_owner == 2'd1);

assign wav_byte = sd_sec_read_data;
assign wav_dvld = sd_sec_read_data_valid && (sd_owner == 2'd2);
assign wav_end  = sd_sec_read_end_raw && (sd_owner == 2'd2);

assign sd_sec_read_end = (sd_owner == 2'd1) ? bmp_end :
                         (sd_owner == 2'd2) ? wav_end : 1'b0;

assign O_wav_track_cnt = wav_track_cnt;
assign O_sd_init_done = sd_init_done;
assign O_sd_retry_cnt = retry_times;

assign O_wav_found = wav_found;
assign O_wav_we    = wav_we_i;
assign O_wav_data  = wav_data_i;

wav_reader #(
    .SCAN_START (SCAN_START_SECTOR),
    .SCAN_MAX   (SCAN_MAX_SECTOR)
) wav_reader_m0 (
    .clk        (clk),
    .rst        (sd_rst),
    .enable     (sd_init_done),
    .need       (wav_need_s),
    .I_track    (I_wav_track),
    .req        (wav_req),
    .addr       (wav_addr),
    .grant      (wav_grant),
    .dvld       (wav_dvld),
    .data       (wav_byte),
    .end_of_sec (wav_end),
    .we         (wav_we_i),
    .wdata      (wav_data_i),
    .found      (wav_found),
    .O_count    (wav_track_cnt),
    .O_fmt_bad  (O_wav_fmt_bad)
);

sd_card_top sd_card_top_m0(
    .clk                    (clk),
    .rst                    (sd_rst),
    .SD_nCS                 (SD_nCS),
    .SD_DCLK                (SD_DCLK),
    .SD_MOSI                (SD_MOSI),
    .SD_MISO                (SD_MISO),
    .sd_init_done           (sd_init_done),
    .sd_sec_read            (sd_sec_read),
    .sd_sec_read_addr       (sd_sec_read_addr),
    .sd_sec_read_data       (sd_sec_read_data),
    .sd_sec_read_data_valid (sd_sec_read_data_valid),
    .sd_sec_read_end        (sd_sec_read_end_raw),
    .sd_sec_write           (1'b0),
    .sd_sec_write_addr      (32'd0),
    .sd_sec_write_data      (),
    .sd_sec_write_data_req  (),
    .sd_sec_write_end       ()
);

endmodule

module key_press_debounce #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer DEBOUNCE_MS = 20
)(
    input  wire clk,
    input  wire rst,
    input  wire button_in,
    output reg  press_pulse
);

localparam integer DEBOUNCE_CYCLES = (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;

reg button_sync0;
reg button_sync1;
reg button_stable;
reg [31:0] cnt;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        button_sync0  <= 1'b1;
        button_sync1  <= 1'b1;
        button_stable <= 1'b1;
        cnt           <= 32'd0;
        press_pulse   <= 1'b0;
    end else begin
        button_sync0 <= button_in;
        button_sync1 <= button_sync0;
        press_pulse  <= 1'b0;

        if (button_sync1 == button_stable) begin
            cnt <= 32'd0;
        end else begin
            if (cnt >= DEBOUNCE_CYCLES - 1) begin
                if (button_stable && !button_sync1)
                    press_pulse <= 1'b1;
                button_stable <= button_sync1;
                cnt           <= 32'd0;
            end else begin
                cnt <= cnt + 32'd1;
            end
        end
    end
end

endmodule

module wav_reader #(
    parameter [31:0] SCAN_START  = 32'd0,
    parameter [31:0] SCAN_MAX    = 32'd131071,
    parameter [15:0] DIR_SEC_MAX = 16'd64,
    parameter integer MAX_TRACKS = 8               // 最多认几首 WAV
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,        // sd_init_done
    input  wire        need,          // 音频缓冲偏空
    input  wire [3:0]  I_track,

    output reg         req,
    output reg  [31:0] addr,
    input  wire        grant,
    input  wire        dvld,
    input  wire [7:0]  data,
    input  wire        end_of_sec,

    output reg         we,
    output reg  [23:0] wdata,
    output reg         found,
    output reg         scan_mode,     // 1 = 走的是逐扇区扫描兜底
    output reg         O_fmt_bad,
    output wire [3:0]  O_count        // 卡上找到了几首
);
localparam [3:0] S_MBR       = 4'd0,
                 S_MBR_GET   = 4'd1,
                 S_BPB       = 4'd2,
                 S_BPB_GET   = 4'd3,
                 S_DIR       = 4'd4,
                 S_DIR_GET   = 4'd5,
                 S_SCAN      = 4'd6,
                 S_SCAN_GET  = 4'd7,
                 S_ARM       = 4'd8,
                 S_DATA_WAIT = 4'd9,
                 S_DATA_GET  = 4'd10;

reg  [3:0]  st;

// ---------------- 曲目表 ----------------
reg  [31:0] t_clus [0:MAX_TRACKS-1];   // 起始扇区
reg  [31:0] t_size [0:MAX_TRACKS-1];   // 文件长度
reg  [3:0]  t_cnt;

// ---------------- 当前曲目 ----------------
reg  [31:0] file_sec;
reg  [31:0] file_len;
reg  [31:0] pcm_start;
reg  [31:0] cur_sec;
reg  [31:0] byte_abs;

reg  [15:0] fmt_ch;
reg  [31:0] fmt_rate;
reg  [15:0] fmt_bits;
reg         fmt_seen;                    // 已经读到第 35 字节
wire        fmt_ok = (fmt_ch == 16'd1) && (fmt_rate == 32'd48000) && (fmt_bits == 16'd16);
reg         stream_off;           // 1 = 放内置旋律（不送数据）
reg  [3:0]  track_d;              // 上一拍的曲目号（用来检测切换）
reg  [31:0] pick_sec;
reg  [31:0] pick_len;
reg  [31:0] pick_off;

// ---------------- FAT 解析 ----------------
reg  [9:0]  fbi;
reg  [31:0] part_start;
reg  [7:0]  ptype;
reg  [31:0] plba;
reg  [15:0] bps, rsvd, root_ent, fat16;
reg  [7:0]  spc, nfats;
reg  [31:0] fat32sz, root_clus;
reg  [31:0] data_start, dir_start;
reg  [15:0] dir_cnt, dir_k;
reg  [31:0] fat_sz;

reg         e_ok;
reg  [7:0]  e_ext0, e_ext1, e_ext2, e_attr;
reg  [15:0] e_chi, e_clo;
reg  [31:0] e_size;
reg         dir_done;             // 目录扫完了

// ---------------- 兜底扫描 ----------------
reg  [31:0] scan_sec;
reg  [7:0]  sh0, sh1, sh2, sh3;
reg  [31:0] s_file_len;
reg         got_data, riok, waok;

// ---------------- 数据阶段 ----------------
reg         have_lo;
reg  [7:0]  lo_byte;

wire [31:0] sh_val = {data, sh0, sh1, sh2};

assign O_count = t_cnt;

// 扇区地址
always @(*) begin
    case (st)
        S_MBR, S_MBR_GET  : addr = 32'd0;
        S_BPB, S_BPB_GET  : addr = part_start;
        S_DIR, S_DIR_GET  : addr = dir_start + {16'd0, dir_k};
        S_SCAN, S_SCAN_GET: addr = scan_sec;
        default           : addr = cur_sec;
    endcase
end

// 曲目表查找（组合）
always @(*) begin
    if ((I_track != 4'd0) && (I_track <= t_cnt)) begin
        pick_sec = t_clus[I_track - 4'd1];
        pick_len = t_size[I_track - 4'd1];
        pick_off = 32'd44;
    end else begin
        pick_sec = 32'd0;
        pick_len = 32'd0;
        pick_off = 32'd0;
    end
end

integer k;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        st         <= S_MBR;
        req        <= 1'b0;
        we         <= 1'b0;
        wdata      <= 24'd0;
        found      <= 1'b0;
        scan_mode  <= 1'b0;
        t_cnt      <= 4'd0;
        for (k = 0; k < MAX_TRACKS; k = k + 1) begin
            t_clus[k] <= 32'd0;
            t_size[k] <= 32'd0;
        end
        file_sec   <= 32'd0;
        file_len   <= 32'd0;
        pcm_start  <= 32'd0;
        cur_sec    <= 32'd0;
        byte_abs   <= 32'd0;
        stream_off <= 1'b1;
        track_d    <= 4'd0;
        fbi        <= 10'd0;
        part_start <= 32'd0;
        ptype      <= 8'd0;
        plba       <= 32'd0;
        bps        <= 16'd0;
        spc        <= 8'd0;
        rsvd       <= 16'd0;
        nfats      <= 8'd0;
        root_ent   <= 16'd0;
        fat16      <= 16'd0;
        fat32sz    <= 32'd0;
        root_clus  <= 32'd0;
        data_start <= 32'd0;
        dir_start  <= 32'd0;
        dir_cnt    <= 16'd0;
        dir_k      <= 16'd0;
        fat_sz     <= 32'd0;
        e_ok       <= 1'b0;
        e_ext0     <= 8'd0;
        e_ext1     <= 8'd0;
        e_ext2     <= 8'd0;
        e_attr     <= 8'd0;
        e_chi      <= 16'd0;
        e_clo      <= 16'd0;
        e_size     <= 32'd0;
        dir_done   <= 1'b0;
        scan_sec   <= SCAN_START;
        sh0 <= 8'd0; sh1 <= 8'd0; sh2 <= 8'd0; sh3 <= 8'd0;
        s_file_len <= 32'd0;
        got_data   <= 1'b0;
        riok       <= 1'b0;
        waok       <= 1'b0;
        have_lo    <= 1'b0;
        lo_byte    <= 8'd0;
    end else begin
        we <= 1'b0;

        //---------------- 曲目切换（任何状态都响应）----------------
        track_d <= I_track;
        if (I_track != track_d) begin
            fmt_seen   <= 1'b0;
            O_fmt_bad  <= 1'b0;
            if ((I_track == 4'd0) || (I_track > t_cnt) || !dir_done) begin
                stream_off <= 1'b1;
                found      <= 1'b0;
            end else begin
                file_sec   <= pick_sec;
                file_len   <= pick_len;
                pcm_start  <= pick_off;
                cur_sec    <= pick_sec;
                byte_abs   <= 32'd0;
                have_lo    <= 1'b0;
                stream_off <= 1'b0;
                found      <= 1'b1;
                if (st != S_ARM)
                    st <= S_ARM;
            end
        end

        case (st)
        //------------------------------------------------ MBR
        S_MBR: if (enable) begin
            req <= 1'b1;
            fbi <= 10'd0;
            ptype <= 8'd0;
            st  <= S_MBR_GET;
        end

        S_MBR_GET: begin
            if (dvld) begin
                fbi <= fbi + 10'd1;
                case (fbi)
                    10'd450: ptype <= data;
                    10'd454: plba[7:0]   <= data;
                    10'd455: plba[15:8]  <= data;
                    10'd456: plba[23:16] <= data;
                    10'd457: plba[31:24] <= data;
                    default: ;
                endcase
            end
            if (end_of_sec) begin
                req <= 1'b0;
                if ((ptype == 8'h0B) || (ptype == 8'h0C) || (ptype == 8'h06) ||
                    (ptype == 8'h04) || (ptype == 8'h07) || (ptype == 8'h0E))
                    part_start <= plba;
                else
                    part_start <= 32'd0;
                st <= S_BPB;
            end
        end

        //------------------------------------------------ BPB
        S_BPB: begin
            req <= 1'b1;
            fbi <= 10'd0;
            st  <= S_BPB_GET;
        end

        S_BPB_GET: begin
            if (dvld) begin
                fbi <= fbi + 10'd1;
                case (fbi)
                    10'd11: bps[7:0]    <= data;
                    10'd12: bps[15:8]   <= data;
                    10'd13: spc         <= data;
                    10'd14: rsvd[7:0]   <= data;
                    10'd15: rsvd[15:8]  <= data;
                    10'd16: nfats       <= data;
                    10'd17: root_ent[7:0]  <= data;
                    10'd18: root_ent[15:8] <= data;
                    10'd22: fat16[7:0]  <= data;
                    10'd23: fat16[15:8] <= data;
                    10'd36: fat32sz[7:0]   <= data;
                    10'd37: fat32sz[15:8]  <= data;
                    10'd38: fat32sz[23:16] <= data;
                    10'd39: fat32sz[31:24] <= data;
                    10'd44: root_clus[7:0]   <= data;
                    10'd45: root_clus[15:8]  <= data;
                    10'd46: root_clus[23:16] <= data;
                    10'd47: root_clus[31:24] <= data;
                    default: ;
                endcase
            end
            if (end_of_sec) begin
                req <= 1'b0;
                if ((bps == 16'd512) && (spc != 8'd0) && (nfats != 8'd0) &&
                    ((fat16 != 16'd0) || (fat32sz != 32'd0))) begin
                    if (fat16 != 16'd0) begin
                        data_start <= part_start + {16'd0, rsvd} + {24'd0, nfats} * {16'd0, fat16};
                        dir_start  <= part_start + {16'd0, rsvd} + {24'd0, nfats} * {16'd0, fat16};
                        dir_cnt    <= (root_ent + 16'd15) >> 4;
                    end else begin
                        data_start <= part_start + {16'd0, rsvd} + {24'd0, nfats} * fat32sz;
                        dir_start  <= part_start + {16'd0, rsvd} + {24'd0, nfats} * fat32sz +
                                      (root_clus - 32'd2) * {24'd0, spc};
                        dir_cnt    <= DIR_SEC_MAX;
                    end
                    dir_k <= 16'd0;
                    st    <= S_DIR;
                end else begin
                    scan_mode <= 1'b1;
                    scan_sec  <= SCAN_START;
                    st        <= S_SCAN;
                end
            end
        end

        //------------------------------------------------ 根目录（收集所有 WAV）
        S_DIR: begin
            if (dir_k >= dir_cnt) begin
                dir_done <= 1'b1;
                if (t_cnt == 4'd0) begin
                    scan_mode <= 1'b1;                 // 目录里没有 WAV
                    scan_sec  <= SCAN_START;
                    st        <= S_SCAN;
                end else begin

                    if ((I_track != 4'd0) && (I_track <= t_cnt)) begin
                        file_sec   <= t_clus[I_track - 4'd1];
                        file_len   <= t_size[I_track - 4'd1];
                        pcm_start  <= 32'd44;
                        cur_sec    <= t_clus[I_track - 4'd1];
                        byte_abs   <= 32'd0;
                        have_lo    <= 1'b0;
                        stream_off <= 1'b0;
                        found      <= 1'b1;
                    end else begin
                        stream_off <= 1'b1;
                        found      <= 1'b0;
                    end
                    st <= S_ARM;
                end
            end else begin
                req <= 1'b1;
                fbi <= 10'd0;
                st  <= S_DIR_GET;
            end
        end

        S_DIR_GET: begin
            if (dvld) begin
                fbi <= fbi + 10'd1;
                case (fbi[4:0])
                    5'd0 : begin
                        // 判定上一项是不是 WAV 文件
                        if (e_ok && (e_ext0 == 8'h57) && (e_ext1 == 8'h41) && (e_ext2 == 8'h56) &&
                            ((e_attr & 8'h0F) != 8'h0F) &&
                            ((e_attr & 8'h08) == 8'h00) &&
                            ((e_attr & 8'h10) == 8'h00) &&
                            (({e_chi, e_clo}) != 32'd0) &&
                            (e_size >= 32'd44) &&
                            (t_cnt < MAX_TRACKS)) begin
                            t_clus[t_cnt] <= data_start + (({e_chi, e_clo}) - 32'd2) * {24'd0, spc};
                            t_size[t_cnt] <= e_size;
                            t_cnt         <= t_cnt + 4'd1;
                        end
                        if (e_ok && (data == 8'h00)) begin
                            // 目录结束（本扇区后面全空）
                            dir_done <= 1'b1;
                            req      <= 1'b0;
                        end
                        e_ok <= (data != 8'h00) && (data != 8'hE5);
                    end
                    5'd8 : e_ext0 <= data;
                    5'd9 : e_ext1 <= data;
                    5'd10: e_ext2 <= data;
                    5'd11: e_attr <= data;
                    5'd20: e_chi[7:0]   <= data;
                    5'd21: e_chi[15:8]  <= data;
                    5'd26: e_clo[7:0]   <= data;
                    5'd27: e_clo[15:8]  <= data;
                    5'd28: e_size[7:0]   <= data;
                    5'd29: e_size[15:8]  <= data;
                    5'd30: e_size[23:16] <= data;
                    5'd31: e_size[31:24] <= data;
                    default: ;
                endcase
            end
            if (end_of_sec) begin
                req <= 1'b0;
                dir_k <= dir_k + 16'd1;
                st    <= S_DIR;
            end
        end

        //------------------------------------------------ 兜底扫描
        S_SCAN: begin
            if (enable) begin
                req      <= 1'b1;
                fbi      <= 10'd0;
                riok     <= 1'b0;
                waok     <= 1'b0;
                got_data <= 1'b0;
                st       <= S_SCAN_GET;
            end
        end

        S_SCAN_GET: begin
            if (dvld) begin
                fbi <= fbi + 10'd1;
                sh3 <= sh2; sh2 <= sh1; sh1 <= sh0; sh0 <= data;
                if (sh_val == 32'h6174_6164 && !got_data && (fbi < 10'd500)) begin
                    got_data  <= 1'b1;
                    pcm_start <= fbi + 32'd5;
                end
                case (fbi)
                    10'd0: riok <= (data == 8'h52);
                    10'd1: riok <= riok && (data == 8'h49);
                    10'd2: riok <= riok && (data == 8'h46);
                    10'd3: riok <= riok && (data == 8'h46);
                    10'd4: s_file_len[7:0]   <= data;
                    10'd5: s_file_len[15:8]  <= data;
                    10'd6: s_file_len[23:16] <= data;
                    10'd7: s_file_len[31:24] <= data;
                    10'd8: waok <= (data == 8'h57);
                    10'd9: waok <= waok && (data == 8'h41);
                    10'd10: waok <= waok && (data == 8'h56);
                    10'd11: waok <= waok && (data == 8'h45);
                    default: ;
                endcase
            end
            if (end_of_sec) begin
                req <= 1'b0;
                if (riok && waok && got_data && (s_file_len != 32'd0)) begin
                    t_clus[0]  <= scan_sec;
                    t_size[0]  <= s_file_len;
                    t_cnt      <= 4'd1;
                    dir_done   <= 1'b1;
                    found      <= 1'b1;
                    file_sec   <= scan_sec;
                    file_len   <= s_file_len;
                    cur_sec    <= scan_sec;
                    byte_abs   <= 32'd0;
                    have_lo    <= 1'b0;
                    stream_off <= 1'b0;
                    st         <= S_ARM;
                end else if (scan_sec >= SCAN_MAX) begin
                    scan_sec <= SCAN_START;
                    st       <= S_SCAN;
                end else begin
                    scan_sec <= scan_sec + 32'd1;
                    st       <= S_SCAN;
                end
            end
        end

        //------------------------------------------------ 对齐扇区边界
        S_ARM: begin
            req <= 1'b1;                    // 读一个扇区（顺便把在途的那个收尾）
            byte_abs <= 32'd0;
            have_lo  <= 1'b0;
            if (end_of_sec) begin
                req <= 1'b0;
                st  <= S_DATA_WAIT;
            end
        end

        //------------------------------------------------ 流式读 PCM
        S_DATA_WAIT: begin
            if (!stream_off && need) begin
                req <= 1'b1;
                st  <= S_DATA_GET;
            end
        end

        S_DATA_GET: begin
            if (dvld) begin
                byte_abs <= byte_abs + 32'd1;

                case (byte_abs)
                    32'd22: fmt_ch[7:0]     <= data;
                    32'd23: fmt_ch[15:8]    <= data;
                    32'd24: fmt_rate[7:0]   <= data;
                    32'd25: fmt_rate[15:8]  <= data;
                    32'd26: fmt_rate[23:16] <= data;
                    32'd27: fmt_rate[31:24] <= data;
                    32'd34: fmt_bits[7:0]   <= data;
                    32'd35: fmt_bits[15:8]  <= data;
                    default: ;
                endcase
                if (byte_abs == 32'd35)
                    fmt_seen <= 1'b1;
                if (byte_abs == 32'd36) begin
                    O_fmt_bad <= !fmt_ok;
                    if (!fmt_ok)
                        stream_off <= 1'b1;     // 直接退回静音
                end
                if (byte_abs >= pcm_start) begin
                    if (fmt_seen && !fmt_ok) begin

                        we      <= 1'b0;
                        have_lo <= 1'b0;
                    end else if (!have_lo) begin
                        lo_byte <= data;
                        have_lo <= 1'b1;
                    end else begin
                        we      <= 1'b1;
                        wdata   <= {data, lo_byte, 8'h00};
                        have_lo <= 1'b0;
                    end
                end
            end
            if (end_of_sec) begin
                req <= 1'b0;
                if (byte_abs >= file_len) begin
                    cur_sec  <= file_sec;
                    byte_abs <= 32'd0;
                    have_lo  <= 1'b0;
                end else begin
                    cur_sec <= cur_sec + 32'd1;
                end
                st <= S_DATA_WAIT;
            end
        end

        default: st <= S_MBR;
        endcase
    end
end

endmodule

`timescale 1ns/1ps

module video_transition #(
    parameter H_ACTIVE    = 640,
    parameter V_ACTIVE    = 480,
    parameter HALF_FRAMES = 18,
    parameter [9:0] X0    = 0
)(
    input  wire        clk,
    input  wire        rst,            // 高有效

    input  wire        disp_tog,       // 每写好一张新图翻转一次
    input  wire        disp_idx,       // 新图所在缓冲（0/1）
    input  wire        disp_valid,
    output reg         disp_buf,

    input  wire [2:0]  mode,           // 转场档位 0..3

    // 视频
    input  wire        hs_i,
    input  wire        vs_i,           // 低有效
    input  wire        de_i,
    input  wire [23:0] rgb_i,

    output reg         hs_o,
    output reg         vs_o,
    output reg         de_o,
    output reg  [23:0] rgb_o,
    output reg         busy            // 转场进行中
);
localparam [7:0] TOTAL = HALF_FRAMES * 2;

//-------------------------------------------------------------- 新图事件
reg [2:0]  tog_sync;
reg        vs_d;
reg        de_d;
reg  [1:0] dv_sync;                // display_valid 跨域同步
reg        pending_img;
reg        tgt_buf;

wire vs_start = vs_d & ~vs_i;
wire new_img  = (tog_sync[2] ^ tog_sync[1]);    // disp_tog 的边沿

//-------------------------------------------------------------- 帧计数
reg  [7:0] frame_cnt;
reg        active;
reg        mid_done;
reg        shown;                  // 1 = 画面上已经有有效图像

wire       mid_now = active && (frame_cnt >= HALF_FRAMES) && !mid_done;
wire       done    = active && (frame_cnt >= (TOTAL - 8'd1));

always @(posedge clk or posedge rst) begin
    if (rst) begin
        tog_sync    <= 3'd0;
        vs_d        <= 1'b1;
        de_d        <= 1'b0;
        dv_sync     <= 2'b00;
        pending_img <= 1'b0;
        tgt_buf     <= 1'b0;
        shown       <= 1'b0;
        frame_cnt   <= 8'd0;
        active      <= 1'b0;
        mid_done    <= 1'b0;
        disp_buf    <= 1'b0;
        busy        <= 1'b0;
    end else begin
        tog_sync <= {tog_sync[1:0], disp_tog};
        vs_d     <= vs_i;
        de_d     <= de_i;
        dv_sync  <= {dv_sync[0], disp_valid};

        if (dv_sync[1])
            shown <= 1'b1;

        if (new_img) begin
            pending_img <= 1'b1;
            tgt_buf     <= disp_idx;
        end

        if (vs_start) begin
            if (!shown) begin

                disp_buf    <= 1'b0;
                active      <= 1'b0;
                frame_cnt   <= 8'd0;
                pending_img <= 1'b0;
            end else if (!active) begin
                if (pending_img && (tgt_buf != disp_buf)) begin
                    pending_img <= 1'b0;
                    if (mode == 3'd0) begin
                        disp_buf <= tgt_buf;               // 直切
                    end else begin
                        disp_buf  <= disp_buf;             // 锁在旧图
                        active    <= 1'b1;
                        frame_cnt <= 8'd1;
                        mid_done  <= 1'b0;
                    end
                end else begin
                    pending_img <= 1'b0;
                    disp_buf    <= disp_idx;               // 闲时跟随
                end
            end else begin
                if (frame_cnt < TOTAL)
                    frame_cnt <= frame_cnt + 8'd1;

                if (mid_now) begin
                    disp_buf <= tgt_buf;                   // 中点换图
                    mid_done <= 1'b1;
                end

                if (done) begin
                    active    <= 1'b0;
                    frame_cnt <= 8'd0;
                    mid_done  <= 1'b0;
                end
            end
        end

        if (active && mid_done && pending_img && !vs_start) begin
            disp_buf    <= tgt_buf;
            pending_img <= 1'b0;
        end

        busy <= active;
    end
end

//-------------------------------------------------------------- 转场强度
reg  [8:0]  scale;
reg  [9:0]  wipe_x;                // 左→右边界
reg  [9:0]  bar_y;                 // 上→下边界

always @(posedge clk or posedge rst) begin
    if (rst) begin
        scale  <= 9'd256;
        wipe_x <= 10'd0;
        bar_y  <= 10'd0;
    end else if (active) begin

        if (frame_cnt < HALF_FRAMES)
            scale <= (((HALF_FRAMES + 1) - frame_cnt) * 256) / HALF_FRAMES;
        else if (frame_cnt > HALF_FRAMES)
            scale <= ((frame_cnt - HALF_FRAMES) * 256) / HALF_FRAMES;
        else
            scale <= 9'd1;

        wipe_x <= (frame_cnt * H_ACTIVE) / TOTAL;
        bar_y  <= (frame_cnt * V_ACTIVE) / TOTAL;
    end else begin
        scale  <= 9'd256;
        wipe_x <= 10'd0;
        bar_y  <= 10'd0;
    end
end

//-------------------------------------------------------------- 像素坐标
reg  [9:0] x_cnt;
reg  [9:0] y_cnt;

wire [9:0] px_x = (x_cnt >= X0) ? (x_cnt - X0) : 10'd0;

//-------------------------------------------------------------- 第 1 拍
reg        de_1, hs_1, vs_1;
reg [23:0] rgb_1;
reg [2:0]  mode_1;
reg [8:0]  scale_1;
reg [9:0]  wipe_1;
reg [9:0]  bar_1;
reg [9:0]  x_1, y_1;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        de_1   <= 1'b0;
        hs_1   <= 1'b0;
        vs_1   <= 1'b0;
        rgb_1  <= 24'd0;
        mode_1 <= 3'd0;
        scale_1 <= 9'd256;
        wipe_1 <= 10'd0;
        bar_1  <= 10'd0;
        x_1    <= 10'd0;
        y_1    <= 10'd0;
        x_cnt  <= 10'd0;
        y_cnt  <= 10'd0;
    end else begin
        // 像素坐标
        if (vs_start) begin
            x_cnt <= 10'd0;
            y_cnt <= 10'd0;
        end else if (de_i) begin
            x_cnt <= x_cnt + 10'd1;
        end else begin
            x_cnt <= 10'd0;
            if (de_d)
                y_cnt <= y_cnt + 10'd1;
        end

        de_1    <= de_i;
        hs_1    <= hs_i;
        vs_1    <= vs_i;
        rgb_1   <= rgb_i;
        mode_1  <= mode;
        scale_1 <= scale;
        wipe_1  <= wipe_x;
        bar_1   <= bar_y;
        x_1     <= px_x;
        y_1     <= y_cnt;
    end
end

//-------------------------------------------------------------- 第 2 拍：出像素
reg de_2, hs_2, vs_2;

wire [17:0] mul_r = rgb_1[23:16] * scale_1;
wire [17:0] mul_g = rgb_1[15:8]  * scale_1;
wire [17:0] mul_b = rgb_1[7:0]   * scale_1;
wire [23:0] fade_px = {mul_r[15:8], mul_g[15:8], mul_b[15:8]};

wire wipe_mask = (mode_1 == 3'd2) && (x_1 >= wipe_1);
wire bar_mask  = (mode_1 == 3'd3) && (y_1 <  bar_1);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        de_o  <= 1'b0;
        hs_o  <= 1'b0;
        vs_o  <= 1'b0;
        rgb_o <= 24'd0;
    end else begin
        de_o <= de_2;
        hs_o <= hs_2;
        vs_o <= vs_2;

        if (!de_2)
            rgb_o <= 24'd0;
        else if (!shown)
            rgb_o <= 24'd0;
        else if (mode_1 == 3'd0)
            rgb_o <= rgb_1;
        else if (mode_1 == 3'd1)
            rgb_o <= fade_px;
        else if (wipe_mask)
            rgb_o <= 24'd0;
        else if (bar_mask)
            rgb_o <= 24'd0;
        else
            rgb_o <= rgb_1;

        de_2 <= de_1;
        hs_2 <= hs_1;
        vs_2 <= vs_1;
    end
end

endmodule

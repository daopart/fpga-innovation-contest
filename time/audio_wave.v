`timescale 1ns/1ps

module audio_wave #(
    parameter H_ACTIVE = 640,
    parameter X0 = 430,            // 窗口左上角 X
    parameter Y0 = 10,             // 窗口左上角 Y
    parameter W  = 200,            // 窗口宽
    parameter H  = 72,             // 窗口高
    parameter integer NB    = 8,   // 柱子个数
    parameter integer PITCH = 24,  // 每根柱子占的像素宽（含间隔）
    parameter integer BARW  = 16,  // 柱子实心宽度
parameter integer BARS  = 16,
    parameter integer TRANSPARENT_BG = 1,  // 1 = 窗口背景透明（直接透出原图）
    parameter integer SHOW_BORDER    = 0,  // 1 = 画 1 像素边框
    parameter integer SHOW_BASE      = 0   // 1 = 画底部基准线
)(
    input  wire        clk,
    input  wire        rst,        // 高有效

    input  wire [23:0] audio_l,    // 有符号 24bit 左声道
    input  wire        audio_valid,// 48kHz 样点有效

    input  wire        hs_i,
    input  wire        vs_i,       // 低有效
    input  wire        de_i,
    input  wire [23:0] rgb_i,      // 背景图像

    output reg         hs_o,
    output reg         vs_o,
    output reg         de_o,
    output reg  [23:0] rgb_o
);
localparam [23:0] C_BORDER = 24'h7A8EA0;    // 边框
localparam [23:0] C_BG     = 24'h0A121A;    // 窗口底色
localparam [23:0] C_LOW    = 24'h30C050;
localparam [23:0] C_MID    = 24'hE0D040;
localparam [23:0] C_HIGH   = 24'hF06030;
localparam [23:0] C_BASE   = 24'h1E3040;    // 底部基准线

localparam integer XBAR0 = X0 + (W - BARS*PITCH)/2;   // 第一根柱子左边界
localparam integer Y_BOT = Y0 + H - 2;              // 柱子底部那一行
localparam [7:0]   HMAX8 = H - 4;                   // 柱高上限

//------------------------------------------------ 状态
reg signed [23:0] lp  [0:NB];       // NB+1 级低通
reg        [20:0] lvl [0:NB-1];     // NB 个频段包络

reg        de_d, vs_d;
reg  [9:0] x_cnt, y_cnt;

reg        de1, hs1, vs1;
reg  [9:0] x1, y1;
reg [23:0] rgb1;
reg        inwin1;
reg [23:0] ov_rgb;

//------------------------------------------------ 函数
function [4:0] sh_of;
    input [4:0] k;
    begin
        case (k)

            5'd0: sh_of = 5'd9;
            5'd1: sh_of = 5'd8;
            5'd2: sh_of = 5'd7;
            5'd3: sh_of = 5'd6;
            5'd4: sh_of = 5'd5;
            5'd5: sh_of = 5'd4;
            5'd6: sh_of = 5'd3;
            5'd7: sh_of = 5'd2;
            default: sh_of = 5'd1;
        endcase
    end
endfunction

function signed [23:0] abs24;
    input signed [23:0] v;
    begin
        abs24 = v[23] ? -v : v;
    end
endfunction

// 第 k 个频段的高度（像素）
function [7:0] band_h;
    input [3:0] k;
    reg [20:0] v;
    begin
        case (k)
            4'd0: v = lvl[0];
            4'd1: v = lvl[1];
            4'd2: v = lvl[2];
            4'd3: v = lvl[3];
            4'd4: v = lvl[4];
            4'd5: v = lvl[5];
            4'd6: v = lvl[6];
            default: v = lvl[7];
        endcase
        v = v >> 11;                                  // 满量程约 64
        band_h = (v > HMAX8) ? HMAX8 : v[7:0];
    end
endfunction

function [7:0] bar_h;
    input [4:0] j;
    reg [3:0] k0, k1;
    reg [7:0] a, b;
    begin
        k0 = j[4:1];
        k1 = (k0 >= 4'd7) ? 4'd7 : (k0 + 4'd1);
        a  = band_h(k0);
        b  = band_h(k1);
        bar_h = j[0] ? (({1'b0, a} + {1'b0, b}) >> 1) : a;
    end
endfunction

function [4:0] bar_index;
    input [9:0] c;
    integer k;
    reg [4:0] idx;
    begin
        idx = 5'd0;
        for (k = 1; k < BARS; k = k + 1)
            if (c >= k * PITCH)
                idx = k[4:0];
        bar_index = idx;
    end
endfunction

//------------------------------------------------ 频谱状态更新（48kHz 样点）
integer i;
integer sh;
reg signed [23:0] ediff;
reg signed [23:0] eabs;
reg        [20:0] inc;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (i = 0; i <= NB; i = i + 1) begin
            lp[i] <= 24'sd0;
            if (i < NB) lvl[i] <= 21'd0;
        end
    end else if (audio_valid) begin
        // 1) 9 级低通
        for (i = 0; i <= NB; i = i + 1) begin
            sh    = sh_of(i[4:0]);
            ediff = audio_l - lp[i];
            lp[i] <= lp[i] + (ediff >>> sh);
        end

        for (i = 0; i < NB; i = i + 1) begin
            ediff = lp[i] - lp[i+1];
            eabs  = abs24(ediff);
            inc   = eabs[20:0] >> 13;
            lvl[i] <= lvl[i] - (lvl[i] >> 9) + inc;    // 快起慢落
        end
    end
end

//------------------------------------------------ 像素坐标 / 绘制判定
wire vs_start = vs_d & ~vs_i;
wire inwin    = (x_cnt >= X0) && (x_cnt < (X0 + W)) &&
                (y_cnt >= Y0) && (y_cnt < (Y0 + H));

wire [9:0] colx = x1 - XBAR0;

wire [4:0] bidx   = bar_index(colx);
wire [9:0] bstart = bidx * PITCH;
wire [9:0] boff   = colx - bstart;
wire       bok    = inwin1 && (x1 >= XBAR0) && (colx < (BARS*PITCH)) && (boff < BARW);
wire [7:0] bh     = bok ? bar_h(bidx) : 8'd0;

wire is_bar    = bok && (bh != 8'd0) && (y1 <= Y_BOT) && (y1 > (Y_BOT - bh));
wire is_basel  = (y1 == Y_BOT);
wire is_border = (x1 == X0) || (x1 == (X0+W-1)) ||
                 (y1 == Y0) || (y1 == (Y0+H-1));
wire is_high   = (bh > ((HMAX8*2)/3));
wire is_mid    = (bh > (HMAX8/3));

always @(*) begin
    if (inwin1) begin
        if (is_bar)
            ov_rgb = is_high ? C_HIGH : (is_mid ? C_MID : C_LOW);
        else if (SHOW_BORDER != 0 && is_border)
            ov_rgb = C_BORDER;
        else if (SHOW_BASE != 0 && is_basel)
            ov_rgb = C_BASE;
        else if (TRANSPARENT_BG != 0)
            ov_rgb = rgb1;
        else
            ov_rgb = C_BG;
    end else begin
        ov_rgb = rgb1;
    end
end

//------------------------------------------------ 2 拍流水线（与改版前一致）
always @(posedge clk or posedge rst) begin
    if (rst) begin
        de_d   <= 1'b0;
        vs_d   <= 1'b1;
        x_cnt  <= 10'd0;
        y_cnt  <= 10'd0;
        de1    <= 1'b0;
        hs1    <= 1'b0;
        vs1    <= 1'b0;
        x1     <= 10'd0;
        y1     <= 10'd0;
        rgb1   <= 24'd0;
        inwin1 <= 1'b0;
        hs_o   <= 1'b0;
        vs_o   <= 1'b0;
        de_o   <= 1'b0;
        rgb_o  <= 24'd0;
    end else begin
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

        de_d   <= de_i;
        vs_d   <= vs_i;

        de1    <= de_i;
        hs1    <= hs_i;
        vs1    <= vs_i;
        x1     <= x_cnt;
        y1     <= y_cnt;
        rgb1   <= rgb_i;
        inwin1 <= inwin;

        de_o   <= de1;
        hs_o   <= hs1;
        vs_o   <= vs1;
        rgb_o  <= ov_rgb;
    end
end

endmodule

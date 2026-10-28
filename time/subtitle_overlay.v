`timescale 1ns/1ps

module subtitle_overlay #(
    parameter H_ACTIVE = 640,
    parameter V_ACTIVE = 480,
    parameter BAND_Y   = 400,          // 黑条上沿
    parameter BAND_H   = 60,           // 黑条高度
    parameter LINE_Y0  = 404,          // 第 1 行字模上沿
    parameter LINE_H   = 28,           // 两行字模的间距
    parameter CHAR_W   = 24,           // 字模宽（也是字模高）
    parameter PAGE_NUM = 4,            // 字幕页数（每页 2 行）
    parameter LINE_W   = 3,
    parameter [23:0] OUTLINE_COLOR = 24'h461800   // 深棕色描边
)(
    input  wire        clk,
    input  wire        rst,            // 高有效
    input  wire [2:0]  page,

    input  wire        hs_i,
    input  wire        vs_i,           // 低有效
    input  wire        de_i,
    input  wire [23:0] rgb_i,

    output reg         hs_o,
    output reg         vs_o,
    output reg         de_o,
    output reg  [23:0] rgb_o
);
//-------------------------------------------------------------- 坐标与行号
reg  [9:0] x_cnt;
reg  [9:0] y_cnt;
reg        vs_d;
reg        de_d;

wire vs_start = vs_d & ~vs_i;

wire       in_band = (y_cnt >= BAND_Y) && (y_cnt < (BAND_Y + BAND_H));
wire       in_text = (y_cnt >= LINE_Y0) && (y_cnt < (LINE_Y0 + 2*LINE_H));
wire [9:0] ty      = (y_cnt >= (LINE_Y0 + LINE_H)) ? (y_cnt - (LINE_Y0 + LINE_H))
                                                    : (y_cnt - LINE_Y0);
wire       ty_ok   = (ty < CHAR_W);
wire       row     = (y_cnt >= (LINE_Y0 + LINE_H)) ? 1'b1 : 1'b0;

//-------------------------------------------------------------- 第 1 拍：锁坐标
reg        de_1;
reg [2:0]  page_1;
reg [9:0]  x_1;
reg [4:0]  row_1;                  // 字模内的行号 0..23
reg        row_sel_1;              // 文本行号 0/1（不是字模行号）
reg        row_ok_1;
reg        in_text_1;
reg        in_band_1;
reg [23:0] rgb_1;
reg        hs_1, vs_1;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        x_cnt     <= 10'd0;
        y_cnt     <= 10'd0;
        vs_d      <= 1'b1;
        de_d      <= 1'b0;
        de_1      <= 1'b0;
        page_1    <= 3'd0;
        x_1       <= 10'd0;
        row_1     <= 5'd0;
        row_sel_1 <= 1'b0;
        row_ok_1  <= 1'b0;
        in_text_1 <= 1'b0;
        in_band_1 <= 1'b0;
        rgb_1     <= 24'd0;
        hs_1      <= 1'b0;
        vs_1      <= 1'b0;
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

        de_1      <= de_i;
        page_1    <= page;
        x_1       <= x_cnt;
        row_1     <= ty[4:0];
        row_sel_1 <= row;
        row_ok_1  <= ty_ok;
        in_text_1 <= in_text;
        in_band_1 <= in_band;
        rgb_1     <= rgb_i;
        hs_1      <= hs_i;
        vs_1      <= vs_i;
        vs_d      <= vs_i;
        de_d      <= de_i;
    end
end

//-------------------------------------------------------------- 第 2 拍：查字模
reg [23:0] fill_2;
reg [23:0] outl_2;
reg [4:0]  gcol_2;
reg [4:0]  grow_2;
reg        is_text_2;
reg        is_band_2;
reg [23:0] rgb_2;
reg        de_2;
reg        hs_2, vs_2;

wire [7:0] gid_now;
wire [4:0] col_now;

wire [LINE_W-1:0] text_line = ((page_1 - 3'd1) << 1) + {{(LINE_W-1){1'b0}}, row_sel_1};

subtitle_text_rom u_text_rom (
    .line  (text_line),
    .x     (x_1),
    .glyph (gid_now),
    .col   (col_now)
);

wire [23:0] fill_1;
wire [23:0] outl_1;

subtitle_font_rom u_font_rom (
    .glyph   (gid_now),
    .row     (row_1),
    .fill    (fill_1),
    .outline (outl_1)
);

wire text_px = row_ok_1 && in_text_1 && (page_1 != 3'd0) &&
               (gid_now != 8'd0) && (col_now < CHAR_W);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        fill_2    <= 24'd0;
        outl_2    <= 24'd0;
        gcol_2    <= 5'd0;
        grow_2    <= 5'd0;
        is_text_2 <= 1'b0;
        is_band_2 <= 1'b0;
        rgb_2     <= 24'd0;
        de_2      <= 1'b0;
        hs_2      <= 1'b0;
        vs_2      <= 1'b0;
    end else begin
        fill_2    <= text_px ? fill_1 : 24'd0;
        outl_2    <= text_px ? outl_1 : 24'd0;

        gcol_2    <= text_px ? col_now : 5'd0;
        grow_2    <= row_1;
        is_text_2 <= text_px;
        is_band_2 <= in_band_1 && (page_1 != 3'd0);   // page=0 时整帧直通
        rgb_2     <= rgb_1;
        de_2      <= de_1;
        hs_2      <= hs_1;
        vs_2      <= vs_1;
    end
end

//-------------------------------------------------------------- 第 3 拍：混色
wire        cur_fill = fill_2[23 - gcol_2];
wire        cur_out  = outl_2[23 - gcol_2];

reg [23:0] gold;
always @(*) begin
    case (grow_2[4:2])
        3'd0: gold = 24'hFFF4AA;
        3'd1: gold = 24'hFFE190;
        3'd2: gold = 24'hFFCE76;
        3'd3: gold = 24'hFFBB5C;
        3'd4: gold = 24'hFFA842;
        default: gold = 24'hFF9628;
    endcase
end

wire [7:0] dim_r = {5'd0, rgb_2[23:21]};
wire [7:0] dim_g = {5'd0, rgb_2[15:13]};
wire [7:0] dim_b = {5'd0, rgb_2[7:5]};
wire [23:0] base = is_band_2 ? {dim_r, dim_g, dim_b} : rgb_2;

wire [23:0] lit   = cur_fill ? gold : (cur_out ? OUTLINE_COLOR : base);
wire        paint = cur_fill | cur_out;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        hs_o  <= 1'b0;
        vs_o  <= 1'b0;
        de_o  <= 1'b0;
        rgb_o <= 24'd0;
    end else begin
        hs_o  <= hs_2;
        vs_o  <= vs_2;
        de_o  <= de_2;
        rgb_o <= de_2 ? (paint ? lit : base) : 24'd0;
    end
end

endmodule

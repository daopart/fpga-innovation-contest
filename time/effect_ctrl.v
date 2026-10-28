`timescale 1ns/1ps

module effect_ctrl #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer HIDE_MS     = 0,      // 0 = 不自动隐藏
    parameter integer PAGE_COUNT  = 2
)(
    input  wire clk,
    input  wire rst,              // 高有效
    input  wire key1_double,
    input  wire key2_double,
    input  wire img_evt,

    output reg  [2:0] trans_mode, // 0..3
    output reg  [2:0] sub_page,
    output reg        sub_active  // 字幕是否显示
);
localparam integer HIDE_CYC = (HIDE_MS > 0) ? (CLK_FREQ_HZ / 1000) * HIDE_MS : 0;
localparam [2:0]   LAST_PAGE = PAGE_COUNT;

reg [31:0] hide_cnt;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        trans_mode <= 3'd0;
        sub_page   <= 3'd1;       // 上电显示第 1 页
        sub_active <= 1'b1;
        hide_cnt   <= HIDE_CYC;
    end else begin
        //-------------------------------------------------- KEY1：转场档位
        if (key1_double) begin
            if (trans_mode == 3'd3)
                trans_mode <= 3'd0;
            else
                trans_mode <= trans_mode + 3'd1;
        end

        //-------------------------------------------------- KEY2：字幕页 / 开关
        if (key2_double) begin
            if (sub_page == LAST_PAGE) begin
                sub_page   <= 3'd0;        // 最后一页再按 -> 关闭
                sub_active <= 1'b0;
            end else begin
                sub_page   <= sub_page + 3'd1;
                sub_active <= 1'b1;
            end
            hide_cnt <= HIDE_CYC;
        end
        //-------------------------------------------------- 换图：字幕自动翻页
        else if (img_evt && sub_active) begin
            if (sub_page >= LAST_PAGE)
                sub_page <= 3'd1;          // 1 -> 2 -> 1 ...
            else
                sub_page <= sub_page + 3'd1;
            hide_cnt <= HIDE_CYC;
        end
        //-------------------------------------------------- 可选自动隐藏
        else if (hide_cnt != 32'd0) begin
            hide_cnt <= hide_cnt - 32'd1;
            if (hide_cnt == 32'd1)
                sub_active <= 1'b0;
        end
    end
end

endmodule

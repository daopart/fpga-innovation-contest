`timescale 1ns/1ps

module key_zoom_ctrl #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer DEBOUNCE_MS = 10,
    parameter integer LONG_MS     = 800,
    parameter integer PULSE_MS    = 120
)(
    input  wire clk,
    input  wire rst,                 // 高有效
    input  wire key1,                // 按下 = 0
    input  wire key2,                // 按下 = 0

    output reg  next_press,
    output reg  auto_press,
    output reg  zoom_in_tog,
    output reg  zoom_out_tog,
    output wire key1_short,          // 短按单拍（给双击识别用）
    output wire key2_short           // 短按单拍（给双击识别用）
);
localparam integer PULSE_CYC = (CLK_FREQ_HZ / 1000) * PULSE_MS;

wire key1_short_int;
wire key1_long;
wire key2_short_int;
wire key2_long;

key_classifier #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .DEBOUNCE_MS (DEBOUNCE_MS),
    .LONG_MS     (LONG_MS)
) u_key1 (
    .clk         (clk),
    .rst         (rst),
    .key_in      (key1),
    .short_press (key1_short_int),
    .long_press  (key1_long)
);

key_classifier #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .DEBOUNCE_MS (DEBOUNCE_MS),
    .LONG_MS     (LONG_MS)
) u_key2 (
    .clk         (clk),
    .rst         (rst),
    .key_in      (key2),
    .short_press (key2_short_int),
    .long_press  (key2_long)
);

//-------------------------------------------------- 短按 -> 80ms 合成按键脉冲
reg [31:0] next_cnt;
reg [31:0] auto_cnt;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        next_press <= 1'b1;
        next_cnt   <= 32'd0;
    end else if (key1_short_int) begin
        next_press <= 1'b0;
        next_cnt   <= PULSE_CYC;
    end else if (next_cnt != 32'd0) begin
        next_cnt <= next_cnt - 32'd1;
        if (next_cnt == 32'd1)
            next_press <= 1'b1;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        auto_press <= 1'b1;
        auto_cnt   <= 32'd0;
    end else if (key2_short_int) begin
        auto_press <= 1'b0;
        auto_cnt   <= PULSE_CYC;
    end else if (auto_cnt != 32'd0) begin
        auto_cnt <= auto_cnt - 32'd1;
        if (auto_cnt == 32'd1)
            auto_press <= 1'b1;
    end
end

//---------------------------------------------------- 长按 -> 缩放事件翻转
always @(posedge clk or posedge rst) begin
    if (rst) begin
        zoom_in_tog  <= 1'b0;
        zoom_out_tog <= 1'b0;
    end else begin
        if (key1_long)
            zoom_in_tog  <= ~zoom_in_tog;
        if (key2_long)
            zoom_out_tog <= ~zoom_out_tog;
    end
end

//---------------------------------------------------- 短按脉冲引出（给双击识别）
assign key1_short = key1_short_int;
assign key2_short = key2_short_int;

endmodule

module key_classifier #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer DEBOUNCE_MS = 10,
    parameter integer LONG_MS     = 600
)(
    input  wire clk,
    input  wire rst,
    input  wire key_in,              // 按下 = 0
    output reg  short_press,
    output reg  long_press
);
localparam integer DEB_CYC  = (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;
localparam integer LONG_CYC = (CLK_FREQ_HZ / 1000) * LONG_MS;

reg [2:0]  key_sync;
reg        key_stable;
reg [31:0] deb_cnt;
reg [31:0] hold_cnt;
reg        long_fired;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        key_sync    <= 3'b111;
        key_stable  <= 1'b1;
        deb_cnt     <= 32'd0;
        hold_cnt    <= 32'd0;
        long_fired  <= 1'b0;
        short_press <= 1'b0;
        long_press  <= 1'b0;
    end else begin
        key_sync    <= {key_sync[1:0], key_in};
        short_press <= 1'b0;
        long_press  <= 1'b0;

        if (key_sync[2] == key_stable) begin
            deb_cnt <= 32'd0;
        end else if (deb_cnt >= (DEB_CYC-1)) begin
            deb_cnt    <= 32'd0;
            key_stable <= key_sync[2];
            if (key_sync[2] == 1'b0) begin

                hold_cnt   <= 32'd0;
                long_fired <= 1'b0;
            end else begin

                if (!long_fired)
                    short_press <= 1'b1;
            end
        end else begin
            deb_cnt <= deb_cnt + 32'd1;
        end

        if (!key_stable && !long_fired) begin
            if (hold_cnt >= (LONG_CYC-1)) begin
                long_press <= 1'b1;
                long_fired <= 1'b1;
            end else begin
                hold_cnt <= hold_cnt + 32'd1;
            end
        end
    end
end

endmodule

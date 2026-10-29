`timescale 1ns/1ps

//      第 1 次短按 -------------------+

module key_event_detect #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer WIN_MS      = 320
)(
    input  wire clk,
    input  wire rst,              // 高有效
    input  wire short_i,          // 短按单拍脉冲

    output reg  double_evt,       // 双击（第 2 下短按）单拍
    output reg  triple_evt
);
localparam integer WIN_CYC = (CLK_FREQ_HZ / 1000) * WIN_MS;

reg [1:0]  cnt;
reg [31:0] tmr;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        cnt        <= 2'd0;
        tmr        <= 32'd0;
        double_evt <= 1'b0;
        triple_evt <= 1'b0;
    end else begin
        double_evt <= 1'b0;
        triple_evt <= 1'b0;

        if (short_i) begin
            if (cnt == 2'd0) begin
                cnt <= 2'd1;
                tmr <= WIN_CYC;
            end else begin

                cnt        <= 2'd0;
                tmr        <= 32'd0;
                double_evt <= 1'b1;
            end
        end else if (tmr != 32'd0) begin
            tmr <= tmr - 32'd1;
            if (tmr == 32'd1) begin
                cnt <= 2'd0;
                tmr <= 32'd0;
            end
        end
    end
end

endmodule

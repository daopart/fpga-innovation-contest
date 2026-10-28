`timescale 1ns/1ps

module flip_ctrl #(
    parameter [20:0] CNT_DEB = 20'd400_000      // 约 16ms @25MHz
)(
    input  wire       clk,
    input  wire       rst,          // 高有效
    input  wire       key_flip,     // 低有效（拨下 = 按下）
    output reg        flip_h,       // 1 = 左右镜像
    output reg        flip_v,       // 1 = 上下镜像
    output reg  [1:0] flip_mode
);

    //------------------------------------------------------------ 同步 + 消抖
    reg        key_s1, key_s2;
    reg        lvl, lvl_d;
    reg [20:0] cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            key_s1 <= 1'b1;
            key_s2 <= 1'b1;
        end else begin
            key_s1 <= key_flip;
            key_s2 <= key_s1;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt   <= 21'd0;
            lvl   <= 1'b1;
            lvl_d <= 1'b1;
        end else begin
            lvl_d <= lvl;
            if (key_s2 != lvl) begin
                if (cnt >= CNT_DEB) begin
                    lvl <= key_s2;
                    cnt <= 21'd0;
                end else begin
                    cnt <= cnt + 21'd1;
                end
            end else begin
                cnt <= 21'd0;
            end
        end
    end

    wire pressed = lvl_d & ~lvl;

    //------------------------------------------------------------ 档位循环
    wire [1:0] mode_next = (flip_mode == 2'd3) ? 2'd0 : (flip_mode + 2'd1);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            flip_mode <= 2'd0;
            flip_h    <= 1'b0;
            flip_v    <= 1'b0;
        end else if (pressed) begin
            flip_mode <= mode_next;
            flip_h    <= mode_next[0];
            flip_v    <= mode_next[1];
        end
    end

endmodule

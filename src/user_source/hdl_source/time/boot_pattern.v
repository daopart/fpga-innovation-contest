`timescale 1ns/1ps

module boot_pattern #(
    parameter H_ACTIVE = 640,
    parameter V_ACTIVE = 480
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        hs_i,
    input  wire        vs_i,
    input  wire        de_i,
    output reg  [23:0] rgb_o
);
    localparam [9:0] LOGO_Y = 10'd108;
    localparam [9:0] LOGO_H = 10'd224;

    reg  [9:0] x_cnt;
    reg  [9:0] y_cnt;
    reg        vs_d;
    reg        de_d;
    reg  [9:0] bar_w;

    wire vs_start = vs_d & ~vs_i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x_cnt <= 10'd0;
            y_cnt <= 10'd0;
            vs_d  <= 1'b1;
            de_d  <= 1'b0;
        end else begin
            vs_d <= vs_i;
            de_d <= de_i;
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
        end
    end

    // 进度条：每场 +1 像素，约 6.7s 走满
    always @(posedge clk or posedge rst) begin
        if (rst)
            bar_w <= 10'd0;
        else if (vs_start && (bar_w < 10'd400))
            bar_w <= bar_w + 10'd1;
    end

    // 320x112 的 1bpp 赛事视觉，显示时 2 倍放大到 640x224
    wire [9:0] logo_dy = (y_cnt >= LOGO_Y) ? (y_cnt - LOGO_Y) : 10'd0;
    wire       in_logo = (y_cnt >= LOGO_Y) && (y_cnt < (LOGO_Y + LOGO_H));
    wire [8:0] sx      = x_cnt[9:1];
    wire [6:0] sy      = logo_dy[8:1];
    wire [10:0] laddr  = sy * 11'd10 + {7'd0, sx[8:5]};

    wire [31:0] ldata;
    boot_logo_rom u_logo (
        .clk  (clk),
        .addr (laddr),
        .data (ldata)
    );

    reg [4:0] lbit_d;
    reg       len_d;
    always @(posedge clk) begin
        lbit_d <= sx[4:0];
        len_d  <= in_logo;
    end
    wire logo_px = len_d && ldata[31 - lbit_d];

    wire [9:0] bar_end = 10'd60 + bar_w;
    wire in_bar = (y_cnt >= (V_ACTIVE - 10'd28)) && (y_cnt < (V_ACTIVE - 10'd20)) &&
                  (x_cnt >= 10'd60) && (x_cnt < bar_end);

    reg [23:0] c;
    always @(*) begin
        c = 24'hF7F8FA;
        if (logo_px)
            c = 24'h1B4F9C;
        if (in_bar)
            c = 24'h1B4F9C;
    end

    always @(posedge clk or posedge rst) begin
        if (rst)
            rgb_o <= 24'd0;
        else
            rgb_o <= c;
    end
endmodule

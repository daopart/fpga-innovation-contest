`timescale 1ns/1ps

module boot_pattern #(
    parameter H_ACTIVE = 640,
    parameter V_ACTIVE = 480
)(
    input  wire        clk,
    input  wire        rst,        // 高有效
    input  wire        hs_i,
    input  wire        vs_i,       // 低有效
    input  wire        de_i,
    output reg  [23:0] rgb_o
);
    localparam [9:0] HORIZON = 10'd300;                 // 地平线
    localparam [9:0] SUN_X   = 10'd320;                 // 落日中心
    localparam [9:0] SUN_Y   = 10'd236;                 // 落日中心（略高于地平线）
    localparam [9:0] SUN_R   = 10'd86;

    reg  [9:0] x_cnt;
    reg  [9:0] y_cnt;
    reg        vs_d;
    reg        de_d;
    reg [11:0] frame_cnt;                               // 场计数

    wire vs_start = vs_d & ~vs_i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x_cnt     <= 10'd0;
            y_cnt     <= 10'd0;
            vs_d      <= 1'b1;
            de_d      <= 1'b0;
            frame_cnt <= 12'd0;
        end else begin
            vs_d <= vs_i;
            de_d <= de_i;
            if (vs_start) begin
                x_cnt     <= 10'd0;
                y_cnt     <= 10'd0;
                frame_cnt <= frame_cnt + 12'd1;
            end else if (de_i) begin
                x_cnt <= x_cnt + 10'd1;
            end else begin
                x_cnt <= 10'd0;
                if (de_d)
                    y_cnt <= y_cnt + 10'd1;
            end
        end
    end

    //----------------------------------------------- 开场揭示

    wire [9:0] reveal_y = (frame_cnt < 12'd24) ? (V_ACTIVE - ((frame_cnt * (V_ACTIVE + 10'd20)) >> 5))
                                              : 10'd0;
    wire       revealing = (frame_cnt < 12'd24);
    wire       revealed  = (y_cnt >= reveal_y);
    wire [2:0] reveal_glow = (revealing && (y_cnt + 10'd1 >= reveal_y) && (y_cnt < reveal_y + 10'd4))
                             ? 3'd7 : 3'd0;

    //----------------------------------------------- 落日

    wire [11:0] adx = (x_cnt > SUN_X) ? (x_cnt - SUN_X) : (SUN_X - x_cnt);
    wire [11:0] ady = (y_cnt > SUN_Y) ? (y_cnt - SUN_Y) : (SUN_Y - y_cnt);
    wire [23:0] r2     = adx * adx + ady * ady;
    wire [23:0] r2max  = SUN_R * SUN_R;
    wire        in_sun = (r2 < r2max) && (y_cnt < HORIZON);

    wire        sun_stripe = ((y_cnt[2:0]) < 3'd3);

    wire [3:0]  sun_band = (y_cnt > (SUN_Y - SUN_R)) ? ((y_cnt - (SUN_Y - SUN_R)) >> 5) : 4'd0;

    //----------------------------------------------- 地平线光晕
    wire [9:0] dy_h = (y_cnt > HORIZON) ? (y_cnt - HORIZON) : (HORIZON - y_cnt);
    wire       glow  = (dy_h < 10'd5);

    //----------------------------------------------- 网格地面
    wire [9:0]  gy    = (y_cnt > HORIZON) ? (y_cnt - HORIZON) : 10'd0;
    wire [10:0] skew  = (gy * 11'd120) >> 8;            // 越远越"收拢"
    wire [10:0] vx    = {1'b0, x_cnt} + skew + frame_cnt[10:0];
    wire        vline = ((vx & 11'd63) < 11'd2);
    wire        hline = ((gy & 10'd31) < 10'd2);
    wire        grid  = (y_cnt > HORIZON) && (vline || hline);

    //----------------------------------------------- 星点（稀疏闪烁）
    wire [15:0] star_h = (x_cnt * 16'd7 + y_cnt * 16'd13 + frame_cnt * 16'd1) & 16'h03FF;
    wire        star   = (star_h == 16'd0) && (y_cnt < HORIZON);

    //----------------------------------------------- 队名「奶蛙队」

    localparam [9:0] TEAM_X = 10'd224;
    localparam [9:0] TEAM_Y = 10'd38;
    localparam [9:0] TEAM_W = 10'd192;
    localparam [9:0] TEAM_H = 10'd64;

    wire        in_team = (x_cnt >= TEAM_X) && (x_cnt < (TEAM_X + TEAM_W)) &&
                          (y_cnt >= TEAM_Y) && (y_cnt < (TEAM_Y + TEAM_H));
    wire [9:0]  tdx = x_cnt - TEAM_X;
    wire [9:0]  tdy = y_cnt - TEAM_Y;
    wire [1:0]  tch = (tdx < 10'd64)  ? 2'd0 :
                      ((tdx < 10'd128) ? 2'd1 : 2'd2);
    wire [9:0]  tcol_raw = (tdx < 10'd64)  ? tdx :
                           ((tdx < 10'd128) ? (tdx - 10'd64) : (tdx - 10'd128));
    wire [4:0]  tcol = tcol_raw[5:1];        // 64 -> 32 列
    wire [5:0]  trow = tdy[6:1];             // 64 -> 32 行

    wire [31:0] team_row;
    team_name_rom u_team_name (
        .I_ch   (tch),
        .I_row  (trow),
        .O_bits (team_row)
    );
    wire team_px = in_team && team_row[31 - tcol];

    //----------------------------------------------- 进度条
    reg  [9:0] bar_w;
    always @(posedge clk or posedge rst) begin
        if (rst)
            bar_w <= 10'd0;
        else if (vs_start && (bar_w < 10'd400))
            bar_w <= bar_w + 10'd1;
    end
    wire [9:0] bar_end = 10'd60 + bar_w;
    wire in_bar = (y_cnt >= (V_ACTIVE - 10'd28)) && (y_cnt < (V_ACTIVE - 10'd20)) &&
                  (x_cnt >= 10'd60) && (x_cnt < bar_end);

    //----------------------------------------------- 配色
    wire [7:0] sky_r = 8'd4  + {2'b0, y_cnt[8:5]};
    wire [7:0] sky_g = 8'd6  + {1'b0, y_cnt[8:5]};
    wire [7:0] sky_b = 8'd28 + {1'b0, y_cnt[8:4]};

    wire [7:0] gnd_r = 8'd10 + {1'b0, gy[8:4]};
    wire [7:0] gnd_g = 8'd4;
    wire [7:0] gnd_b = 8'd22 + {1'b0, gy[8:4]};

    reg [23:0] c;

    always @(*) begin

        if (y_cnt > HORIZON)
            c = {gnd_r, gnd_g, gnd_b};
        else
            c = {sky_r, sky_g, sky_b};

        // 星点
        if (star)
            c = 24'hC8D8FF;

        if (in_sun && !sun_stripe) begin

            c = {8'd 255,
                 8'd 230 - {2'b00, sun_band} * 8'd28,
                 8'd  50 + {2'b00, sun_band} * 8'd10};
        end else if (in_sun && sun_stripe)
            c = 24'h1A0F2A;

        // 地平线光晕
        if (glow)
            c = 24'h50E0FF;

        // 网格
        if (grid)
            c = (gy < 10'd60) ? 24'h40A0FF : 24'h2050B0;

        if (team_px)
            c = 24'hAFF0FF;

        // 进度条
        if (in_bar)
            c = 24'h30E0C0;

        if (revealing && !revealed)
            c = c >> 7;                                  // 约 1/8 亮度
        if (reveal_glow != 3'd0)
            c = 24'hB0F0FF;
    end

    always @(posedge clk or posedge rst) begin
        if (rst)
            rgb_o <= 24'd0;
        else
            rgb_o <= c;
    end
endmodule

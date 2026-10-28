`timescale 1ns/1ps

module tb_video_adjust;

reg clk = 1'b0;
always #20 clk = ~clk;              // 25MHz

reg rst = 1'b1;

wire hs, vs, de;

color_bar u_cb (
    .clk    (clk),
    .rst    (rst),
    .hs     (hs),
    .vs     (vs),
    .de     (de),
    .rgb_r  (),
    .rgb_g  (),
    .rgb_b  ()
);

//-------------------------------------------------- 输入图像（按输入时序）
function [23:0] img_pix(input [9:0] x, input [9:0] y);
    img_pix = {x[7:0], y[7:0], 8'h5a};
endfunction

reg  [9:0] xi = 10'd0;
reg  [9:0] yi = 10'd0;
reg        de_i_d = 1'b0;
reg        vs_i_d = 1'b1;

wire [23:0] rgb_i = img_pix(xi, yi);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        xi <= 0; yi <= 0; de_i_d <= 0; vs_i_d <= 1;
    end else begin
        de_i_d <= de;
        vs_i_d <= vs;
        if (vs_i_d & ~vs) begin
            xi <= 0; yi <= 0;
        end else if (de) begin
            xi <= xi + 10'd1;
        end else begin
            xi <= 0;
            if (de_i_d) yi <= yi + 10'd1;
        end
    end
end

//-------------------------------------------------- 按键激励
reg key3 = 1'b1, key4 = 1'b1, key5 = 1'b1, key6 = 1'b1;

wire signed [7:0] bright;
wire [8:0]        gain;
wire              show;

adj_key_ctrl #(
    .CNT_DEB  (20'd200),
    .CNT_SHOW (26'd600_000)
) u_key (
    .I_clk    (clk),
    .I_rst    (rst),
    .I_key    ({key6, key5, key4, key3}),
    .O_bright (bright),
    .O_gain   (gain),
    .O_show   (show)
);

//-------------------------------------------------- 亮度/对比度 + OSD
wire [23:0] adj_rgb;
wire        adj_de, adj_vs;

video_bright_contrast u_bc (
    .I_pix_clk (clk),
    .I_rst     (rst),
    .I_de      (de),
    .I_vs      (vs),
    .I_rgb     (rgb_i),
    .I_bright  (bright),
    .I_gain    (gain),
    .O_rgb     (adj_rgb),
    .O_de      (adj_de),
    .O_vs      (adj_vs)
);

wire [23:0] osd_rgb;

adj_osd u_osd (
    .I_pix_clk (clk),
    .I_rst     (rst),
    .I_de      (adj_de),
    .I_vs      (adj_vs),
    .I_rgb     (adj_rgb),
    .I_bright  (bright),
    .I_gain    (gain),
    .I_active  (show),
    .O_rgb     (osd_rgb)
);

//-------------------------------------------------- 输出坐标与检查
reg [9:0] x_cnt = 10'd0;
reg [9:0] y_cnt = 10'd0;
reg       de_d  = 1'b0;
reg       vs_d  = 1'b1;

integer errors    = 0;
integer checks    = 0;
integer frame_cnt = 0;
integer osd_checks = 0;

wire vs_fall = vs_d & ~vs;

always @(posedge clk) begin
    vs_d <= vs;
    de_d <= adj_de;
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        x_cnt <= 0; y_cnt <= 0; frame_cnt <= 0;
    end else begin
        if (vs_fall) begin
            frame_cnt <= frame_cnt + 1;
            x_cnt <= 0; y_cnt <= 0;
        end else begin
            if (adj_de) begin
                if (!de_d) x_cnt <= 10'd1;
                else if (x_cnt != 10'd639) x_cnt <= x_cnt + 10'd1;
            end else begin
                x_cnt <= 10'd0;
            end
            if (!adj_de && de_d) y_cnt <= y_cnt + 10'd1;
        end
    end
end

function [7:0] adj_ch(input [7:0] c, input signed [7:0] b);
    integer v;
    begin
        v = c + b;
        if (v < 0)        adj_ch = 8'd0;
        else if (v > 255) adj_ch = 8'd255;
        else              adj_ch = v[7:0];
    end
endfunction

wire [23:0] exp_in  = img_pix(x_cnt, y_cnt);
wire [23:0] exp_out = {adj_ch(exp_in[23:16], bright),
                       adj_ch(exp_in[15:8],  bright),
                       adj_ch(exp_in[7:0],   bright)};

wire in_box = (x_cnt >= 12) && (x_cnt < 100) && (y_cnt >= 12) && (y_cnt < 52);

always @(posedge clk) begin
    if (adj_de && (frame_cnt > 2)) begin
        checks = checks + 1;
        if (!show) begin

            if (osd_rgb !== exp_out) begin
                errors = errors + 1;
                if (errors < 10)
                    $display("PASS-THRU MISMATCH x=%0d y=%0d got=%06x exp=%06x",
                             x_cnt, y_cnt, osd_rgb, exp_out);
            end
        end else begin
            osd_checks = osd_checks + 1;
            if (in_box) begin
                if (osd_rgb !== 24'hFF_FF_00 && osd_rgb !== 24'h00_00_00) begin
                    errors = errors + 1;
                    if (errors < 10)
                        $display("OSD BOX MISMATCH x=%0d y=%0d got=%06x", x_cnt, y_cnt, osd_rgb);
                end
            end else begin
                if (osd_rgb !== exp_out) begin
                    errors = errors + 1;
                    if (errors < 10)
                        $display("OSD OUTSIDE MISMATCH x=%0d y=%0d got=%06x exp=%06x",
                                 x_cnt, y_cnt, osd_rgb, exp_out);
                end
            end
        end
    end
end

//-------------------------------------------------- 激励
initial begin
    rst = 1'b1;
    repeat (20) @(posedge clk);
    rst = 1'b0;

    wait (frame_cnt == 4);              // 先跑几帧验证直通
    key4 = 1'b0;
    repeat (2000) @(posedge clk);
    key4 = 1'b1;                        // 松开

    wait (frame_cnt == 7);
    repeat (2000) @(posedge clk);

    $display("checks=%0d osd_checks=%0d errors=%0d bright=%0d gain=%0d",
             checks, osd_checks, errors, $signed(bright), gain);
    if (errors == 0 && checks > 500000 && osd_checks > 1000 && $signed(bright) == 4 && gain == 256)
        $display("RESULT: PASS");
    else
        $display("RESULT: FAIL");
    $finish;
end

endmodule

`timescale 1ns/1ps

module tb_video_zoom;

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

//-------------------------------------------------- 行为模型：按行供数
function [23:0] src_pix(input [9:0] x, input [9:0] y);
    src_pix = {x[7:0], y[7:0], 8'h5a};
endfunction

reg [23:0] mem_rgb   = 24'd0;
reg        mem_empty = 1'b1;
reg        mem_ack   = 1'b0;
reg  [9:0] mem_col   = 10'd0;
reg  [9:0] mem_row   = 10'd0;
reg  [2:0] mstate    = 3'd0;
reg  [7:0] mdelay    = 8'd0;

wire [7:0]  mem_r = mem_rgb[23:16];
wire [7:0]  mem_g = mem_rgb[15:8];
wire [7:0]  mem_b = mem_rgb[7:0];
wire [31:0] line_rdata = {mem_r, mem_g, mem_b, 8'h00};   // 像素在 [31:8]

integer errors    = 0;
integer checks    = 0;
integer frame_cnt = 0;
integer cnt_1x    = 0;
integer cnt_2x    = 0;
integer cnt_4x    = 0;
integer cnt_05x   = 0;

//--------------------------------------------------------- DUT
wire        line_req;
wire        line_ack;
wire [20:0] line_addr;
wire        line_ren;
wire [23:0] rgb_o;
wire        de_o;
wire        hs_o;
wire        vs_o;
wire [2:0]  zoom_level;

reg zoom_in_tog  = 1'b0;
reg zoom_out_tog = 1'b0;
reg flip_h_i     = 1'b0;
reg flip_v_i     = 1'b0;

assign line_ack = mem_ack;

video_zoom #(
    .H_ACTIVE  (640),
    .V_ACTIVE  (480),
    .BUF0_ADDR (0),
    .BUF1_ADDR (307200)
) dut (
    .video_clk    (clk),
    .rst          (rst),
    .hs_i         (hs),
    .vs_i         (vs),
    .de_i         (de),
    .hs_o         (hs_o),
    .vs_o         (vs_o),
    .de_o         (de_o),
    .rgb_o        (rgb_o),
    .buf_sel      (1'b0),
    .line_req     (line_req),
    .line_ack     (line_ack),
    .line_addr    (line_addr),
    .line_empty   (mem_empty),
    .line_ren     (line_ren),
    .line_rdata   (line_rdata),
    .zoom_in_tog  (zoom_in_tog),
    .zoom_out_tog (zoom_out_tog),
    .zoom_level   (zoom_level),
    .flip_h_i     (flip_h_i),
    .flip_v_i     (flip_v_i)
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        mem_ack   <= 1'b0;
        mem_empty <= 1'b1;
        mem_col   <= 10'd0;
        mstate    <= 3'd0;
        mdelay    <= 8'd0;
        mem_rgb   <= 24'd0;
        mem_row   <= 10'd0;
    end else begin
        case (mstate)
            3'd0: begin
                if (line_req) begin
                    mem_row <= line_addr[20:0] / 21'd640;    // 行号 = 地址/640
                    mdelay  <= 8'd0;
                    mstate  <= 3'd1;
                end
            end
            3'd1: begin                                      // 模拟 SDRAM 读延迟
                if (mdelay == 8'd20) begin
                    mem_ack   <= 1'b1;
                    mem_empty <= 1'b1;
                    mstate    <= 3'd2;
                end else begin
                    mdelay <= mdelay + 8'd1;
                end
            end
            3'd2: begin                                      // 等 DUT 收下应答
                if (!line_req) begin
                    mem_ack   <= 1'b0;
                    mem_empty <= 1'b0;
                    mem_col   <= 10'd0;
                    mstate    <= 3'd3;
                end
            end
            3'd3: begin                                      // 每次 ren 供一个像素
                if (line_ren) begin
                    mem_rgb <= src_pix(mem_col, mem_row);
                    mem_col <= mem_col + 10'd1;
                    if (mem_col == 10'd639) begin
                        mem_empty <= 1'b1;
                        mstate    <= 3'd0;
                    end
                end
            end
            default: mstate <= 3'd0;
        endcase
    end
end

//-------------------------------------------------- 检查
reg [9:0] x_cnt    = 10'd0;
reg [9:0] y_cnt    = 10'd0;
reg [2:0] chk_zoom = 3'd1;
reg       chk_fh   = 1'b0;
reg       chk_fv   = 1'b0;
reg       vs_d     = 1'b1;
reg       de_d     = 1'b0;

wire vs_fall = vs_d & ~vs;

always @(posedge clk) begin
    vs_d <= vs;
    de_d <= de_o;
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        x_cnt    <= 10'd0;
        y_cnt    <= 10'd0;
        chk_zoom <= 3'd1;
        chk_fh   <= 1'b0;
        chk_fv   <= 1'b0;
    end else begin
        if (vs_fall) begin
            y_cnt    <= 10'd0;
            x_cnt    <= 10'd0;
            chk_zoom <= zoom_level;
            chk_fh   <= flip_h_i;
            chk_fv   <= flip_v_i;
        end else begin
            if (de_o) begin
                if (!de_d)
                    x_cnt <= 10'd1;
                else if (x_cnt != 10'd639)
                    x_cnt <= x_cnt + 10'd1;
            end else begin
                x_cnt <= 10'd0;
            end

            if (!de_o && de_d)
                y_cnt <= y_cnt + 10'd1;
        end
    end
end

function [9:0] fx(input [9:0] x);
    fx = chk_fh ? (10'd639 - x) : x;
endfunction

function [9:0] fy(input [9:0] y);
    fy = chk_fv ? (10'd479 - y) : y;
endfunction

// 期望值
reg [23:0] exp_rgb;
reg        exp_valid;

always @(*) begin
    exp_valid = 1'b1;
    exp_rgb   = 24'd0;
    case (chk_zoom)
        3'd1: exp_rgb = src_pix(fx(x_cnt), fy(y_cnt));                       // 1x
        3'd2: exp_rgb = src_pix(fx(10'd160 + (x_cnt >> 1)),
                                fy(10'd120 + (y_cnt >> 1)));                 // 2x
        3'd4: exp_rgb = src_pix(fx(10'd240 + (x_cnt >> 2)),
                                fy(10'd180 + (y_cnt >> 2)));                 // 4x
        3'd3: begin
            exp_valid = 1'b0;
            exp_rgb   = 24'd0;
        end
        3'd0: begin                                                          // 0.5x
            if ((x_cnt >= 10'd160) && (x_cnt < 10'd480) &&
                (y_cnt >= 10'd120) && (y_cnt < 10'd360))
                exp_rgb = src_pix(fx((x_cnt - 10'd160) << 1),
                                  fy((y_cnt - 10'd120) << 1));
            else
                exp_rgb = 24'd0;
        end
        default: begin
            exp_valid = 1'b0;
            exp_rgb   = 24'd0;
        end
    endcase
end

always @(posedge clk) begin
    if (de_o && exp_valid && (frame_cnt > 2)) begin
        checks = checks + 1;
        if (chk_zoom == 3'd1)      cnt_1x  = cnt_1x  + 1;
        else if (chk_zoom == 3'd2) cnt_2x  = cnt_2x  + 1;
        else if (chk_zoom == 3'd4) cnt_4x  = cnt_4x  + 1;
        else if (chk_zoom == 3'd0) cnt_05x = cnt_05x + 1;
        if (rgb_o !== exp_rgb) begin
            errors = errors + 1;
            if (errors < 10)
                $display("MISMATCH t=%0t zoom=%0d x=%0d y=%0d got=%06x exp=%06x",
                         $time, chk_zoom, x_cnt, y_cnt, rgb_o, exp_rgb);
        end
    end
end

always @(posedge clk) begin
    if (vs_fall)
        frame_cnt <= frame_cnt + 1;
end

//-------------------------------------------------- 激励
initial begin
    rst = 1'b1;
    repeat (20) @(posedge clk);
    rst = 1'b0;

    wait (frame_cnt == 2);          // 1x 两帧后切 2x
    repeat (100) @(posedge clk);
    zoom_in_tog = 1'b1;             // -> 2x

    wait (frame_cnt == 4);
    repeat (100) @(posedge clk);
    zoom_out_tog = 1'b1;            // -> 1x

    wait (frame_cnt == 6);
    repeat (100) @(posedge clk);
    zoom_out_tog = 1'b0;            // -> 0.5x

    // 0.5x 两帧后连按放大到 4x
    wait (frame_cnt == 9);  repeat (50) @(posedge clk); zoom_in_tog = ~zoom_in_tog;   // -> 1x
    wait (frame_cnt == 10); repeat (50) @(posedge clk); zoom_in_tog = ~zoom_in_tog;   // -> 2x
    wait (frame_cnt == 11); repeat (50) @(posedge clk); zoom_in_tog = ~zoom_in_tog;   // -> 3x
    wait (frame_cnt == 12); repeat (50) @(posedge clk); zoom_in_tog = ~zoom_in_tog;   // -> 4x

    wait (frame_cnt == 15); repeat (50) @(posedge clk); flip_h_i = 1'b1; flip_v_i = 1'b0;  // 左右
    wait (frame_cnt == 17); repeat (50) @(posedge clk); flip_h_i = 1'b0; flip_v_i = 1'b1;  // 上下
    wait (frame_cnt == 19); repeat (50) @(posedge clk); flip_h_i = 1'b1; flip_v_i = 1'b1;  // 180°
    wait (frame_cnt == 21); repeat (50) @(posedge clk); flip_h_i = 1'b0; flip_v_i = 1'b0;  // 正常

    wait (frame_cnt == 23);
    repeat (2000) @(posedge clk);

    $display("checks=%0d errors=%0d zoom_level=%0d (1x=%0d 2x=%0d 4x=%0d 0.5x=%0d)",
             checks, errors, zoom_level, cnt_1x, cnt_2x, cnt_4x, cnt_05x);
    if (errors == 0 && checks > 100000)
        $display("RESULT: PASS");
    else
        $display("RESULT: FAIL");
    $finish;
end

endmodule

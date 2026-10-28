`timescale 1ns/1ps

module video_bright_contrast (
    input  wire              I_pix_clk,
    input  wire              I_rst,
    input  wire              I_de,
    input  wire              I_vs,
    input  wire [23:0]       I_rgb,
    input  wire signed [7:0] I_bright,
    input  wire [8:0]        I_gain,
    input  wire [1:0]        I_filter,
    output reg  [23:0]       O_rgb,
    output reg               O_de,
    output reg               O_vs
);
    wire signed [9:0] gain_s = {1'b0, I_gain};

    wire signed [9:0] r_s = $signed({2'b00, I_rgb[23:16]}) - 10'sd128;
    wire signed [9:0] g_s = $signed({2'b00, I_rgb[15:8]})  - 10'sd128;
    wire signed [9:0] b_s = $signed({2'b00, I_rgb[7:0]})   - 10'sd128;

    reg signed [19:0] r_m, g_m, b_m;
    reg               de_d1, vs_d1;

    always @(posedge I_pix_clk or posedge I_rst) begin
        if (I_rst) begin
            r_m   <= 20'sd0;
            g_m   <= 20'sd0;
            b_m   <= 20'sd0;
            de_d1 <= 1'b0;
            vs_d1 <= 1'b0;
        end else begin
            r_m   <= r_s * gain_s;
            g_m   <= g_s * gain_s;
            b_m   <= b_s * gain_s;
            de_d1 <= I_de;
            vs_d1 <= I_vs;
        end
    end

    wire signed [19:0] b_ext = {{12{I_bright[7]}}, I_bright};

    wire signed [19:0] r_v = (r_m >>> 8) + 20'sd128 + b_ext;
    wire signed [19:0] g_v = (g_m >>> 8) + 20'sd128 + b_ext;
    wire signed [19:0] b_v = (b_m >>> 8) + 20'sd128 + b_ext;

    wire [7:0] r_o = (r_v < 20'sd0) ? 8'd0 : (r_v > 20'sd255) ? 8'd255 : r_v[7:0];
    wire [7:0] g_o = (g_v < 20'sd0) ? 8'd0 : (g_v > 20'sd255) ? 8'd255 : g_v[7:0];
    wire [7:0] b_o = (b_v < 20'sd0) ? 8'd0 : (b_v > 20'sd255) ? 8'd255 : b_v[7:0];

    //-------------------------------------------------- 滤镜（无行缓存、零延迟）

    wire [15:0] luma16 = ({8'd0, r_o} << 6) + ({8'd0, r_o} << 3) + ({8'd0, r_o} << 2) + {8'd0, r_o}
                       + ({8'd0, g_o} << 7) + ({8'd0, g_o} << 4) + ({8'd0, g_o} << 2) + ({8'd0, g_o} << 1)
                       + ({8'd0, b_o} << 4) + ({8'd0, b_o} << 3) + ({8'd0, b_o} << 2) + {8'd0, b_o};
    wire [7:0]  luma   = luma16[15:8];

    wire [7:0] r_f = (I_filter == 2'd1) ? (8'd255 - r_o) :
                     (I_filter == 2'd2) ? luma : r_o;
    wire [7:0] g_f = (I_filter == 2'd1) ? (8'd255 - g_o) :
                     (I_filter == 2'd2) ? luma : g_o;
    wire [7:0] b_f = (I_filter == 2'd1) ? (8'd255 - b_o) :
                     (I_filter == 2'd2) ? luma : b_o;

    always @(posedge I_pix_clk or posedge I_rst) begin
        if (I_rst) begin
            O_rgb <= 24'd0;
            O_de  <= 1'b0;
            O_vs  <= 1'b0;
        end else begin
            O_rgb <= {r_f, g_f, b_f};
            O_de  <= de_d1;
            O_vs  <= vs_d1;
        end
    end
endmodule

module adj_key_ctrl #(
    parameter [19:0] CNT_DEB  = 20'd400_000,
    parameter [22:0] CNT_DBL  = 23'd8_000_000,       // 双击窗口 320ms @25MHz
    parameter [25:0] CNT_SHOW = 26'd37_500_000       // 约 1.5s @25MHz
)(
    input  wire              I_clk,
    input  wire              I_rst,
    input  wire [3:0]        I_key,
    output reg  signed [7:0] O_bright,
    output reg  [8:0]        O_gain,
    output reg  [1:0]        O_filter,
    output reg               O_track_evt,
    output wire              O_show
);
    reg [3:0] key_s1, key_s2;

    always @(posedge I_clk or posedge I_rst) begin
        if (I_rst) begin
            key_s1 <= 4'hF;
            key_s2 <= 4'hF;
        end else begin
            key_s1 <= I_key;
            key_s2 <= key_s1;
        end
    end

    wire [3:0] pressed;

    genvar gi;
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : g_deb
            reg [19:0] cnt;
            reg        lvl;
            reg        lvl_d;

            always @(posedge I_clk or posedge I_rst) begin
                if (I_rst) begin
                    cnt   <= 20'd0;
                    lvl   <= 1'b1;
                    lvl_d <= 1'b1;
                end else begin
                    lvl_d <= lvl;
                    if (key_s2[gi] != lvl) begin
                        if (cnt >= CNT_DEB) begin
                            lvl <= key_s2[gi];
                            cnt <= 20'd0;
                        end else begin
                            cnt <= cnt + 20'd1;
                        end
                    end else begin
                        cnt <= 20'd0;
                    end
                end
            end

            assign pressed[gi] = lvl_d & ~lvl;
        end
    endgenerate

    wire b_dn = pressed[0];
    wire b_up = pressed[1];
    wire c_dn = pressed[2];
    wire c_up = pressed[3];

    //------------------------------------------------- KEY3 单击/双击识别

    reg        dbl_win;
    reg [22:0] dbl_cnt;
    reg [2:0]  click_cnt;
    reg        single_apply;     // 单击动作脉冲（窗口超时）
    reg        dbl_pulse;        // 双击脉冲

    always @(posedge I_clk or posedge I_rst) begin
        if (I_rst) begin
            dbl_win      <= 1'b0;
            dbl_cnt      <= 23'd0;
            click_cnt    <= 3'd0;
            single_apply <= 1'b0;
            dbl_pulse    <= 1'b0;
            O_track_evt  <= 1'b0;
        end else begin
            single_apply <= 1'b0;
            dbl_pulse    <= 1'b0;
            O_track_evt  <= 1'b0;

            if (b_dn) begin
                dbl_win   <= 1'b1;
                dbl_cnt   <= CNT_DBL;
                if (click_cnt < 3'd7)
                    click_cnt <= click_cnt + 3'd1;
            end else if (dbl_win) begin
                if (dbl_cnt == 23'd0) begin
                    dbl_win   <= 1'b0;
                    click_cnt <= 3'd0;
                    case (click_cnt)
                        3'd1: single_apply <= 1'b1;
                        3'd2: dbl_pulse    <= 1'b1;
                        default: O_track_evt <= 1'b1;
                    endcase
                end else begin
                    dbl_cnt <= dbl_cnt - 23'd1;
                end
            end
        end
    end

    always @(posedge I_clk or posedge I_rst) begin
        if (I_rst)
            O_filter <= 2'd0;
        else if (dbl_pulse)
            O_filter <= (O_filter >= 2'd2) ? 2'd0 : (O_filter + 2'd1);   // 0→1→2→0
    end

    always @(posedge I_clk or posedge I_rst) begin
        if (I_rst)
            O_bright <= 8'sd0;
        else if (b_up)
            O_bright <= (O_bright > 8'sd15) ? 8'sd31 : (O_bright + 8'sd16);
        else if (single_apply)
            O_bright <= (O_bright < -8'sd16) ? -8'sd32 : (O_bright - 8'sd16);
    end

    always @(posedge I_clk or posedge I_rst) begin
        if (I_rst)
            O_gain <= 9'd256;
        else if (c_up)
            O_gain <= (O_gain > 9'd320) ? 9'd384 : (O_gain + 9'd64);        // 对比度步长 64（再翻倍）
        else if (c_dn)
            O_gain <= (O_gain < 9'd192) ? 9'd128 : (O_gain - 9'd64);
    end

    reg [25:0] show_cnt;

    always @(posedge I_clk or posedge I_rst) begin
        if (I_rst)
            show_cnt <= 26'd0;
        else if (b_up | single_apply | c_dn | c_up)
            show_cnt <= CNT_SHOW;
        else if (show_cnt != 26'd0)
            show_cnt <= show_cnt - 26'd1;
    end

    assign O_show = (show_cnt != 26'd0);
endmodule

module adj_osd #(
    parameter H_ACTIVE = 640,
    parameter V_ACTIVE = 480,
    parameter X0       = 16,
    parameter Y0       = 16
)(
    input  wire              I_pix_clk,
    input  wire              I_rst,
    input  wire              I_de,
    input  wire              I_vs,
    input  wire [23:0]       I_rgb,
    input  wire signed [7:0] I_bright,
    input  wire [8:0]        I_gain,
    input  wire              I_active,
    output reg  [23:0]       O_rgb
);
    localparam CW = 16;
    localparam CH = 16;
    localparam NCOL = 5;

    reg [9:0] x, y;
    reg       vs_d;

    always @(posedge I_pix_clk or posedge I_rst) begin
        if (I_rst) begin
            x    <= 10'd0;
            y    <= 10'd0;
            vs_d <= 1'b0;
        end else begin
            vs_d <= I_vs;
            if ((I_vs != vs_d) && !I_de) begin
                x <= 10'd0;
                y <= 10'd0;
            end else if (I_de) begin
                if (x == H_ACTIVE - 1) begin
                    x <= 10'd0;
                    y <= (y == V_ACTIVE - 1) ? 10'd0 : (y + 10'd1);
                end else begin
                    x <= x + 10'd1;
                end
            end
        end
    end

    localparam BX = X0 - 4;
    localparam BY = Y0 - 4;
    localparam BW = NCOL * CW + 8;
    localparam BH = 2 * CH + 8;

    wire in_box = (x >= BX) && (x < BX + BW) && (y >= BY) && (y < BY + BH);
    wire in_txt = (x >= X0) && (x < X0 + NCOL * CW) &&
                  (y >= Y0) && (y < Y0 + 2 * CH);

    wire [9:0] sx   = x - X0;
    wire [9:0] sy   = y - Y0;
    wire [2:0] col  = sx[8:4];
    wire [3:0] bcol = sx[3:0];
    wire [1:0] line = sy[5:4];
    wire [3:0] brow = sy[3:0];

    wire signed [8:0] b_sgn  = {{1{I_bright[7]}}, I_bright};
    wire [8:0]        b_mag  = b_sgn[8] ? (~b_sgn + 9'd1) : b_sgn;
    wire [8:0]        b_tens = b_mag / 9'd10;
    wire [8:0]        b_ones = b_mag % 9'd10;

    wire [9:0] g10    = {1'b0, I_gain};
    wire [9:0] c_int  = (g10 >= 10'd256) ? 10'd1 : 10'd0;
    wire [9:0] c_rem  = (g10 - c_int * 10'd256) >> 4;
    wire [9:0] c_frac = (c_rem * 10'd25) >> 2;
    wire [9:0] c_tens = c_frac / 10'd10;
    wire [9:0] c_ones = c_frac % 10'd10;

    reg [3:0] code;

    always @(*) begin
        code = 4'd15;
        if (I_active && in_txt) begin
            case (line)
            2'd0: begin
                case (col)
                3'd0:    code = 4'd13;                          // 'B'
                3'd1:    code = I_bright[7] ? 4'd11 : 4'd10;    // '-' / '+'
                3'd2:    code = b_tens[3:0];
                3'd3:    code = b_ones[3:0];
                default: code = 4'd15;
                endcase
            end
            2'd1: begin
                case (col)
                3'd0:    code = 4'd14;                          // 'C'
                3'd1:    code = c_int[3:0];
                3'd2:    code = 4'd12;                          // '.'
                3'd3:    code = c_tens[3:0];
                3'd4:    code = c_ones[3:0];
                default: code = 4'd15;
                endcase
            end
            default: code = 4'd15;
            endcase
        end
    end

    wire [7:0]  rom_addr = {code, brow};
    wire [15:0] glyph;

    adj_font_rom u_adj_font_rom (
        .I_addr (rom_addr),
        .O_bits (glyph)
    );

    wire pix_on = in_txt && glyph[15 - bcol];

    always @(*) begin
        if (!in_box || !I_active)
            O_rgb = I_rgb;
        else if (pix_on)
            O_rgb = 24'hFF_FF_00;
        else
            O_rgb = 24'h00_00_00;
    end
endmodule

module adj_font_rom (
    input  wire [7:0]   I_addr,
    output reg  [15:0]  O_bits
);

    always @(*) begin
        case (I_addr)
            8'h03: O_bits = 16'h0180;
            8'h04: O_bits = 16'h0240;
            8'h05: O_bits = 16'h0660;
            8'h06: O_bits = 16'h0420;
            8'h07: O_bits = 16'h0420;
            8'h08: O_bits = 16'h0420;
            8'h09: O_bits = 16'h0420;
            8'h0A: O_bits = 16'h0420;
            8'h0B: O_bits = 16'h0660;
            8'h0C: O_bits = 16'h0240;
            8'h0D: O_bits = 16'h0180;
            8'h13: O_bits = 16'h0080;
            8'h14: O_bits = 16'h0380;
            8'h15: O_bits = 16'h0080;
            8'h16: O_bits = 16'h0080;
            8'h17: O_bits = 16'h0080;
            8'h18: O_bits = 16'h0080;
            8'h19: O_bits = 16'h0080;
            8'h1A: O_bits = 16'h0080;
            8'h1B: O_bits = 16'h0080;
            8'h1C: O_bits = 16'h0080;
            8'h1D: O_bits = 16'h03E0;
            8'h23: O_bits = 16'h03C0;
            8'h24: O_bits = 16'h0460;
            8'h25: O_bits = 16'h0420;
            8'h26: O_bits = 16'h0420;
            8'h27: O_bits = 16'h0020;
            8'h28: O_bits = 16'h0040;
            8'h29: O_bits = 16'h0080;
            8'h2A: O_bits = 16'h0100;
            8'h2B: O_bits = 16'h0200;
            8'h2C: O_bits = 16'h0420;
            8'h2D: O_bits = 16'h07E0;
            8'h33: O_bits = 16'h03C0;
            8'h34: O_bits = 16'h0460;
            8'h35: O_bits = 16'h0420;
            8'h36: O_bits = 16'h0020;
            8'h37: O_bits = 16'h0040;
            8'h38: O_bits = 16'h0180;
            8'h39: O_bits = 16'h0040;
            8'h3A: O_bits = 16'h0020;
            8'h3B: O_bits = 16'h0420;
            8'h3C: O_bits = 16'h0460;
            8'h3D: O_bits = 16'h03C0;
            8'h43: O_bits = 16'h0040;
            8'h44: O_bits = 16'h00C0;
            8'h45: O_bits = 16'h00C0;
            8'h46: O_bits = 16'h0140;
            8'h47: O_bits = 16'h0340;
            8'h48: O_bits = 16'h0240;
            8'h49: O_bits = 16'h0440;
            8'h4A: O_bits = 16'h07F0;
            8'h4B: O_bits = 16'h0040;
            8'h4C: O_bits = 16'h0040;
            8'h4D: O_bits = 16'h01F0;
            8'h53: O_bits = 16'h07E0;
            8'h54: O_bits = 16'h0400;
            8'h55: O_bits = 16'h0400;
            8'h56: O_bits = 16'h0400;
            8'h57: O_bits = 16'h07C0;
            8'h58: O_bits = 16'h0460;
            8'h59: O_bits = 16'h0020;
            8'h5A: O_bits = 16'h0020;
            8'h5B: O_bits = 16'h0420;
            8'h5C: O_bits = 16'h0460;
            8'h5D: O_bits = 16'h03C0;
            8'h63: O_bits = 16'h01C0;
            8'h64: O_bits = 16'h0240;
            8'h65: O_bits = 16'h0400;
            8'h66: O_bits = 16'h0400;
            8'h67: O_bits = 16'h05C0;
            8'h68: O_bits = 16'h0660;
            8'h69: O_bits = 16'h0420;
            8'h6A: O_bits = 16'h0420;
            8'h6B: O_bits = 16'h0420;
            8'h6C: O_bits = 16'h0260;
            8'h6D: O_bits = 16'h03C0;
            8'h73: O_bits = 16'h07E0;
            8'h74: O_bits = 16'h0400;
            8'h75: O_bits = 16'h0040;
            8'h78: O_bits = 16'h0080;
            8'h7A: O_bits = 16'h0100;
            8'h7B: O_bits = 16'h0100;
            8'h7C: O_bits = 16'h0100;
            8'h7D: O_bits = 16'h0100;
            8'h83: O_bits = 16'h03C0;
            8'h84: O_bits = 16'h0660;
            8'h85: O_bits = 16'h0420;
            8'h86: O_bits = 16'h0420;
            8'h87: O_bits = 16'h0340;
            8'h88: O_bits = 16'h03C0;
            8'h89: O_bits = 16'h0660;
            8'h8A: O_bits = 16'h0420;
            8'h8B: O_bits = 16'h0420;
            8'h8C: O_bits = 16'h0660;
            8'h8D: O_bits = 16'h03C0;
            8'h93: O_bits = 16'h03C0;
            8'h94: O_bits = 16'h0640;
            8'h95: O_bits = 16'h0420;
            8'h96: O_bits = 16'h0420;
            8'h97: O_bits = 16'h0420;
            8'h98: O_bits = 16'h0660;
            8'h99: O_bits = 16'h03A0;
            8'h9A: O_bits = 16'h0020;
            8'h9B: O_bits = 16'h0040;
            8'h9C: O_bits = 16'h0240;
            8'h9D: O_bits = 16'h0380;
            8'hA4: O_bits = 16'h0080;
            8'hA5: O_bits = 16'h0080;
            8'hA6: O_bits = 16'h0080;
            8'hA7: O_bits = 16'h0080;
            8'hA8: O_bits = 16'h07F0;
            8'hA9: O_bits = 16'h0080;
            8'hAA: O_bits = 16'h0080;
            8'hAB: O_bits = 16'h0080;
            8'hAC: O_bits = 16'h0080;
            8'hB8: O_bits = 16'h07E0;
            8'hCC: O_bits = 16'h0600;
            8'hCD: O_bits = 16'h0600;
            8'hD3: O_bits = 16'h0FC0;
            8'hD4: O_bits = 16'h0460;
            8'hD5: O_bits = 16'h0420;
            8'hD6: O_bits = 16'h0420;
            8'hD7: O_bits = 16'h0440;
            8'hD8: O_bits = 16'h0780;
            8'hD9: O_bits = 16'h0460;
            8'hDA: O_bits = 16'h0420;
            8'hDB: O_bits = 16'h0420;
            8'hDC: O_bits = 16'h0460;
            8'hDD: O_bits = 16'h0FC0;
            8'hE3: O_bits = 16'h01E0;
            8'hE4: O_bits = 16'h0260;
            8'hE5: O_bits = 16'h0620;
            8'hE6: O_bits = 16'h0400;
            8'hE7: O_bits = 16'h0400;
            8'hE8: O_bits = 16'h0400;
            8'hE9: O_bits = 16'h0400;
            8'hEA: O_bits = 16'h0400;
            8'hEB: O_bits = 16'h0620;
            8'hEC: O_bits = 16'h0240;
            8'hED: O_bits = 16'h01C0;
            default: O_bits = 16'h0000;
        endcase
    end

endmodule

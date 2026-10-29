`timescale 1ns/1ps

module tb_audio_wave;

localparam integer H_ACT = 640;
localparam integer V_ACT = 480;
localparam integer CLK_P = 40;           // 25MHz
localparam [23:0] GRAY  = 24'h808080;

localparam integer X0 = 430, Y0 = 10, W = 200, H = 72;
localparam integer NB = 8, PITCH = 24, BARW = 16;
localparam integer XBAR0 = X0 + (W - NB*PITCH)/2;
localparam integer Y_BOT = Y0 + H - 2;

localparam [23:0] C_BORDER = 24'h7A8EA0;
localparam [23:0] C_BG     = 24'h0A121A;
localparam [23:0] C_LOW    = 24'h30C050;
localparam [23:0] C_MID    = 24'hE0D040;
localparam [23:0] C_HIGH   = 24'hF06030;
localparam [23:0] C_BASE   = 24'h1E3040;

reg clk = 1'b0;
reg rst = 1'b1;
reg hs_i = 1'b0, vs_i = 1'b1, de_i = 1'b0;
reg [23:0] rgb_i = 24'd0;
reg [23:0] audio_l = 24'sd0;
reg        audio_valid = 1'b0;

wire hs_o, vs_o, de_o;
wire [23:0] rgb_o;

always #(CLK_P/2) clk = ~clk;

audio_wave #(
    .H_ACTIVE (H_ACT),
    .X0 (X0), .Y0 (Y0), .W (W), .H (H),
    .NB (NB), .PITCH (PITCH), .BARW (BARW)
) dut (
    .clk (clk), .rst (rst),
    .audio_l (audio_l), .audio_valid (audio_valid),
    .hs_i (hs_i), .vs_i (vs_i), .de_i (de_i), .rgb_i (rgb_i),
    .hs_o (hs_o), .vs_o (vs_o), .de_o (de_o), .rgb_o (rgb_o)
);

//-------------------------------------------------- 音频源：48kHz 方波
reg [8:0] aud_cnt = 9'd0;
reg [8:0] phase   = 9'd0;
reg [7:0] half_per = 8'd24;          // 半周期 24 点 -> 1kHz
reg       audio_on = 1'b0;

always @(posedge clk) begin
    if (rst) begin
        aud_cnt     <= 9'd0;
        audio_valid <= 1'b0;
        audio_l     <= 24'sd0;
        phase       <= 9'd0;
    end else begin
        if (aud_cnt == 9'd519) begin
            aud_cnt     <= 9'd0;
            audio_valid <= 1'b1;
            audio_l     <= audio_on ? ((phase < half_per) ? 24'sd2000000 : -24'sd2000000)
                                    : 24'sd0;
            if (audio_on) begin
                if (phase >= (2*half_per - 1)) phase <= 9'd0;
                else                           phase <= phase + 9'd1;
            end
        end else begin
            aud_cnt     <= aud_cnt + 9'd1;
            audio_valid <= 1'b0;
        end
    end
end

//-------------------------------------------------- 帧扫描统计
integer px = 0, py = 0;
integer bar_top [0:NB-1];
integer b, k;
integer out_bad = 0, border_bad = 0, bar_pix = 0, bad_col = 0;
integer errors = 0;
integer fdump = 0;
reg     dump_en = 1'b0;
reg     bg_pat  = 1'b0;
integer check_en = 1;

task automatic clear_heights;
    begin
        for (k = 0; k < NB; k = k + 1) bar_top[k] = -1;
    end
endtask

function [23:0] bg_col;
    input [9:0] xx, yy;
    begin
        bg_col = bg_pat ? {xx[7:0], yy[7:0], 8'h40} : GRAY;
    end
endfunction

always @(negedge clk) begin
    if (de_o) begin
        if (px >= X0 && px < X0+W && py >= Y0 && py < Y0+H) begin
            if (rgb_o == C_LOW || rgb_o == C_MID || rgb_o == C_HIGH) begin
                bar_pix = bar_pix + 1;
                for (b = 0; b < NB; b = b + 1) begin
                    if (px == XBAR0 + b*PITCH + BARW/2) begin
                        if (bar_top[b] < 0 || py < bar_top[b]) bar_top[b] = py;
                    end
                end
            end else if (rgb_o !== bg_col(px, py)) begin
                if (check_en) bad_col = bad_col + 1;
            end
            if (dump_en)
                $fwrite(fdump, "%0d %0d %06x\n", px-X0, py-Y0, rgb_o);
        end else begin
            if (rgb_o !== bg_col(px, py)) begin
                if (check_en) out_bad = out_bad + 1;
            end
        end

        px = px + 1;
        if (px == H_ACT) begin
            px = 0;
            py = py + 1;
        end
    end
end

//-------------------------------------------------- 激励
task automatic chk(input [255:0] name, input integer cond);
    begin
        if (!cond) begin
            errors = errors + 1;
            $display("  [FAIL] %0s", name);
        end
    end
endtask

task automatic one_frame(input integer with_audio);
    integer y, x;
    begin
        audio_on = with_audio;
        bar_pix  = 0; out_bad = 0; bad_col = 0;
        px = 0; py = 0;
        clear_heights;
        vs_i = 1'b0;
        repeat (2) begin hs_i = 1'b1; #(CLK_P); hs_i = 1'b0; #(CLK_P); end
        vs_i = 1'b1;
        #(CLK_P);
        for (y = 0; y < V_ACT; y = y + 1) begin
            hs_i = 1'b1; #(CLK_P);
            hs_i = 1'b0; #(CLK_P);
            de_i = 1'b1;
            for (x = 0; x < H_ACT; x = x + 1) begin
                rgb_i = bg_pat ? {x[7:0], y[7:0], 8'h40} : GRAY;
                #(CLK_P);
            end
            de_i = 1'b0;
            rgb_i = 24'd0;
            #(CLK_P);
        end
        repeat (2) begin hs_i = 1'b1; #(CLK_P); hs_i = 1'b0; #(CLK_P); end
        #(20*CLK_P);
    end
endtask

integer h_now;
integer n_tall, h_max;
initial begin
    $display("============================================================");
    $display(" tb_audio_wave: %0dx%0d, %0d bars", H_ACT, V_ACT, NB);
    $display("============================================================");

    rst = 1'b1;
    repeat (20) @(posedge clk);
    rst = 1'b0;
    repeat (50) @(posedge clk);

    // 1) 静音两帧
    one_frame(0);
    one_frame(0);
    chk("silence: no bars", bar_pix == 0);
    chk("silence: outside pass-through", out_bad == 0);
    $display(" silent frame: bars=%0d border_bad=%0d out_bad=%0d", bar_pix, border_bad, out_bad);

    one_frame(1); one_frame(1); one_frame(1);
    one_frame(1); one_frame(1);
    fdump = $fopen("bars_frame.txt", "w");
    dump_en = 1'b1;
    one_frame(1);
    dump_en = 1'b0;
    $fclose(fdump);

    check_en = 0;
    bg_pat   = 1'b1;
    fdump    = $fopen("bars_frame_bg.txt", "w");
    dump_en  = 1'b1;
    one_frame(1);
    dump_en  = 1'b0;
    $fclose(fdump);
    bg_pat   = 1'b0;
    check_en = 1;

    chk("audio: has bars", bar_pix > 100);
    chk("audio: outside pass-through", out_bad == 0);
    chk("audio: no stray colour", bad_col == 0);
    $display(" audio frame: bars=%0d border_bad=%0d out_bad=%0d bad_col=%0d", bar_pix, border_bad, out_bad, bad_col);

    n_tall = 0; h_max = 0;
    for (k = 0; k < NB; k = k + 1) begin
        h_now = (bar_top[k] < 0) ? 0 : (Y_BOT - bar_top[k] + 1);
        $display("   bar%0d height=%0d", k, h_now);
        if (h_now > 2) n_tall = n_tall + 1;
        if (h_now > h_max) h_max = h_now;
    end
    chk("audio: at least 4 bars visible", n_tall >= 4);
    chk("audio: tallest bar > 8 px", h_max > 8);

    $display(" errors=%0d", errors);
    $display(" RESULT: %s", (errors == 0) ? "PASS" : "FAIL");
    $finish;
end

endmodule

`timescale 1ns/1ps

module tb_audio_wav;

localparam real    MCLK_HALF = 40.69;      // 12.288MHz
localparam integer NPUSH     = 1000;
localparam integer NCAP      = 3000;

reg I_mclk = 1'b0;
always #(MCLK_HALF) I_mclk = ~I_mclk;

reg I_wr_clk = 1'b0;
always #5 I_wr_clk = ~I_wr_clk;            // 100MHz

reg        rst = 1'b1;
reg        wr_en = 1'b0;
reg [23:0] wr_data = 24'd0;

wire O_i2s_BCLK, O_i2s_LRCK, O_i2s_DOUT;
wire wav_need, wav_mode;

hdmi_audio_melody_i2s_64fs #(
    .BPM (72), .NOTE_NUM (142)
) dut (
    .I_mclk        (I_mclk),
    .I_rst         (rst),
    .I_wav_wr_clk  (I_wr_clk),
    .I_wav_wr_en   (wr_en),
    .I_wav_wr_data (wr_data),
    .O_wav_need    (wav_need),
    .I_wav_only    (1'b1),          // 只放 WAV
    .I_wav_flush   (1'b0),
    .O_wav_mode    (wav_mode),
    .O_i2s_BCLK    (O_i2s_BCLK),
    .O_i2s_LRCK    (O_i2s_LRCK),
    .O_i2s_DOUT    (O_i2s_DOUT)
);

//-------------------------------------------------- 每个帧边界取一个样点
integer    ncap = 0;
reg [23:0] cap [0:NCAP-1];

always @(posedge O_i2s_LRCK) begin
    if (!rst) begin
        if (ncap < NCAP) cap[ncap] = dut.S_sample_word;
        ncap = ncap + 1;
    end
end

//-------------------------------------------------- 灌数据 + 检查
integer k, q, found_off, matched, errors;

initial begin
    $display("============================================================");
    $display(" tb_audio_wav: push %0d samples, check sample stream", NPUSH);
    $display("============================================================");

    rst = 1'b1;
    repeat (40) @(posedge I_mclk);
    rst = 1'b0;
    repeat (40) @(posedge I_mclk);

    for (k = 0; k < NPUSH; k = k + 1) begin
        @(posedge I_wr_clk);
        wr_en   <= 1'b1;
        wr_data <= 24'h1000 + k;
    end
    @(posedge I_wr_clk);
    wr_en <= 1'b0;

    repeat (1600000) @(posedge I_mclk);

    $display("  captured %0d frames", ncap);

    found_off = -1;
    for (k = 0; k < (ncap - NPUSH) && (found_off < 0); k = k + 1) begin
        if (cap[k] === 24'h001000) begin
            matched = 1;
            for (q = 0; q < NPUSH; q = q + 1)
                if (cap[k+q] !== (24'h1000 + q)) matched = 0;
            if (matched) found_off = k;
        end
    end

    errors = 0;
    if (found_off < 0) begin
        $display("  [FAIL] 没找到连续的 WAV 样点序列");
        for (k = 0; k < 8; k = k + 1)
            $display("    cap[%0d]=%06x", k, cap[k]);
        errors = errors + 1;
    end else begin
        $display("  WAV 序列出现在第 %0d 帧，%0d 个样点全部匹配", found_off, NPUSH);
    end

    if (found_off >= 0) begin
        q = 0;
        for (k = found_off + NPUSH; k < found_off + NPUSH + 100; k = k + 1)
            if (cap[k] !== 24'd0) q = q + 1;
        if (q != 0) begin
            $display("  [FAIL] 放完后的 %0d 帧不是静音（会和旋律混在一起）", q);
            errors = errors + 1;
        end else begin
            $display("  放完后的 100 帧是静音（不会混入旋律）");
        end
    end

    if (wav_mode !== 1'b1) begin
        $display("  [WARN] 放完后没有锁定在 WAV 模式（wav_mode=%0d）", wav_mode);
    end else begin
        $display("  放完后保持 WAV 模式（不回退旋律，避免叠加）");
    end

    $display(" RESULT: %s", (errors == 0) ? "PASS" : "FAIL");
    $finish;
end

endmodule

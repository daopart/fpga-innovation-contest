`timescale 1ns / 1ps

module tb_audio_melody;

    localparam real    MCLK_HALF_NS = 40.69;      // 12.288MHz 半周期
    localparam integer SIM_SECONDS  = 6;          // 仿真时长（秒）
    localparam integer FRAMES_TOTAL = 48000 * SIM_SECONDS;

    reg  I_mclk = 1'b0;
    reg  I_rst  = 1'b1;

    wire O_i2s_BCLK;
    wire O_i2s_LRCK;
    wire O_i2s_DOUT;

    hdmi_audio_melody_i2s_64fs #(
        .BPM (72)
    ) dut (
        .I_mclk     (I_mclk),
        .I_rst      (I_rst),
        .O_i2s_BCLK (O_i2s_BCLK),
        .O_i2s_LRCK (O_i2s_LRCK),
        .O_i2s_DOUT (O_i2s_DOUT)
    );

    // ------------------------------------------------------------ 时钟 & 复位
    always #(MCLK_HALF_NS) I_mclk = ~I_mclk;

    initial begin
        I_rst = 1'b1;
        repeat (40) @(posedge I_mclk);
        I_rst = 1'b0;
    end

    // ------------------------------------------------------------ 采集
    integer    fd;
    integer    frame_cnt = 0;
    integer    nonzero   = 0;
    integer    peak      = 0;
    integer    struct_err = 0;
    integer    v;
    integer    bclk_cnt = 0;
    reg [23:0] ch_sample;

    initial begin
        fd = $fopen("audio_melody_samples.txt", "w");
        if (fd == 0) begin
            $display("ERROR: cannot open audio_melody_samples.txt");
            $finish;
        end
    end

    always @(posedge O_i2s_BCLK) bclk_cnt = bclk_cnt + 1;

    always @(posedge O_i2s_LRCK) begin
        if (!I_rst) begin

            if ((bclk_cnt != 128) && (frame_cnt > 1)) begin
                struct_err = struct_err + 1;
                if (struct_err < 5)
                    $display("WARN: frame %0d bclk_cnt=%0d", frame_cnt, bclk_cnt);
            end
            bclk_cnt = 0;

            ch_sample = dut.S_sample_word;
            $fwrite(fd, "L %06h\n", ch_sample);

            frame_cnt = frame_cnt + 1;
            v = ch_sample[23] ? (16777216 - ch_sample) : ch_sample;
            if (v != 0) nonzero = nonzero + 1;
            if (v > peak) peak = v;

            if (frame_cnt >= FRAMES_TOTAL) begin
                $fwrite(fd, "# frames=%0d nonzero=%0d peak=%0d struct_err=%0d\n",
                        frame_cnt, nonzero, peak, struct_err);
                $fclose(fd);
                $display("# frames=%0d nonzero=%0d peak=%0d struct_err=%0d",
                         frame_cnt, nonzero, peak, struct_err);
                $display("# RESULT: %s", (struct_err == 0) ? "PASS" : "FAIL");
                $finish;
            end
        end
    end

    initial begin
        #(SIM_SECONDS * 1.0e9 + 1.0e5);
        $display("# TIMEOUT frames=%0d nonzero=%0d peak=%0d", frame_cnt, nonzero, peak);
        $fclose(fd);
        $finish;
    end

endmodule

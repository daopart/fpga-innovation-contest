module hdmi_audio_melody_i2s_64fs #(
    parameter integer BPM         = 72,      // 速度
    parameter integer LOOP_GAP_MS = 1200,    // 一遍结束后的静音
    parameter integer ENV_STEP    = 2,
    parameter integer REL_SAMPLES = 480,     // 音符末尾做释放的采样数（10ms）
    parameter integer NOTE_NUM    = 142,

    parameter integer MELODY_ENABLE = 0,
    parameter integer HARM2_SHIFT = 2
)(
    input  wire I_mclk,      // 12.288MHz
    input  wire I_rst,       // 高有效

    input  wire        I_wav_wr_clk,        // sd_card_clk
    input  wire        I_wav_wr_en,
    input  wire [23:0] I_wav_wr_data,
    output wire        O_wav_need,
    input  wire        I_wav_only,
    input  wire        I_wav_flush,
    output reg         O_wav_mode,

    output reg  O_i2s_BCLK,
    output reg  O_i2s_LRCK,
    output reg  O_i2s_DOUT
);

    // 每 1/2 拍的采样数（48kHz）
    localparam integer SPB_HALF    = (60 * 48000) / (2 * BPM);
    localparam integer GAP_SAMPLES = 48 * LOOP_GAP_MS;

    localparam [7:0]  ENV_STEP_B = ENV_STEP;
    localparam [16:0] GAP_CNT    = GAP_SAMPLES[16:0];
    localparam [17:0] REL_S      = REL_SAMPLES;

    // ------------------------------------------------------------ 播放状态
    reg [11:0] S_idx;          // 当前音符序号
    reg [17:0] S_pos;          // 当前音符内第几个采样
    reg [31:0] S_phase;        // 相位累加器
    reg [7:0]  S_env;          // 包络 0..255
    reg [16:0] S_gap;          // 循环静音倒计时

    wire [5:0] W_semi;
    wire [3:0] W_dur_q2;

    // ---------------------------------------------------------------- 音符表
    generate
        if (MELODY_ENABLE != 0) begin : g_melody
            melody_rom #(
                .NOTE_NUM (NOTE_NUM)
            ) u_melody_rom (
                .I_idx    (S_idx),
                .O_semi   (W_semi),
                .O_dur_q2 (W_dur_q2)
            );
        end else begin : g_no_melody

            assign W_semi   = 6'd0;
            assign W_dur_q2 = 4'd2;
        end
    endgenerate

    // ------------------------------------------------------- 半音 -> 相位步进

    function [31:0] semi_step;
        input [7:0] s;
        begin
            case (s)
                8'd0 : semi_step = 32'd7373644;    // E2    82.41Hz
                8'd1 : semi_step = 32'd7812103;    // F2    87.31Hz
                8'd2 : semi_step = 32'd8276635;    // F#2   92.50Hz
                8'd3 : semi_step = 32'd8768789;    // G2    98.00Hz
                8'd4 : semi_step = 32'd9290209;    // G#2  103.83Hz
                8'd5 : semi_step = 32'd9842633;    // A2   110.00Hz
                8'd6 : semi_step = 32'd10427907;   // A#2  116.54Hz
                8'd7 : semi_step = 32'd11047982;   // B2   123.47Hz
                8'd8 : semi_step = 32'd11704930;   // C3   130.81Hz
                8'd9 : semi_step = 32'd12400941;   // C#3  138.59Hz
                8'd10: semi_step = 32'd13138339;   // D3   146.83Hz
                8'd11: semi_step = 32'd13919586;   // D#3  155.56Hz
                8'd12: semi_step = 32'd14747287;   // E3   164.81Hz
                8'd13: semi_step = 32'd15624207;   // F3   174.61Hz
                8'd14: semi_step = 32'd16553270;   // F#3  185.00Hz
                8'd15: semi_step = 32'd17537579;   // G3   196.00Hz
                8'd16: semi_step = 32'd18580418;   // G#3  207.65Hz
                8'd17: semi_step = 32'd19685267;   // A3   220.00Hz
                8'd18: semi_step = 32'd20855814;   // A#3  233.08Hz
                8'd19: semi_step = 32'd22095965;   // B3   246.94Hz
                8'd20: semi_step = 32'd23409859;   // C4   261.63Hz
                8'd21: semi_step = 32'd24801882;   // C#4  277.18Hz
                8'd22: semi_step = 32'd26276679;   // D4   293.66Hz
                8'd23: semi_step = 32'd27839171;   // D#4  311.13Hz
                8'd24: semi_step = 32'd29494575;   // E4   329.63Hz
                8'd25: semi_step = 32'd31248413;   // F4   349.23Hz
                8'd26: semi_step = 32'd33106541;   // F#4  369.99Hz
                8'd27: semi_step = 32'd35075158;   // G4   392.00Hz
                8'd28: semi_step = 32'd37160835;   // G#4  415.30Hz
                8'd29: semi_step = 32'd39370534;   // A4   440.00Hz
                8'd30: semi_step = 32'd41711627;   // A#4  466.16Hz
                8'd31: semi_step = 32'd44191930;   // B4   493.88Hz
                8'd32: semi_step = 32'd46819719;   // C5   523.25Hz
                8'd33: semi_step = 32'd49603764;   // C#5  554.37Hz
                8'd34: semi_step = 32'd52553357;   // D5   587.33Hz
                8'd35: semi_step = 32'd55678342;   // D#5  622.25Hz
                8'd36: semi_step = 32'd58989149;   // E5   659.26Hz
                8'd37: semi_step = 32'd62496826;   // F5   698.46Hz
                8'd38: semi_step = 32'd66213081;   // F#5  739.99Hz
                8'd39: semi_step = 32'd70150316;   // G5   783.99Hz
                8'd40: semi_step = 32'd74321671;   // G#5  830.61Hz
                8'd41: semi_step = 32'd78741067;   // A5   880.00Hz
                8'd42: semi_step = 32'd83423255;   // A#5  932.33Hz
                8'd43: semi_step = 32'd88383859;   // B5   987.77Hz
                8'd44: semi_step = 32'd93639437;   // C6  1046.50Hz
                8'd45: semi_step = 32'd99207528;   // C#6 1108.73Hz
                8'd46: semi_step = 32'd105106715;  // D6  1174.66Hz
                8'd47: semi_step = 32'd111356685;  // D#6 1244.51Hz
                8'd48: semi_step = 32'd117978298;  // E6  1318.51Hz
                8'd49: semi_step = 32'd124993653;  // F6  1396.91Hz
                8'd50: semi_step = 32'd132426162;  // F#6 1479.98Hz
                8'd51: semi_step = 32'd140300631;  // G6  1567.98Hz
                8'd52: semi_step = 32'd148643341;  // G#6 1661.22Hz
                8'd53: semi_step = 32'd157482134;  // A6  1760.00Hz
                8'd54: semi_step = 32'd166846509;  // A#6 1864.66Hz
                8'd55: semi_step = 32'd176767719;  // B6  1975.53Hz
                8'd56: semi_step = 32'd187278874;
                8'd57: semi_step = 32'd198415056;  // C#7 2217.46Hz
                8'd58: semi_step = 32'd210213429;  // D7  2349.32Hz
                8'd59: semi_step = 32'd222713370;  // D#7 2489.02Hz
                8'd60: semi_step = 32'd235956596;  // E7  2637.02Hz
                8'd61: semi_step = 32'd249987305;  // F7  2793.83Hz
                8'd62: semi_step = 32'd264852324;  // F#7 2959.96Hz
                default: semi_step = 32'd280601263; // G7  3135.96Hz
            endcase
        end
    endfunction

    // ------------------------------------------------------------ 64 点正弦表
    function signed [23:0] sin24;
        input [5:0] i;
        begin
            case (i)
                6'd0 : sin24 = 24'sd0;
                6'd1 : sin24 = 24'sd686120;
                6'd2 : sin24 = 24'sd1365632;
                6'd3 : sin24 = 24'sd2031993;
                6'd4 : sin24 = 24'sd2678784;
                6'd5 : sin24 = 24'sd3299777;
                6'd6 : sin24 = 24'sd3888992;
                6'd7 : sin24 = 24'sd4440753;
                6'd8 : sin24 = 24'sd4949747;
                6'd9 : sin24 = 24'sd5411073;
                6'd10: sin24 = 24'sd5820287;
                6'd11: sin24 = 24'sd6173449;
                6'd12: sin24 = 24'sd6467157;
                6'd13: sin24 = 24'sd6698582;
                6'd14: sin24 = 24'sd6865497;
                6'd15: sin24 = 24'sd6966293;
                6'd16: sin24 = 24'sd7000000;
                6'd17: sin24 = 24'sd6966293;
                6'd18: sin24 = 24'sd6865497;
                6'd19: sin24 = 24'sd6698582;
                6'd20: sin24 = 24'sd6467157;
                6'd21: sin24 = 24'sd6173449;
                6'd22: sin24 = 24'sd5820287;
                6'd23: sin24 = 24'sd5411073;
                6'd24: sin24 = 24'sd4949747;
                6'd25: sin24 = 24'sd4440753;
                6'd26: sin24 = 24'sd3888992;
                6'd27: sin24 = 24'sd3299777;
                6'd28: sin24 = 24'sd2678784;
                6'd29: sin24 = 24'sd2031993;
                6'd30: sin24 = 24'sd1365632;
                6'd31: sin24 = 24'sd686120;
                6'd32: sin24 = 24'sd0;
                6'd33: sin24 = -24'sd686120;
                6'd34: sin24 = -24'sd1365632;
                6'd35: sin24 = -24'sd2031993;
                6'd36: sin24 = -24'sd2678784;
                6'd37: sin24 = -24'sd3299777;
                6'd38: sin24 = -24'sd3888992;
                6'd39: sin24 = -24'sd4440753;
                6'd40: sin24 = -24'sd4949747;
                6'd41: sin24 = -24'sd5411073;
                6'd42: sin24 = -24'sd5820287;
                6'd43: sin24 = -24'sd6173449;
                6'd44: sin24 = -24'sd6467157;
                6'd45: sin24 = -24'sd6698582;
                6'd46: sin24 = -24'sd6865497;
                6'd47: sin24 = -24'sd6966293;
                6'd48: sin24 = -24'sd7000000;
                6'd49: sin24 = -24'sd6966293;
                6'd50: sin24 = -24'sd6865497;
                6'd51: sin24 = -24'sd6698582;
                6'd52: sin24 = -24'sd6467157;
                6'd53: sin24 = -24'sd6173449;
                6'd54: sin24 = -24'sd5820287;
                6'd55: sin24 = -24'sd5411073;
                6'd56: sin24 = -24'sd4949747;
                6'd57: sin24 = -24'sd4440753;
                6'd58: sin24 = -24'sd3888992;
                6'd59: sin24 = -24'sd3299777;
                6'd60: sin24 = -24'sd2678784;
                6'd61: sin24 = -24'sd2031993;
                6'd62: sin24 = -24'sd1365632;
                default: sin24 = -24'sd686120;
            endcase
        end
    endfunction

    // ------------------------------------------------------------- 合成逻辑
    wire [17:0] W_dur        = W_dur_q2 * SPB_HALF;      // 本音符长度（采样数）
    wire [31:0] W_step       = semi_step({2'b00, W_semi});
    wire [31:0] W_phase_next = S_phase + W_step;
    wire [5:0]  W_sin_idx    = W_phase_next[31:26];
    wire [5:0]  W_sin2_idx   = W_phase_next[30:25];

    wire [7:0]  W_target;
    wire [7:0]  W_env_next;
    wire signed [23:0] W_sin1;
    wire signed [23:0] W_sin2;
    wire signed [25:0] W_mix;
    wire signed [35:0] W_prod;
    wire signed [23:0] W_samp;

    wire        W_last   = (S_pos + 18'd1 >= W_dur);
    wire        W_is_end = W_last && (S_idx + 12'd1 >= NOTE_NUM);

    assign W_target = (S_gap != 17'd0)                ? 8'd0 :
                      (S_pos >= (W_dur - REL_S))       ? 8'd0 :
                                                        8'd255;

    assign W_env_next = (S_env < W_target) ? ((S_env >= 8'd254)      ? 8'd255 : S_env + ENV_STEP_B) :
                        (S_env > W_target) ? ((S_env <= ENV_STEP_B) ? 8'd0   : S_env - ENV_STEP_B) :
                                             S_env;

    assign W_sin1 = sin24(W_sin_idx);
    assign W_sin2 = sin24(W_sin2_idx);
    assign W_mix  = W_sin1 + (W_sin2 >>> HARM2_SHIFT);
    assign W_prod = W_mix * $signed({1'b0, W_env_next});
    assign W_samp = W_prod >>> 8;

    wire signed [23:0] W_samp_out = W_samp;

    // 下一状态
    reg [11:0] S_idx_next;
    reg [17:0] S_pos_next;
    reg [31:0] S_phase_next;
    reg [16:0] S_gap_next;

    always @(*) begin
        S_idx_next   = S_idx;
        S_pos_next   = S_pos + 18'd1;
        S_phase_next = W_phase_next;
        S_gap_next   = S_gap;

        if (S_gap != 17'd0) begin

            S_pos_next   = 18'd0;
            S_phase_next = 32'd0;
            S_gap_next   = S_gap - 17'd1;
        end else if (W_last) begin
            S_pos_next   = 18'd0;
            S_phase_next = 32'd0;               // 每个音重新起振
            if (W_is_end) begin
                S_idx_next = 12'd0;
                S_gap_next = GAP_CNT;
            end else begin
                S_idx_next = S_idx + 12'd1;
            end
        end
    end

    reg [5:0]  S_bit_cnt;
    reg [63:0] S_shift_reg;
    reg signed [23:0] S_sample_word;

    wire S_frame_tick = (S_bit_cnt == 6'd63) && (O_i2s_LRCK == 1'b1) && (O_i2s_BCLK == 1'b1);

    localparam integer WF_AW  = 10;                 // 1024 深
    localparam integer WF_LOW = 9'd640;

    function [WF_AW:0] gray2bin;
        input [WF_AW:0] g;
        integer k;
        begin
            gray2bin[WF_AW] = g[WF_AW];
            for (k = WF_AW-1; k >= 0; k = k - 1)
                gray2bin[k] = gray2bin[k+1] ^ g[k];
        end
    endfunction

    reg [23:0] wf_mem [0:(1<<WF_AW)-1];

    // 写侧
    reg  [WF_AW:0] wbin, wgray;
    reg  [WF_AW:0] rgray_w1, rgray_w2;
    wire [WF_AW:0] rbin_w    = gray2bin(rgray_w2);
    wire           wfull     = (wgray == {~rgray_w2[WF_AW:WF_AW-1], rgray_w2[WF_AW-2:0]});
    wire [WF_AW:0] wused     = wbin - rbin_w;
    assign         O_wav_need = wused < WF_LOW;

    // 读侧
    reg  [WF_AW:0] rbin, rgray;
    reg  [WF_AW:0] wgray_r1, wgray_r2;
    wire [WF_AW:0] wbin_r    = gray2bin(wgray_r2);
    wire           rempty    = (rgray == wgray_r2);

    // 写口（sd_card_clk）
    always @(posedge I_wav_wr_clk or posedge I_rst) begin
        if (I_rst) begin
            wbin <= {(WF_AW+1){1'b0}};
            wgray <= {(WF_AW+1){1'b0}};
            rgray_w1 <= {(WF_AW+1){1'b0}};
            rgray_w2 <= {(WF_AW+1){1'b0}};
        end else begin
            rgray_w1 <= rgray;
            rgray_w2 <= rgray_w1;
            if (I_wav_wr_en && !wfull) begin
                wf_mem[wbin[WF_AW-1:0]] <= I_wav_wr_data;
                wbin  <= wbin + 1'b1;
                wgray <= (wbin + 1'b1) ^ ((wbin + 1'b1) >> 1);
            end
        end
    end

    reg  [WF_AW-1:0] rd_addr;
    reg  [23:0]      rd_q;
    reg  [23:0]      S_wav_word;
    reg              S_wav_vld;
    reg              S_wav_act;
    reg  [1:0]       I_wav_only_sync;
    reg  [1:0]       I_wav_flush_sync;   // 切歌脉冲两级同步
    reg              I_wav_flush_d;
    reg  [16:0]      S_mute_cnt;
    reg  [12:0]      S_wav_gap;

    always @(posedge I_mclk or posedge I_rst) begin
        if (I_rst) begin
            rbin    <= {(WF_AW+1){1'b0}};
            rgray   <= {(WF_AW+1){1'b0}};
            wgray_r1 <= {(WF_AW+1){1'b0}};
            wgray_r2 <= {(WF_AW+1){1'b0}};
            rd_addr <= {(WF_AW){1'b0}};
            rd_q    <= 24'd0;
            S_wav_word <= 24'd0;
            S_wav_vld  <= 1'b0;
            S_wav_act  <= 1'b0;
            S_wav_gap  <= 13'd0;
            O_wav_mode <= 1'b0;
        end else begin
            // 指针同步
            wgray_r1 <= wgray;
            wgray_r2 <= wgray_r1;

            // 跨时钟域同步
            I_wav_only_sync  <= {I_wav_only_sync[0],  I_wav_only};
            I_wav_flush_sync <= {I_wav_flush_sync[0], I_wav_flush};
            I_wav_flush_d    <= I_wav_flush_sync[1];

            // 同步读（地址 = 当前读指针）
            rd_q <= wf_mem[rd_addr];

            if (S_frame_tick) begin

                if (I_wav_flush_sync[1] != I_wav_flush_d) begin
                    rbin      <= wbin_r;
                    rgray     <= wgray_r2;
                    rd_addr   <= wbin_r[WF_AW-1:0];
                    S_wav_vld <= 1'b0;
                    S_mute_cnt <= 17'd96;
                end else if (S_mute_cnt != 17'd0) begin
                    S_mute_cnt <= S_mute_cnt - 17'd1;
                    S_wav_vld  <= 1'b0;
                end else if (!rempty) begin
                    S_wav_word <= rd_q;
                    S_wav_vld  <= 1'b1;
                    S_wav_act  <= 1'b1;      // 一旦有数据就锁定到 WAV
                    S_wav_gap  <= 13'd0;
                    O_wav_mode <= 1'b1;
                    rbin    <= rbin + 1'b1;
                    rgray   <= (rbin + 1'b1) ^ ((rbin + 1'b1) >> 1);
                    rd_addr <= rbin[WF_AW-1:0] + 1'b1;
                end else begin
                    S_wav_vld <= 1'b0;
                    if (S_wav_gap != 13'h1FFF)
                        S_wav_gap <= S_wav_gap + 13'd1;
                end
            end
        end
    end

    // -------------------------------------------------------- I2S 64fs 发送

    always @(posedge I_mclk or posedge I_rst) begin
        if (I_rst) begin
            O_i2s_BCLK    <= 1'b0;
            O_i2s_LRCK    <= 1'b0;
            O_i2s_DOUT    <= 1'b0;
            S_bit_cnt     <= 6'd0;
            S_shift_reg   <= 64'd0;
            S_sample_word <= 24'sd0;
            S_idx         <= 12'd0;
            S_pos         <= 18'd0;
            S_phase       <= 32'd0;
            S_env         <= 8'd0;
            S_gap         <= 17'd0;
        end else begin
            O_i2s_BCLK <= ~O_i2s_BCLK;

            if (O_i2s_BCLK == 1'b1) begin
                O_i2s_DOUT  <= S_shift_reg[63];
                S_shift_reg <= {S_shift_reg[62:0], 1'b0};

                if (S_bit_cnt == 6'd63) begin
                    S_bit_cnt <= 6'd0;

                    if (O_i2s_LRCK == 1'b0) begin

                        O_i2s_LRCK  <= 1'b1;
                        S_shift_reg <= {S_sample_word[23:0], 40'd0};
                    end else begin

                        O_i2s_LRCK    <= 1'b0;

                        if (I_wav_only_sync[1] || (MELODY_ENABLE == 0))
                            S_sample_word <= S_wav_vld ? S_wav_word : 24'sd0;
                        else
                            S_sample_word <= W_samp_out;
                        S_shift_reg   <= {S_sample_word, 40'd0};

                        S_env         <= W_env_next;
                        S_idx         <= S_idx_next;
                        S_pos         <= S_pos_next;
                        S_phase       <= S_phase_next;
                        S_gap         <= S_gap_next;
                    end
                end else begin
                    S_bit_cnt <= S_bit_cnt + 6'd1;
                end
            end
        end
    end

endmodule

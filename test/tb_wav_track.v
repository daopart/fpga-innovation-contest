`timescale 1ns/1ps

module tb_wav_track;

localparam integer S_BPB  = 2048;
localparam integer S_DIR  = 2208;
localparam integer FSIZE  = 1024;
localparam integer NPCM   = (FSIZE - 44) / 2;

reg clk = 1'b0;
reg rst = 1'b1;
always #5 clk = ~clk;

reg [7:0] img_a [0:FSIZE-1];
reg [7:0] img_b [0:FSIZE-1];
reg [7:0] img_c [0:FSIZE-1];
integer i, n;
reg [15:0] sv;

reg        busy    = 1'b0;
reg  [9:0] bidx    = 10'd0;
reg [31:0] lat     = 32'd0;
wire       sd_dvld;
wire       sd_end;
wire [7:0] sd_data;

reg         need  = 1'b1;
reg  [3:0]  track = 4'd0;
wire        req;
wire [31:0] addr;
wire        we;
wire [23:0] wdata;
wire        found;
wire        scan_mode;
wire [3:0]  cnt;

wav_reader #(
    .SCAN_START  (32'd0),
    .SCAN_MAX    (32'd8),
    .DIR_SEC_MAX (16'd4),
    .MAX_TRACKS  (8)
) dut (
    .clk        (clk),
    .rst        (rst),
    .enable     (1'b1),
    .need       (need),
    .I_track    (track),
    .req        (req),
    .addr       (addr),
    .grant      (1'b1),
    .dvld       (sd_dvld),
    .data       (sd_data),
    .end_of_sec (sd_end),
    .we         (we),
    .wdata      (wdata),
    .found      (found),
    .scan_mode  (scan_mode),
    .O_count    (cnt)
);

function [7:0] sec_byte;
    input [31:0] s;
    input [9:0]  b;
    reg   [31:0] off;
    begin
        sec_byte = 8'h00;
        if (s == 32'd0) begin
            if (b == 10'd450) sec_byte = 8'h0C;
            if (b == 10'd454) sec_byte = S_BPB[7:0];
            if (b == 10'd455) sec_byte = S_BPB[15:8];
        end else if (s == S_BPB) begin
            case (b)
                10'd11: sec_byte = 8'd0;  10'd12: sec_byte = 8'd2;
                10'd13: sec_byte = 8'd8;
                10'd14: sec_byte = 8'd32; 10'd15: sec_byte = 8'd0;
                10'd16: sec_byte = 8'd2;
                10'd36: sec_byte = 8'd64;
                10'd44: sec_byte = 8'd2;
                default: sec_byte = 8'h00;
            endcase
        end else if (s == S_DIR) begin
            case (b)
                10'd0:  sec_byte = "A";
                10'd8:  sec_byte = "W"; 10'd9: sec_byte = "A"; 10'd10: sec_byte = "V";
                10'd11: sec_byte = 8'h20;
                10'd26: sec_byte = 8'd3;  10'd27: sec_byte = 8'h00;
                10'd28: sec_byte = FSIZE[7:0]; 10'd29: sec_byte = FSIZE[15:8];
                10'd32: sec_byte = "B";
                10'd40: sec_byte = "W"; 10'd41: sec_byte = "A"; 10'd42: sec_byte = "V";
                10'd43: sec_byte = 8'h20;
                10'd58: sec_byte = 8'd5;  10'd59: sec_byte = 8'h00;
                10'd60: sec_byte = FSIZE[7:0]; 10'd61: sec_byte = FSIZE[15:8];
                10'd64: sec_byte = "C";
                10'd72: sec_byte = "W"; 10'd73: sec_byte = "A"; 10'd74: sec_byte = "V";
                10'd75: sec_byte = 8'h20;
                10'd90: sec_byte = 8'd7;  10'd91: sec_byte = 8'h00;
                10'd92: sec_byte = FSIZE[7:0]; 10'd93: sec_byte = FSIZE[15:8];
                default: sec_byte = 8'h00;
            endcase
        end else if ((s >= 32'd2216) && (s < 32'd2218)) begin
            off = (s - 32'd2216) * 512 + b;
            sec_byte = img_a[off];
        end else if ((s >= 32'd2232) && (s < 32'd2234)) begin
            off = (s - 32'd2232) * 512 + b;
            sec_byte = img_b[off];
        end else if ((s >= 32'd2248) && (s < 32'd2250)) begin
            off = (s - 32'd2248) * 512 + b;
            sec_byte = img_c[off];
        end
    end
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        busy <= 1'b0; bidx <= 10'd0; lat <= 32'd0;
    end else if (!busy) begin
        if (req) begin
            busy <= 1'b1; lat <= addr; bidx <= 10'd0;
        end
    end else if (bidx < 10'd512) begin
        bidx <= bidx + 10'd1;
    end else begin
        busy <= 1'b0;
    end
end

assign sd_dvld = busy && (bidx < 10'd512);
assign sd_end  = busy && (bidx == 10'd512);
assign sd_data = sec_byte(lat, bidx);

integer errors = 0;
integer got_n  = 0;
reg [23:0] samp [0:1999];

always @(posedge clk) begin
    if (we && (got_n < 2000)) begin
        samp[got_n] = wdata;
        got_n = got_n + 1;
    end
end

function [7:0] hdr_byte(input [15:0] o);
    begin
        case (o)
            16'd0: hdr_byte = "R"; 16'd1: hdr_byte = "I";
            16'd2: hdr_byte = "F"; 16'd3: hdr_byte = "F";
            16'd4: hdr_byte = FSIZE[7:0]; 16'd5: hdr_byte = FSIZE[15:8];
            16'd8: hdr_byte = "W"; 16'd9: hdr_byte = "A";
            16'd10: hdr_byte = "V"; 16'd11: hdr_byte = "E";
            16'd12: hdr_byte = "f"; 16'd13: hdr_byte = "m";
            16'd14: hdr_byte = "t"; 16'd15: hdr_byte = " ";
            16'd16: hdr_byte = 8'd16;                    // fmt 块大小
            16'd18: hdr_byte = 8'd1;                     // 格式 = PCM
            16'd20: hdr_byte = 8'd1;                     // 声道 = 1
            16'd22: hdr_byte = 8'd1; 16'd23: hdr_byte = 8'd0;      // channels 在 22
            16'd24: hdr_byte = 8'h80; 16'd25: hdr_byte = 8'hBB;    // 48000
            16'd26: hdr_byte = 8'd0;  16'd27: hdr_byte = 8'd0;
            16'd28: hdr_byte = 8'h00; 16'd29: hdr_byte = 8'h77;    // 字节率 96000
            16'd30: hdr_byte = 8'h01; 16'd31: hdr_byte = 8'd0;
            16'd32: hdr_byte = 8'd2; 16'd33: hdr_byte = 8'd0;      // 块对齐 2
            16'd34: hdr_byte = 8'd16; 16'd35: hdr_byte = 8'd0;     // 位深 16
            16'd36: hdr_byte = "d"; 16'd37: hdr_byte = "a";
            16'd38: hdr_byte = "t"; 16'd39: hdr_byte = "a";
            16'd40: hdr_byte = FSIZE[7:0]; 16'd41: hdr_byte = FSIZE[15:8];
            default: hdr_byte = 8'h00;
        endcase
    end
endfunction

task init_img(input [15:0] base);
    integer m;
    begin
        for (m = 0; m < FSIZE; m = m + 1) begin
            if (m < 44)
                img_a[m] = hdr_byte(m[15:0]);
            else begin
                sv = base + ((m - 44) / 2) % NPCM;
                img_a[m] = ((m % 2) == 0) ? sv[7:0] : sv[15:8];
            end
        end
    end
endtask

task check_seg(input [23:0] base, output integer nbad);
    integer q;
    begin
        nbad = 0;
        for (q = 0; q < 39; q = q + 1) begin
            if (((samp[q] - base) >= (490 << 8)) || (samp[q][7:0] != 8'h00))
                nbad = nbad + 1;
            if ((samp[q+1] - samp[q]) !== 24'h000100)
                nbad = nbad + 1;
        end
    end
endtask

task play_and_check(input [3:0] tsel, input [23:0] base, output integer nbad);
    begin
        track = tsel;
        repeat (600) @(posedge clk);
        got_n = 0;
        repeat (3000) @(posedge clk);
        nbad = 0;
        check_seg(base, nbad);
        $display("  track %0d: got %0d samples, bad %0d", tsel, got_n, nbad);
    end
endtask

integer t, nb;

initial begin
    for (i = 0; i < FSIZE; i = i + 1) img_a[i] = 8'h00;
    init_img(16'h1000);
    for (i = 0; i < FSIZE; i = i + 1) img_b[i] = img_a[i];

    img_b[22] = 8'd2;  img_b[23] = 8'd0;                       // channels = 2
    img_b[24] = 8'h44; img_b[25] = 8'hAC;                      // 44100
    img_b[26] = 8'd0;  img_b[27] = 8'd0;
    for (i = 44; i < FSIZE; i = i + 2) begin
        sv = 16'h2000 + ((i - 44) / 2) % NPCM;
        img_b[i] = sv[7:0]; img_b[i+1] = sv[15:8];
    end
    for (i = 0; i < FSIZE; i = i + 1) img_c[i] = img_a[i];
    for (i = 44; i < FSIZE; i = i + 2) begin
        sv = 16'h3000 + ((i - 44) / 2) % NPCM;
        img_c[i] = sv[7:0]; img_c[i+1] = sv[15:8];
    end

    $display("============================================================");
    $display(" tb_wav_track: 3 WAV tracks + switching");
    $display("============================================================");

    rst = 1'b1;
    repeat (10) @(posedge clk);
    rst = 1'b0;

    t = 0;
    while ((cnt < 4'd3) && (t < 20000)) begin
        @(posedge clk);
        t = t + 1;
    end
    $display("  scan: found %0d tracks (%0d cycles), scan_mode=%0d", cnt, t, scan_mode);
    $display("  dbg: spc=%0d spc_log=%0d dat=%0d dir=%0d dk=%0d tcnt=%0d dirdone=%0d",
             dut.spc, dut.spc_log, dut.data_start, dut.dir_start, dut.dir_k, dut.t_cnt, dut.dir_done);
    if (cnt != 4'd3) begin
        $display("  [FAIL] should find 3 tracks");
        errors = errors + 1;
    end

    play_and_check(4'd1, 24'h100000, nb);
    if (nb != 0 || got_n < 40) begin errors = errors + 1; $display("  [FAIL] track 1"); end

    track = 4'd2;
    repeat (600) @(posedge clk);
    got_n = 0;
    repeat (3000) @(posedge clk);
    $display("  track 2 (stereo 44.1k): got %0d samples (expect 0), fmt_bad=%0d",
             got_n, dut.O_fmt_bad);
    if (got_n != 0) begin errors = errors + 1; $display("  [FAIL] track 2 should be blocked"); end
    if (dut.O_fmt_bad !== 1'b1) begin errors = errors + 1; $display("  [FAIL] fmt_bad not set"); end
    play_and_check(4'd3, 24'h300000, nb);
    if (nb != 0 || got_n < 40) begin errors = errors + 1; $display("  [FAIL] track 3"); end

    track = 4'd0;
    repeat (600) @(posedge clk);
    got_n = 0;
    repeat (3000) @(posedge clk);
    $display("  track 0: got %0d samples (expect 0)", got_n);
    if (got_n != 0) begin errors = errors + 1; $display("  [FAIL] track 0 still streaming"); end

    $display(" errors=%0d", errors);
    $display(" RESULT: %s", (errors == 0) ? "PASS" : "FAIL");
    $finish;
end

endmodule

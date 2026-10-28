`timescale 1ns/1ps

module tb_wav_fat;

localparam integer S_MBR  = 0;
localparam integer S_BPB  = 2048;
localparam integer S_DIR  = 2208;
localparam integer S_FILE = 2216;
localparam integer FCLU   = 3;
localparam integer FSIZE  = 1536;         // 文件长度（3 扇区）

reg clk = 1'b0;
reg rst = 1'b1;
always #5 clk = ~clk;

//---------------- 卡内容（按需生成，不占大内存）
reg [7:0] wavimg [0:FSIZE-1];

integer i, n;
reg [15:0] sv;

integer errors = 0;
integer got_n  = 0;
reg [15:0] exp16;
reg [23:0] exp_s;

//---------------- 假 SD 从机
reg        busy    = 1'b0;
reg  [9:0] bidx    = 10'd0;
reg [31:0] lat     = 32'd0;
wire       sd_dvld;
wire       sd_end;
wire [7:0] sd_data;

//---------------- DUT
reg         need = 1'b1;
wire        req;
wire [31:0] addr;
wire        we;
wire [23:0] wdata;
wire        found;
wire        scan_mode;

wav_reader #(
    .SCAN_START  (32'd0),
    .SCAN_MAX    (32'd8),
    .DIR_SEC_MAX (16'd4)
) dut (
    .clk        (clk),
    .rst        (rst),
    .enable     (1'b1),
    .need       (need),
    .req        (req),
    .addr       (addr),
    .grant      (1'b1),
    .dvld       (sd_dvld),
    .data       (sd_data),
    .end_of_sec (sd_end),
    .we         (we),
    .wdata      (wdata),
    .found      (found),
    .scan_mode  (scan_mode)
);

//---------------- 扇区内容
function [7:0] sec_byte;
    input [31:0] s;
    input [9:0]  b;
    reg   [31:0] off;
    begin
        sec_byte = 8'h00;
        if (s == S_MBR) begin
            if (b == 10'd446) sec_byte = 8'h00;
            if (b == 10'd450) sec_byte = 8'h0C;             // 分区类型
            if (b == 10'd454) sec_byte = S_BPB[7:0];        // LBA 起始
            if (b == 10'd455) sec_byte = S_BPB[15:8];
            if (b == 10'd456) sec_byte = 8'h00;
            if (b == 10'd457) sec_byte = 8'h00;
        end else if (s == S_BPB) begin
            case (b)
                10'd11: sec_byte = 8'd0;   10'd12: sec_byte = 8'd2;   // 512 字节/扇区
                10'd13: sec_byte = 8'd8;                              // 8 扇区/簇
                10'd14: sec_byte = 8'd32;  10'd15: sec_byte = 8'd0;   // 保留 32
                10'd16: sec_byte = 8'd2;                              // 2 个 FAT
                10'd22: sec_byte = 8'd0;   10'd23: sec_byte = 8'd0;   // fat16 = 0
                10'd36: sec_byte = 8'd64;                             // FAT32 大小 = 64
                10'd44: sec_byte = 8'd2;                              // 根簇 = 2
                default: sec_byte = 8'h00;
            endcase
        end else if (s == S_DIR) begin
            if (b < 10'd32) begin

                case (b)
                    10'd0: sec_byte = "M"; 10'd1: sec_byte = "U"; 10'd2: sec_byte = "S";
                    10'd3: sec_byte = "I"; 10'd4: sec_byte = "C"; 10'd5: sec_byte = " ";
                    10'd6: sec_byte = " "; 10'd7: sec_byte = " ";
                    10'd8: sec_byte = "W"; 10'd9: sec_byte = "A"; 10'd10: sec_byte = "V";
                    10'd11: sec_byte = 8'h20;                       // 普通文件
                    10'd20: sec_byte = 8'h00; 10'd21: sec_byte = 8'h00;
                    10'd26: sec_byte = FCLU[7:0];
                    10'd27: sec_byte = 8'h00;
                    10'd28: sec_byte = FSIZE[7:0];
                    10'd29: sec_byte = FSIZE[15:8];
                    10'd30: sec_byte = 8'h00;
                    10'd31: sec_byte = 8'h00;
                    default: sec_byte = 8'h00;
                endcase
            end else begin
                sec_byte = 8'h00;                                    // 第二项起全 0（目录结束）
            end
        end else if ((s >= S_FILE) && (s < S_FILE + FSIZE/512)) begin
            off = (s - S_FILE) * 512 + b;
            sec_byte = wavimg[off];
        end
    end
endfunction

//---------------- 数据阶段检查（PCM：第 n 个样点 = 0x0100 + n）
always @(posedge clk) begin
    if (we) begin
        exp16 = 16'h0100 + (got_n % 746);
        exp_s = {exp16[15:8], exp16[7:0], 8'h00};
        if (wdata !== exp_s) begin
            errors = errors + 1;
            if (errors < 8)
                $display("  [FAIL] sample %0d: got=%06x exp=%06x", got_n, wdata, exp_s);
        end
        got_n = got_n + 1;
    end
end

//---------------- 假 SD 行为
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

//---------------- 卡内容初始化
initial begin
    // WAV 头（44 字节）+ PCM
    for (i = 0; i < FSIZE; i = i + 1) wavimg[i] = 8'h00;
    wavimg[0]  = "R"; wavimg[1] = "I"; wavimg[2] = "F"; wavimg[3] = "F";
    wavimg[4]  = 8'h00; wavimg[5] = 8'h06; wavimg[6] = 8'h00; wavimg[7] = 8'h00;
    wavimg[8]  = "W"; wavimg[9] = "A"; wavimg[10] = "V"; wavimg[11] = "E";
    wavimg[12] = "f"; wavimg[13] = "m"; wavimg[14] = "t"; wavimg[15] = " ";
    wavimg[16] = 8'd16; wavimg[17] = 8'd0;
    wavimg[18] = 8'd1;  wavimg[19] = 8'd0;
    wavimg[20] = 8'd1;  wavimg[21] = 8'd0;
    wavimg[22] = 8'h80; wavimg[23] = 8'hBB;
    wavimg[32] = 8'd2;  wavimg[33] = 8'd0;
    wavimg[34] = 8'd16; wavimg[35] = 8'd0;
    wavimg[36] = "d"; wavimg[37] = "a"; wavimg[38] = "t"; wavimg[39] = "a";
    wavimg[40] = 8'h00; wavimg[41] = 8'h06; wavimg[42] = 8'h00; wavimg[43] = 8'h00;
    for (n = 0; n < (FSIZE-44)/2; n = n + 1) begin
        sv = 16'h0100 + (n % 746);
        wavimg[44 + 2*n]     = sv[7:0];
        wavimg[44 + 2*n + 1] = sv[15:8];
    end
end

integer t;
integer dbg = 0;
reg [3:0] st_d = 4'hF;
always @(posedge clk) begin
    if (dut.st != st_d) begin
        $display("   ST %0d -> %0d | part=%0d bps=%0d spc=%0d rsvd=%0d nf=%0d f32=%0d rclus=%0d dat=%0d dir=%0d dk=%0d fsec=%0d",
                 st_d, dut.st, dut.part_start, dut.bps, dut.spc, dut.rsvd, dut.nfats,
                 dut.fat32sz, dut.root_clus, dut.data_start, dut.dir_start, dut.dir_k, dut.file_sec);
        st_d = dut.st;
    end
    if (sd_dvld && (dbg < 12) && (dut.st == 4'd5)) begin
        $display("   DIR b=%0d data=%02x eok=%0d ext=%c%c%c attr=%02x chi=%0d clo=%0d size=%0d",
                 bidx, sd_data, dut.e_ok, dut.e_ext0, dut.e_ext1, dut.e_ext2,
                 dut.e_attr, dut.e_chi, dut.e_clo, dut.e_size);
        dbg = dbg + 1;
    end
end
initial begin
    $display("============================================================");
    $display(" tb_wav_fat: 合成 FAT32 卡，根目录里只有 MUSIC.WAV");
    $display("   MBR@0  BPB@%0d  DIR@%0d  FILE@%0d(簇 %0d)", S_BPB, S_DIR, S_FILE, FCLU);
    $display("============================================================");
    rst = 1'b1;
    repeat (10) @(posedge clk);
    rst = 1'b0;

    t = 0;
    while (!found && (t < 5000)) begin
        @(posedge clk);
        t = t + 1;
    end
    if (!found) begin
        $display("  [FAIL] FAT 里没找到 WAV");
        errors = errors + 1;
    end else begin
        $display("  FAT 找到 WAV：%0d 拍（scan_mode=%0d）", t, scan_mode);
        if (scan_mode !== 1'b0) begin
            $display("  [FAIL] 走成了兜底扫描（不该走到这里）");
            errors = errors + 1;
        end
    end

    t = 0;
    while ((got_n < 800) && (t < 200000)) begin
        @(posedge clk);
        t = t + 1;
    end
    $display("  收到 %0d 个样点，errors=%0d", got_n, errors);
    $display(" RESULT: %s", (errors == 0) ? "PASS" : "FAIL");
    $finish;
end

endmodule

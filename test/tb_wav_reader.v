`timescale 1ns/1ps

//    3) 读完整个文件会自动从头循环

module tb_wav_reader;

localparam integer NSEC    = 3;
localparam integer WAV_SEC = 4;          // 假卡上 WAV 放在第 4 个扇区

reg clk = 1'b0;
reg rst = 1'b1;
always #5 clk = ~clk;                     // 100MHz

//---------------- 假 SD 卡内容
reg [7:0]  card [0:NSEC*512-1];
integer    i, n;
reg [15:0] sv;

//---------------- 假 SD 从机（组合输出，避免与 DUT 采样差拍）
reg        busy     = 1'b0;
reg  [9:0] bidx     = 10'd0;
reg [31:0] lat_addr = 32'd0;
wire       sd_dvld;
wire       sd_end;
wire [7:0] sd_data;

//---------------- DUT 连线
reg         need = 1'b1;
wire        req;
wire [31:0] addr;
wire        we;
wire [23:0] wdata;
wire        found;

//---------------- 检查
integer    errors = 0;
integer    got_n  = 0;
reg [15:0] exp16;
reg [23:0] exp_s;
integer    t;

//---------------- 卡内容
initial begin
    for (i = 0; i < NSEC*512; i = i + 1) card[i] = 8'h00;
    card[0]  = "R"; card[1] = "I"; card[2] = "F"; card[3] = "F";
    card[4]  = 8'h00; card[5] = 8'h06; card[6] = 8'h00; card[7] = 8'h00;   // file_len = 1536
    card[8]  = "W"; card[9] = "A"; card[10] = "V"; card[11] = "E";
    card[12] = "f"; card[13] = "m"; card[14] = "t"; card[15] = " ";
    card[16] = 8'd16; card[17] = 8'd0;
    card[18] = 8'd1;  card[19] = 8'd0;                                     // PCM
    card[20] = 8'd1;  card[21] = 8'd0;                                     // mono
    card[22] = 8'h80; card[23] = 8'hBB; card[24] = 8'd0; card[25] = 8'd0;  // 48000
    card[32] = 8'd2;  card[33] = 8'd0;                                     // block align
    card[34] = 8'd16; card[35] = 8'd0;                                     // 16 bit
    card[36] = "d"; card[37] = "a"; card[38] = "t"; card[39] = "a";
    card[40] = 8'h00; card[41] = 8'h06; card[42] = 8'h00; card[43] = 8'h00;   // data size = 1536
    for (n = 0; n < (NSEC*512-44)/2; n = n + 1) begin
        sv = 16'h0100 + n;
        card[44 + 2*n]     = sv[7:0];
        card[44 + 2*n + 1] = sv[15:8];
    end
end

//---------------- DUT
wav_reader #(
    .SCAN_START (32'd0),
    .SCAN_MAX   (32'd15)
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
    .found      (found)
);

//---------------- 假 SD 从机行为
always @(posedge clk or posedge rst) begin
    if (rst) begin
        busy     <= 1'b0;
        bidx     <= 10'd0;
        lat_addr <= 32'd0;
    end else if (!busy) begin
        if (req) begin
            busy     <= 1'b1;
            lat_addr <= addr;
            bidx     <= 10'd0;
        end
    end else if (bidx < 10'd512) begin
        bidx <= bidx + 10'd1;
    end else begin
        busy <= 1'b0;
    end
end

assign sd_dvld = busy && (bidx < 10'd512);
assign sd_end  = busy && (bidx == 10'd512);
assign sd_data = ((lat_addr >= WAV_SEC) && (lat_addr < (WAV_SEC + NSEC)))
                 ? card[(lat_addr - WAV_SEC)*512 + bidx]
                 : 8'hA5;

//---------------- 样点比对
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

//---------------- 主流程
initial begin
    $display("============================================================");
    $display(" tb_wav_reader: WAV @ sector %0d, %0d PCM sectors", WAV_SEC, NSEC);
    $display("============================================================");
    rst = 1'b1;
    repeat (10) @(posedge clk);
    rst = 1'b0;

    t = 0;
    while (!found && (t < 20000)) begin
        @(posedge clk);
        t = t + 1;
    end
    if (!found) begin
        $display("  [FAIL] 没扫到 WAV 头");
        errors = errors + 1;
    end else begin
        $display("  found WAV after %0d cycles", t);
    end

    while (got_n < 1000) @(posedge clk);

    $display("  got %0d samples, errors=%0d", got_n, errors);
    $display(" RESULT: %s", (errors == 0 && got_n >= 1000) ? "PASS" : "FAIL");
    $finish;
end

endmodule

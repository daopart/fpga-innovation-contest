`timescale 1ns/1ps

module tb_key_zoom_ctrl;

localparam integer CLK_FREQ = 1_000_000;   // 1MHz
localparam integer MS       = CLK_FREQ / 1000;

reg  clk = 1'b0;
reg  rst = 1'b1;
reg  key1 = 1'b1;
reg  key2 = 1'b1;

wire        next_press;
wire        auto_press;
wire        zoom_in_tog;
wire        zoom_out_tog;
wire        key1_short;

always #500 clk = ~clk;                    // 1MHz

key_zoom_ctrl #(
    .CLK_FREQ_HZ (CLK_FREQ),
    .DEBOUNCE_MS (10),
    .LONG_MS     (800),
    .PULSE_MS    (120)
) dut (
    .clk          (clk),
    .rst          (rst),
    .key1         (key1),
    .key2         (key2),
    .next_press   (next_press),
    .auto_press   (auto_press),
    .zoom_in_tog  (zoom_in_tog),
    .zoom_out_tog (zoom_out_tog),
    .key1_short   (key1_short),
    .key2_short   ()
);

wire dbl;
key_event_detect #(
    .CLK_FREQ_HZ (CLK_FREQ),
    .WIN_MS      (320)
) u_dbl (
    .clk        (clk),
    .rst        (rst),
    .short_i    (key1_short),
    .double_evt (dbl),
    .triple_evt ()
);

//------------------------------------------------------------- 事件计数
integer n_next   = 0;
integer n_zoom   = 0;
integer n_dbl    = 0;
integer n_short  = 0;

reg next_d  = 1'b1;
reg zi_d    = 1'b0;

always @(posedge clk) begin
    next_d <= next_press;
    zi_d   <= zoom_in_tog;
    if (next_d && !next_press) n_next = n_next + 1;
    if (zi_d   != zoom_in_tog) n_zoom = n_zoom + 1;
    if (dbl)                   n_dbl  = n_dbl + 1;
    if (key1_short)            n_short = n_short + 1;
end

//------------------------------------------------------------- 辅助任务
task automatic press_for(input integer ms);
    integer i;
    begin
        key1 = 1'b0;
        repeat (ms * MS) @(posedge clk);
        key1 = 1'b1;
    end
endtask

task automatic wait_ms(input integer ms);
    begin
        repeat (ms * MS) @(posedge clk);
    end
endtask

integer errors = 0;
task automatic chk(input [255:0] name, input integer got, input integer exp);
    begin
        if (got !== exp) begin
            errors = errors + 1;
            $display("  [FAIL] %0s: got=%0d exp=%0d", name, got, exp);
        end
    end
endtask

integer base;

initial begin
    $display("============================================================");
    $display(" tb_key_zoom_ctrl: 1MHz, deb=10ms long=800ms pulse=120ms");
    $display("============================================================");

    rst = 1'b1;
    repeat (20) @(posedge clk);
    rst = 1'b0;
    wait_ms(5);

    // 1) 60ms 轻点
    base = n_next;
    press_for(60);
    wait_ms(300);
    chk("60ms 轻点 -> 1 次 next", n_next - base, 1);
    chk("60ms 轻点 -> 不触发缩放", n_zoom, 0);

    // 2) 5ms 毛刺
    base = n_next;
    press_for(5);
    wait_ms(300);
    chk("5ms 毛刺 -> 被消抖吃掉", n_next - base, 0);

    base = n_next;
    press_for(60); wait_ms(200);
    press_for(60); wait_ms(200);
    press_for(60); wait_ms(200);
    press_for(60); wait_ms(400);
    chk("连点 4 次 -> 4 次 next", n_next - base, 4);

    // 4) 900ms 长按
    base = n_next;
    press_for(900);
    wait_ms(400);
    chk("900ms 长按 -> 触发 1 次放大", n_zoom, 1);
    chk("900ms 长按 -> 松手不产生 next", n_next - base, 0);

    // 5) 双击（间隔 200ms）
    base = n_dbl;
    press_for(60); wait_ms(140);   // 按下到下次按下 ≈ 60+140
    press_for(60);
    wait_ms(400);
    chk("间隔 200ms 双击 -> 1 次双击", n_dbl - base, 1);

    // 6) 两次单击（间隔 600ms）
    base = n_dbl;
    press_for(60); wait_ms(540);
    press_for(60);
    wait_ms(400);
    chk("间隔 600ms -> 不算双击", n_dbl - base, 0);

    $display(" 统计: next=%0d zoom=%0d double=%0d short=%0d", n_next, n_zoom, n_dbl, n_short);
    $display(" errors=%0d", errors);
    $display(" RESULT: %s", (errors == 0) ? "PASS" : "FAIL");
    $finish;
end

endmodule

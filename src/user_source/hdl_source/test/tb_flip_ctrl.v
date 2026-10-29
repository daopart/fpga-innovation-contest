`timescale 1ns/1ps

module tb_flip_ctrl;

localparam integer DEB = 100;

reg clk = 1'b0;
reg rst = 1'b1;
reg key_flip = 1'b1;

wire       flip_h;
wire       flip_v;
wire [1:0] flip_mode;

always #20 clk = ~clk;                // 25MHz

flip_ctrl #(
    .CNT_DEB (DEB)
) dut (
    .clk       (clk),
    .rst       (rst),
    .key_flip  (key_flip),
    .flip_h    (flip_h),
    .flip_v    (flip_v),
    .flip_mode (flip_mode)
);

integer errors = 0;
integer checks = 0;

task automatic expect_mode(input [1:0] m);
    begin
        checks = checks + 1;
        if (flip_mode !== m) begin
            errors = errors + 1;
            $display("  [FAIL] mode=%0d exp=%0d", flip_mode, m);
        end
        if (flip_h !== m[0] || flip_v !== m[1]) begin
            errors = errors + 1;
            $display("  [FAIL] flip_h=%0d flip_v=%0d 与 mode=%0d 不符", flip_h, flip_v, m);
        end
    end
endtask

task automatic toggle;
    begin
        key_flip = 1'b0;
        repeat (DEB * 3) @(posedge clk);
        key_flip = 1'b1;
        repeat (DEB * 3) @(posedge clk);
    end
endtask

initial begin
    $display("============================================================");
    $display(" tb_flip_ctrl: 4 modes, debounce=%0d", DEB);
    $display("============================================================");

    rst = 1'b1;
    repeat (10) @(posedge clk);
    rst = 1'b0;
    repeat (10) @(posedge clk);

    expect_mode(2'd0);

    toggle; expect_mode(2'd1);        // 左右
    toggle; expect_mode(2'd2);        // 上下
    toggle; expect_mode(2'd3);        // 180°
    toggle; expect_mode(2'd0);        // 回到正常
    toggle; expect_mode(2'd1);        // 再循环

    // 短毛刺（< 消抖时间）不应改变档位
    key_flip = 1'b0;
    repeat (DEB / 2) @(posedge clk);
    key_flip = 1'b1;
    repeat (DEB * 3) @(posedge clk);
    expect_mode(2'd1);

    $display(" checks=%0d errors=%0d", checks, errors);
    $display(" RESULT: %s", (errors == 0) ? "PASS" : "FAIL");
    $finish;
end

endmodule

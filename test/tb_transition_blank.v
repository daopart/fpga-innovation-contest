`timescale 1ns/1ps

module tb_transition_blank;

reg clk = 1'b0;
always #5 clk = ~clk;                 // 100MHz

reg rst = 1'b1;

reg        hs_i = 1'b1;
reg        vs_i = 1'b1;
reg        de_i = 1'b0;
reg [23:0] rgb_i = 24'h00;
reg        disp_valid = 1'b0;
reg        disp_tog = 1'b0;
reg        disp_idx = 1'b0;

wire       hs_o, vs_o, de_o;
wire [23:0] rgb_o;
wire       busy;

video_transition #(
    .H_ACTIVE (640),
    .V_ACTIVE (480),
    .HALF_FRAMES (10)
) dut (
    .clk        (clk),
    .rst        (rst),
    .hs_i       (hs_i),
    .vs_i       (vs_i),
    .de_i       (de_i),
    .rgb_i      (rgb_i),
    .mode       (3'd0),
    .disp_tog   (disp_tog),
    .disp_idx   (disp_idx),
    .disp_valid (disp_valid),
    .busy       (busy),
    .hs_o       (hs_o),
    .vs_o       (vs_o),
    .de_o       (de_o),
    .rgb_o      (rgb_o)
);

integer errors = 0;
integer i;
integer n_de = 0;

task run_pixels(input integer n);
    begin
        for (i = 0; i < n; i = i + 1) begin
            @(negedge clk);
            de_i  = 1'b1;
            rgb_i = 24'hAB_CD_EF;
            @(posedge clk);
            #1;
            if (de_o) begin
                n_de = n_de + 1;
                if (rgb_o !== 24'h000000) begin
                    errors = errors + 1;
                    if (errors < 6)
                        $display("  [FAIL] 无图时输出非黑：%06x (第 %0d 个有效像素)", rgb_o, n_de);
                end
            end
            @(negedge clk);
            de_i = 1'b0;
        end
    end
endtask

initial begin
    $display("============================================================");
    $display(" tb_transition_blank: 无图先熄屏 + 有图正常透传");
    $display("============================================================");

    rst = 1'b1;
    repeat (5) @(posedge clk);
    rst = 1'b0;
    repeat (5) @(posedge clk);

    run_pixels(40);
    $display("  阶段1：输出 %0d 个有效像素，errors=%0d", n_de, errors);
    if (n_de < 10) begin
        $display("  [FAIL] 几乎没有有效像素，时序激励有问题");
        errors = errors + 1;
    end

    disp_valid = 1'b1;
    repeat (6) @(posedge clk);
    n_de  = 0;
    errors = 0;                       // 只看阶段 2
    for (i = 0; i < 40; i = i + 1) begin
        @(negedge clk);
        de_i  = 1'b1;
        rgb_i = 24'hAB_CD_EF;
        @(posedge clk);
        #1;
        if (de_o && (rgb_o !== 24'hAB_CD_EF)) begin
            errors = errors + 1;
            if (errors < 6)
                $display("  [FAIL] 有图时没透传：%06x", rgb_o);
        end
        if (de_o) n_de = n_de + 1;
        @(negedge clk);
        de_i = 1'b0;
    end
    $display("  阶段2：输出 %0d 个有效像素，errors=%0d", n_de, errors);

    $display(" RESULT: %s", (errors == 0 && n_de > 10) ? "PASS" : "FAIL");
    $finish;
end

endmodule

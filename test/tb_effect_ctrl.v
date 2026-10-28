`timescale 1ns/1ps

module tb_effect_ctrl;
    reg clk = 0, rst = 1;
    reg k1d = 0, k2d = 0, img = 0;
    wire [2:0] mode, page;
    wire act;

    always #5 clk = ~clk;

    effect_ctrl #(.CLK_FREQ_HZ(1000), .HIDE_MS(0), .PAGE_COUNT(2)) dut (
        .clk(clk), .rst(rst),
        .key1_double(k1d), .key2_double(k2d), .img_evt(img),
        .trans_mode(mode), .sub_page(page), .sub_active(act)
    );

    integer errors = 0;
    task chk(input [255:0] name, input integer cond);
        begin
            if (!cond) begin
                errors = errors + 1;
                $display("  [FAIL] %0s (page=%0d act=%b)", name, page, act);
            end
        end
    endtask

    task pulse_k2; begin k2d = 1; @(posedge clk); k2d = 0; @(posedge clk); end endtask
    task pulse_img; begin img = 1; @(posedge clk); img = 0; @(posedge clk); end endtask

    initial begin
        repeat (3) @(posedge clk);
        rst <= 0;
        repeat (2) @(posedge clk);

        chk("boot page1 on", page == 3'd1 && act == 1'b1);

        pulse_img;  chk("img1 -> page2", page == 3'd2 && act);
        pulse_img;  chk("img2 -> page1", page == 3'd1 && act);
        pulse_img;  chk("img3 -> page2", page == 3'd2 && act);

        pulse_k2;   chk("dbl -> off", page == 3'd0 && !act);
        pulse_img;  chk("img while off: stays off", page == 3'd0 && !act);

        pulse_k2;   chk("dbl -> page1", page == 3'd1 && act);
        pulse_k2;   chk("dbl -> page2", page == 3'd2 && act);
        pulse_k2;   chk("dbl -> off again", page == 3'd0 && !act);

        $display((errors == 0) ? "RESULT: PASS" : "RESULT: FAIL");
        $display("errors=%0d", errors);
        $finish;
    end
endmodule

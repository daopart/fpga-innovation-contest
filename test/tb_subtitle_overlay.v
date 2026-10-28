`timescale 1ns/1ps

module tb_subtitle_overlay;

localparam integer H_ACT = 640;
localparam integer V_ACT = 480;
localparam integer CLK_P = 10;
localparam [23:0] GRAY = 24'hC0C0C0;

localparam integer BAND_Y  = 400;
localparam integer BAND_H  = 60;
localparam integer LINE_Y0 = 404;

reg clk = 1'b0;
reg rst = 1'b1;

reg  [2:0] page = 3'd0;
reg        hs_i = 1'b0;
reg        vs_i = 1'b1;
reg        de_i = 1'b0;
reg  [23:0] rgb_i = 24'd0;

wire hs_o, vs_o, de_o;
wire [23:0] rgb_o;

always #(CLK_P/2) clk = ~clk;

subtitle_overlay #(
    .H_ACTIVE (H_ACT),
    .V_ACTIVE (V_ACT),
    .BAND_Y   (BAND_Y),
    .BAND_H   (BAND_H),
    .LINE_Y0  (LINE_Y0),
    .PAGE_NUM (4),
    .LINE_W   (3)
) dut (
    .clk   (clk),
    .rst   (rst),
    .page  (page),
    .hs_i  (hs_i),
    .vs_i  (vs_i),
    .de_i  (de_i),
    .rgb_i (rgb_i),
    .hs_o  (hs_o),
    .vs_o  (vs_o),
    .de_o  (de_o),
    .rgb_o (rgb_o)
);

integer fd;
integer ocnt = 0;
integer idx, px, py;
integer n_gold = 0;
integer n_out  = 0;
integer n_band = 0;
integer n_bad  = 0;
integer errors = 0;

task automatic chk(input [255:0] name, input integer cond);
    begin
        if (!cond) begin
            errors = errors + 1;
            $display("  [FAIL] %0s", name);
        end
    end
endtask

function automatic is_gold(input [23:0] c);
    begin
        is_gold = (c == 24'hFFF4AA) || (c == 24'hFFE190) || (c == 24'hFFCE76) ||
                  (c == 24'hFFBB5C) || (c == 24'hFFA842) || (c == 24'hFF9628);
    end
endfunction

always @(negedge clk) begin
    if (de_o) begin
        ocnt = ocnt + 1;
        idx  = ocnt - 1;
        px   = idx % H_ACT;
        py   = idx / H_ACT;
        $fwrite(fd, "%0d %0d %06x\n", px, py, rgb_o);
        if (py >= BAND_Y && py < BAND_Y + BAND_H) begin
            if (page == 3'd0) begin
                if (rgb_o !== GRAY) n_bad = n_bad + 1;
            end else begin
                n_band = n_band + 1;
                if (is_gold(rgb_o))            n_gold = n_gold + 1;
                else if (rgb_o == 24'h461800)  n_out  = n_out + 1;
                else if (rgb_o == 24'h060606)  ;   // 暗底
                else                           n_bad = n_bad + 1;
            end
        end else if (page != 3'd0) begin
            // 黑条以外必须原样直通
            if (rgb_o !== GRAY) n_bad = n_bad + 1;
        end
    end
end

task automatic run_frame(input integer use_page);
    integer y, x;
    begin
        page = use_page[2:0];
        #(20 * CLK_P);

        vs_i = 1'b0;
        repeat (2) begin hs_i = 1'b1; #(CLK_P); hs_i = 1'b0; #(CLK_P); end
        vs_i = 1'b1;
        #(CLK_P);

        for (y = 0; y < V_ACT; y = y + 1) begin
            hs_i = 1'b1; #(CLK_P);
            hs_i = 1'b0; #(CLK_P);
            de_i = 1'b1;
            for (x = 0; x < H_ACT; x = x + 1) begin
                rgb_i = GRAY;
                #(CLK_P);
            end
            de_i = 1'b0;
            rgb_i = 24'd0;
            #(CLK_P);
        end

        repeat (2) begin hs_i = 1'b1; #(CLK_P); hs_i = 1'b0; #(CLK_P); end
        #(4 * CLK_P);
    end
endtask

integer p;
initial begin
    $display("============================================================");
    $display(" tb_subtitle_overlay: %0dx%0d, 4 pages, art text 24x24", H_ACT, V_ACT);
    $display("============================================================");

    rst <= 1'b1;
    repeat (8) @(posedge clk);
    rst <= 1'b0;
    repeat (20) @(posedge clk);

    for (p = 1; p <= 4; p = p + 1) begin
        n_gold = 0; n_out = 0; n_band = 0; n_bad = 0; ocnt = 0;

        case (p)
            1: fd = $fopen("sub_frame_p1.txt", "w");
            2: fd = $fopen("sub_frame_p2.txt", "w");
            3: fd = $fopen("sub_frame_p3.txt", "w");
            default: fd = $fopen("sub_frame_p4.txt", "w");
        endcase
        run_frame(p);
        $fclose(fd);
        chk("page band covered", n_band == 640*60);
        chk("page has text", n_gold > 100);
        chk("page has outline", n_out > 100);
        chk("page only text/outline/dim", n_bad == 0);
        $display(" page%0d: band=%0d gold=%0d outline=%0d other=%0d",
                 p, n_band, n_gold, n_out, n_bad);
    end

    n_gold = 0; n_out = 0; n_band = 0; n_bad = 0; ocnt = 0;
    fd = $fopen("sub_frame_p0.txt", "w");
    run_frame(0);
    $fclose(fd);
    chk("page0 pass-through", n_bad == 0);
    chk("page0 no text", n_gold == 0);
    $display(" page0: band=%0d gold=%0d outline=%0d other=%0d",
             n_band, n_gold, n_out, n_bad);

    $display(" errors=%0d", errors);
    if (errors == 0) $display(" RESULT: PASS");
    else             $display(" RESULT: FAIL");
    $finish;
end

endmodule

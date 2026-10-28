`timescale 1ns/1ps

module tb_video_transition;

localparam integer H_ACT = 8;      // 有效像素
localparam integer V_ACT = 4;      // 有效行
localparam integer HALF  = 16;     // 半转场帧数
localparam integer CLK_P = 10;

reg clk = 1'b0;
reg rst = 1'b1;

reg        disp_tog   = 1'b0;
reg        disp_idx   = 1'b0;
reg        disp_valid = 1'b0;
reg  [2:0] mode       = 3'd0;

reg        hs_i = 1'b0;
reg        vs_i = 1'b1;
reg        de_i = 1'b0;
reg  [23:0] rgb_i = 24'd0;

wire        disp_buf;
wire        hs_o, vs_o, de_o;
wire [23:0] rgb_o;
wire        busy;

always #(CLK_P/2) clk = ~clk;

video_transition #(
    .H_ACTIVE    (H_ACT),
    .V_ACTIVE    (V_ACT),
    .HALF_FRAMES (HALF),
    .X0          (0)
) dut (
    .clk        (clk),
    .rst        (rst),
    .disp_tog   (disp_tog),
    .disp_idx   (disp_idx),
    .disp_valid (disp_valid),
    .disp_buf   (disp_buf),
    .mode       (mode),
    .hs_i       (hs_i),
    .vs_i       (vs_i),
    .de_i       (de_i),
    .rgb_i      (rgb_i),
    .hs_o       (hs_o),
    .vs_o       (vs_o),
    .de_o       (de_o),
    .rgb_o      (rgb_o),
    .busy       (busy)
);

integer errors = 0;
integer checks = 0;
reg [23:0] mid_px;          // 本帧“中间像素”的输出
reg [23:0] last_px;         // 本帧最后一个有效像素的输出
reg [23:0] first_px;        // 本帧第一个有效像素的输出

task automatic chk(input [255:0] name, input integer cond);
    begin
        checks = checks + 1;
        if (!cond) begin
            errors = errors + 1;
            $display("  [FAIL] %0s (t=%0t)", name, $time);
        end
    end
endtask

//---------------------------------------------------------- 一帧微型视频

task automatic drive_frame(input [23:0] color);
    integer l, x;
    begin
        mid_px   = 24'hxxxxxx;
        last_px  = 24'hxxxxxx;
        first_px = 24'hxxxxxx;

        // 场同步（低有效）
        vs_i = 1'b0;
        for (l = 0; l < 2; l = l + 1) begin
            hs_i = 1'b1; #(CLK_P);
            hs_i = 1'b0; #(CLK_P);
        end
        vs_i = 1'b1;
        #(CLK_P);

        for (l = 0; l < V_ACT; l = l + 1) begin
            hs_i = 1'b1; #(CLK_P);
            hs_i = 1'b0; #(CLK_P);

            de_i = 1'b1;
            for (x = 0; x < H_ACT; x = x + 1) begin
                rgb_i = color;
                #(CLK_P);
                if ((l == 0) && (x == 0))
                    first_px = rgb_o;
                if ((l == V_ACT/2) && (x == H_ACT/2))
                    mid_px = rgb_o;
                if ((l == V_ACT-1) && (x == H_ACT-1))
                    last_px = rgb_o;
            end
            de_i = 1'b0;
            rgb_i = 24'd0;
            #(CLK_P);
        end

        for (l = 0; l < 2; l = l + 1) begin
            hs_i = 1'b1; #(CLK_P);
            hs_i = 1'b0; #(CLK_P);
        end
    end
endtask

task automatic run_frames(input integer n);
    integer k;
    begin
        for (k = 0; k < n; k = k + 1)
            drive_frame(24'hFFFFFF);
    end
endtask

always @(posedge clk) begin
    if (dut.vs_start && $time < 8000) begin
        $display("  %0t VS tog=%b pend=%b act=%b busy=%b frm=%0d scale=%0d buf=%b shown=%b",
                 $time, disp_tog, dut.pending_img, dut.active, busy,
                 dut.frame_cnt, dut.scale, disp_buf, dut.shown);
    end
end

initial begin
    $display("============================================================");
    $display(" tb_video_transition: H=%0d V=%0d HALF=%0d", H_ACT, V_ACT, HALF);
    $display("============================================================");

    rst <= 1'b1;
    repeat (4) @(posedge clk);
    rst <= 1'b0;
    repeat (2) @(posedge clk);

    //------------------------------------------------ 1) 第一张图
    $display("[1] 第一张图：disp_valid=1 后直接出图，不压黑");
    mode       <= 3'd1;
    disp_valid <= 1'b1;
    disp_idx   <= 1'b0;
    run_frames(6);
    chk("first image buf = 0", disp_buf === 1'b0);
    chk("first image not black", last_px !== 24'd0);

    //------------------------------------------------ 2) mode 0 直切
    $display("[2] mode=0 直切：新图一到就换缓冲，不 busy");
    mode     <= 3'd0;
    disp_idx <= 1'b1;
    disp_tog <= ~disp_tog;
    run_frames(4);
    chk("cut: buf follows new image", disp_buf === 1'b1);
    chk("cut: not busy", busy === 1'b0);

    //------------------------------------------------ 3) mode 1 淡入淡出
    $display("[3] mode=1 淡入淡出：中点压黑、中点换缓冲");
    mode     <= 3'd1;
    disp_idx <= 1'b0;
    disp_tog <= ~disp_tog;
    run_frames(2);
    chk("fade: busy after new image", busy === 1'b1);
    run_frames(2);
    chk("fade: buf still old before mid", disp_buf === 1'b1);
    chk("fade: still visible before mid", last_px[23:16] > 8'h20);

    run_frames(HALF - 3);
    chk("fade: near black at mid", last_px[23:16] < 8'h08);

    run_frames(2);
    chk("fade: buf swapped after mid", disp_buf === 1'b0);

    run_frames(HALF + 4);             // 跑完
    chk("fade: finished (not busy)", busy === 1'b0);
    chk("fade: buf = new image", disp_buf === 1'b0);
    chk("fade: back to full brightness", last_px[23:16] > 8'hE0);

    //------------------------------------------------ 4) mode 2 左→右
    $display("[4] mode=2 左→右：左侧先变黑");
    mode     <= 3'd2;
    disp_idx <= 1'b1;
    disp_tog <= ~disp_tog;
    run_frames(3);
    chk("wipe: busy", busy === 1'b1);
    chk("wipe: left/mid black", mid_px === 24'd0);
    run_frames(2*HALF + 4);
    chk("wipe: finished", busy === 1'b0);

    //------------------------------------------------ 5) mode 3 上→下
    $display("[5] mode=3 上→下：上方先变黑");
    mode     <= 3'd3;
    disp_idx <= 1'b0;
    disp_tog <= ~disp_tog;
    run_frames(4);
    chk("bar: busy", busy === 1'b1);
    chk("bar: top black", first_px === 24'd0);
    run_frames(2*HALF + 4);
    chk("bar: finished", busy === 1'b0);

    $display("------------------------------------------------------------");
    $display(" checks=%0d errors=%0d", checks, errors);
    if (errors == 0)
        $display(" RESULT: PASS");
    else
        $display(" RESULT: FAIL");
    $display("============================================================");
    $finish;
end

endmodule

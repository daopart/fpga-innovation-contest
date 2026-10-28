`timescale 1ns/1ps

module video_zoom #(
    parameter H_ACTIVE  = 640,
    parameter V_ACTIVE  = 480,
    parameter BUF0_ADDR = 0,
    parameter BUF1_ADDR = 307200
)(
    input  wire        video_clk,
    input  wire        rst,                 // 高有效

    input  wire        hs_i,
    input  wire        vs_i,
    input  wire        de_i,

    output reg         hs_o,
    output reg         vs_o,
    output reg         de_o,
    output wire [23:0] rgb_o,

    input  wire        buf_sel,

    output reg         line_req,            // 保持到 line_ack
    input  wire        line_ack,
    output reg  [20:0] line_addr,
    input  wire        line_empty,          // 读 FIFO 空标志
    output wire        line_ren,            // 读 FIFO 取数
    input  wire [31:0] line_rdata,          // {8'h00, R, G, B}

    input  wire        zoom_in_tog,
    input  wire        zoom_out_tog,
    output reg  [2:0]  zoom_level,

    input  wire        flip_h_i,           // 1 = 左右镜像
    input  wire        flip_v_i            // 1 = 上下镜像
);
localparam integer HC = H_ACTIVE / 2;
localparam integer VC = V_ACTIVE / 2;

localparam [2:0] ZOOM_05 = 3'd0;
localparam [2:0] ZOOM_1X = 3'd1;
localparam [2:0] ZOOM_2X = 3'd2;
localparam [2:0] ZOOM_3X = 3'd3;
localparam [2:0] ZOOM_4X = 3'd4;

//------------------------------------------------------------------ 倍率参数

reg  signed [15:0] step_q8;
reg  signed [23:0] h_acc_init;
reg  signed [23:0] v_acc_init;

always @(*) begin
    case (zoom_level)
        ZOOM_05: begin
            step_q8    = 16'sd512;                  // 1/0.5 = 2 像素
            h_acc_init = HC*256 - HC*512;
            v_acc_init = VC*256 - VC*512;
        end
        ZOOM_2X: begin
            step_q8    = 16'sd128;                  // 1/2 = 0.5 像素
            h_acc_init = HC*256 - HC*128;
            v_acc_init = VC*256 - VC*128;
        end
        ZOOM_3X: begin
            step_q8    = 16'sd64;
            h_acc_init = HC*256 - HC*64;
            v_acc_init = VC*256 - VC*64;
        end
        ZOOM_4X: begin
            step_q8    = 16'sd32;
            h_acc_init = HC*256 - HC*32;
            v_acc_init = VC*256 - VC*32;
        end
        default: begin
            step_q8    = 16'sd256;
            h_acc_init = 24'sd0;
            v_acc_init = 24'sd0;
        end
    endcase
end

//-------------------------------------------------------------- 按键事件同步
reg [2:0] zi_sync;
reg [2:0] zo_sync;

always @(posedge video_clk or posedge rst) begin
    if (rst) begin
        zi_sync <= 3'd0;
        zo_sync <= 3'd0;
    end else begin
        zi_sync <= {zi_sync[1:0], zoom_in_tog};
        zo_sync <= {zo_sync[1:0], zoom_out_tog};
    end
end

wire zi_pulse = zi_sync[2] ^ zi_sync[1];
wire zo_pulse = zo_sync[2] ^ zo_sync[1];

always @(posedge video_clk or posedge rst) begin
    if (rst)
        zoom_level <= ZOOM_1X;
    else if (zi_pulse && (zoom_level != ZOOM_4X))
        zoom_level <= zoom_level + 3'd1;
    else if (zo_pulse && (zoom_level != ZOOM_05))
        zoom_level <= zoom_level - 3'd1;
end

//---------------------------------------------------------------- 时序边沿
reg de_d;
reg vs_d;

wire line_start  = de_i & ~de_d;                // 一行第一个有效像素
wire frame_start = vs_d & ~vs_i;

always @(posedge video_clk or posedge rst) begin
    if (rst) begin
        de_d <= 1'b0;
        vs_d <= 1'b1;
    end else begin
        de_d <= de_i;
        vs_d <= vs_i;
    end
end

reg [1:0] base_sync;

always @(posedge video_clk or posedge rst) begin
    if (rst)
        base_sync <= 2'b00;
    else
        base_sync <= {base_sync[0], buf_sel};
end

//----------------------------------------------------------- 行缓存与搬运状态

reg [23:0] line_buf [0:2*H_ACTIVE-1];
reg [23:0] rd_q;                 // 行缓存读出寄存

reg        bank;
reg        cur_bank;             // 当前正在显示的 bank
reg        cur_vld;              // 当前行缓存是否有效
reg        fetch_ok;             // 本次搬运是否完成
reg        fill_active;
reg        req_wait;
reg  [9:0] fill_cnt;
reg        fill_bank;
reg  [1:0] ack_sync;
reg        ren_d;

reg signed [23:0] h_acc;         // 水平源坐标（Q8）
reg signed [23:0] v_acc;         // 垂直源坐标（Q8）
reg signed [15:0] step_l;        // 本帧锁存的步进
reg signed [23:0] h_acc0_l;
reg [20:0]        base_l;        // 本帧读的帧缓存基地址
reg               flip_h_l;      // 本帧锁存的左右翻转
reg               flip_v_l;      // 本帧锁存的上下翻转

reg [12:0] req_timer;            // 申请超时保护
reg [12:0] fill_timer;           // 搬运超时保护
reg [4:0]  pop_wait;             // 应答后取数前的等待

wire fetch_idle = ~fill_active & ~req_wait;

// 下一行（第 N+1 行）的源行坐标
wire signed [23:0] v_acc_next = v_acc + step_l;
wire [9:0]         src_y_next = v_acc_next[17:8];
wire               v_next_ok  = (v_acc_next >= 0) && (v_acc_next < (V_ACTIVE*256));

wire [9:0]         src_y_flip  = flip_v_l ? ((V_ACTIVE-1) - src_y_next) : src_y_next;
wire [18:0]        row_off    = {src_y_flip, 9'd0} + {src_y_flip, 7'd0};   // *640

// 第 0 行的源行坐标（场起始用）
wire [9:0]  src_y_first = v_acc_init[17:8];
wire        v_first_ok  = (v_acc_init >= 0) && (v_acc_init < (V_ACTIVE*256));
wire [9:0]  src_y_first_f = flip_v_i ? ((V_ACTIVE-1) - src_y_first) : src_y_first;
wire [18:0] row_off_fst = {src_y_first_f, 9'd0} + {src_y_first_f, 7'd0};

wire [20:0] base_now = base_sync[1] ? BUF1_ADDR : BUF0_ADDR;

//-------------------------------------------------------- 显示取点（组合逻辑）

wire signed [23:0] h_acc_pre    = line_start ? h_acc0_l : h_acc;
wire signed [23:0] h_src        = h_acc_pre >>> 8;
wire               h_ok         = (h_src >= 0) && (h_src < (H_ACTIVE));
wire [9:0]         src_x        = h_ok ? h_src[9:0] : 10'd0;

wire [9:0]         src_x_rd     = flip_h_l ? ((H_ACTIVE-1) - src_x) : src_x;
wire               cur_bank_eff = line_start ? bank : cur_bank;
wire               cur_vld_eff  = line_start ? fetch_ok : cur_vld;

assign line_ren = fill_active & ~line_empty & ~req_wait & (pop_wait == 5'd0);

wire [10:0] wr_index = fill_bank ? (11'd640 + {1'b0, fill_cnt}) : {1'b0, fill_cnt};
wire [10:0] rd_index = cur_bank_eff ? (11'd640 + {1'b0, src_x_rd}) : {1'b0, src_x_rd};

always @(posedge video_clk or posedge rst) begin
    if (rst) begin
        ack_sync <= 2'b00;
        ren_d    <= 1'b0;
    end else begin
        ack_sync <= {ack_sync[0], line_ack};
        ren_d    <= line_ren;
    end
end

always @(posedge video_clk or posedge rst) begin
    if (rst) begin
        line_req    <= 1'b0;
        line_addr   <= 21'd0;
        req_wait    <= 1'b0;
        fill_active <= 1'b0;
        fill_cnt    <= 10'd0;
        fill_bank   <= 1'b0;
        fetch_ok    <= 1'b0;
        bank        <= 1'b0;
        cur_bank    <= 1'b0;
        cur_vld     <= 1'b0;
        h_acc       <= 24'sd0;
        v_acc       <= 24'sd0;
        step_l      <= 16'sd256;
        h_acc0_l    <= 24'sd0;
        base_l      <= 21'd0;
        flip_h_l    <= 1'b0;
        flip_v_l    <= 1'b0;
        req_timer   <= 13'd0;
        fill_timer  <= 13'd0;
        pop_wait    <= 5'd0;
        hs_o        <= 1'b0;
        vs_o        <= 1'b0;
        de_o        <= 1'b0;
    end else begin
        //------------------------------------------------------ 1. 申请应答
        if (req_wait) begin
            req_timer <= req_timer + 13'd1;
            if (ack_sync[1]) begin
                line_req  <= 1'b0;
                req_wait  <= 1'b0;
                req_timer <= 13'd0;
            end else if (req_timer[12]) begin        // 超时保护（SDRAM 未就绪等）
                line_req    <= 1'b0;
                req_wait    <= 1'b0;
                fill_active <= 1'b0;
                req_timer   <= 13'd0;
            end
        end else begin
            req_timer <= 13'd0;
        end

        if (req_wait)
            pop_wait <= 5'd16;
        else if (pop_wait != 5'd0)
            pop_wait <= pop_wait - 5'd1;

        //------------------------------------------------------ 2. 整行搬运
        if (fill_active) begin
            fill_timer <= fill_timer + 13'd1;
            if (fill_timer[12]) begin
                fill_active <= 1'b0;
                fill_timer  <= 13'd0;
            end
        end else begin
            fill_timer <= 13'd0;
        end

        if (ren_d && fill_active) begin
            if (fill_cnt == (H_ACTIVE-1)) begin
                fill_active <= 1'b0;
                fetch_ok    <= 1'b1;
            end else begin
                fill_cnt <= fill_cnt + 10'd1;
            end
        end

        //-------------------------------------------------- 3. 帧 / 行 调度
        if (frame_start) begin
            step_l    <= step_q8;
            h_acc0_l  <= h_acc_init;
            base_l    <= base_now;
            flip_h_l  <= flip_h_i;                   // 每场起始锁存翻转状态
            flip_v_l  <= flip_v_i;
            v_acc     <= v_acc_init;
            bank      <= 1'b0;
            cur_vld   <= 1'b0;
            fetch_ok  <= 1'b0;
            if (fetch_idle && v_first_ok) begin
                line_addr   <= base_now + row_off_fst;
                line_req    <= 1'b1;
                req_wait    <= 1'b1;
                fill_bank   <= 1'b0;
                fill_cnt    <= 10'd0;
                fill_active <= 1'b1;
            end
        end else if (line_start) begin
            cur_bank <= bank;                        // 上一次申请的 bank
            cur_vld  <= fetch_ok;
            fetch_ok <= 1'b0;
            v_acc    <= v_acc_next;
            if (fetch_idle && v_next_ok) begin
                line_addr   <= base_l + row_off;
                line_req    <= 1'b1;
                req_wait    <= 1'b1;
                fill_bank   <= ~bank;
                fill_cnt    <= 10'd0;
                fill_active <= 1'b1;
                bank        <= ~bank;                // 只有真正发申请时才换 bank
            end
        end

        //---------------------------------------------------- 4. 水平累加
        if (de_i)
            h_acc <= h_acc_pre + step_l;

        //---------------------------------------------------- 5. 输出延时对齐
        hs_o <= hs_i;
        vs_o <= vs_i;
        de_o <= de_i;
    end
end

//--------------------------------------------------- 行缓存（简单双端口 RAM）

reg rd_ok;

always @(posedge video_clk) begin
    if (ren_d && fill_active)
        line_buf[wr_index] <= line_rdata[31:8];

    rd_q  <= line_buf[rd_index];
    rd_ok <= de_i && h_ok && cur_vld_eff;      // 与 rd_q 同一拍
end

assign rgb_o = rd_ok ? rd_q : 24'd0;

endmodule

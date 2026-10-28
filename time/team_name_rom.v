`timescale 1ns/1ps
//=============================================================================
//  team_name_rom.v —— 「奶蛙队」32x32 点阵（开机动画队名）
//  由 tools/gen_team_rom.py 生成，字体：msyhbd.ttc
//  每行 32 bit，MSB = 最左像素；I_ch：0=奶 1=蛙 2=队
//=============================================================================
module team_name_rom (
    input  wire [1:0]  I_ch,
    input  wire [5:0]  I_row,
    output reg  [31:0] O_bits
);
    always @(*) begin
        case ({I_ch, I_row})
            8'd0  : O_bits = 32'h00000000;   // 奶 行 0
            8'd1  : O_bits = 32'h0F000000;   // 奶 行 1
            8'd2  : O_bits = 32'h0F000000;   // 奶 行 2
            8'd3  : O_bits = 32'h0F07FFF0;   // 奶 行 3
            8'd4  : O_bits = 32'h0F07FFF0;   // 奶 行 4
            8'd5  : O_bits = 32'h1F07FFF0;   // 奶 行 5
            8'd6  : O_bits = 32'h7FFFFFF0;   // 奶 行 6
            8'd7  : O_bits = 32'h7FF8F0F0;   // 奶 行 7
            8'd8  : O_bits = 32'h7FF8F0F0;   // 奶 行 8
            8'd9  : O_bits = 32'h7FF8F1E0;   // 奶 行 9
            8'd10 : O_bits = 32'h1E78F1E0;   // 奶 行 10
            8'd11 : O_bits = 32'h1C78F3E0;   // 奶 行 11
            8'd12 : O_bits = 32'h3C70F3FE;   // 奶 行 12
            8'd13 : O_bits = 32'h3C70F3FE;   // 奶 行 13
            8'd14 : O_bits = 32'h3CF1F3FE;   // 奶 行 14
            8'd15 : O_bits = 32'h3CF1F3FE;   // 奶 行 15
            8'd16 : O_bits = 32'h38F1F03E;   // 奶 行 16
            8'd17 : O_bits = 32'h78F1E03E;   // 奶 行 17
            8'd18 : O_bits = 32'h7FE1E03C;   // 奶 行 18
            8'd19 : O_bits = 32'h3FE1E03C;   // 奶 行 19
            8'd20 : O_bits = 32'h1FE3E03C;   // 奶 行 20
            8'd21 : O_bits = 32'h0FE3E03C;   // 奶 行 21
            8'd22 : O_bits = 32'h07F3C03C;   // 奶 行 22
            8'd23 : O_bits = 32'h0FF7C03C;   // 奶 行 23
            8'd24 : O_bits = 32'h1FE7C03C;   // 奶 行 24
            8'd25 : O_bits = 32'h3F6F807C;   // 奶 行 25
            8'd26 : O_bits = 32'h7E1F8FFC;   // 奶 行 26
            8'd27 : O_bits = 32'h7C3F0FFC;   // 奶 行 27
            8'd28 : O_bits = 32'h781F0FF8;   // 奶 行 28
            8'd29 : O_bits = 32'h300E0FE0;   // 奶 行 29
            8'd30 : O_bits = 32'h00040000;   // 奶 行 30
            8'd31 : O_bits = 32'h00000000;   // 奶 行 31
            8'd64 : O_bits = 32'h00000000;   // 蛙 行 0
            8'd65 : O_bits = 32'h07800F00;   // 蛙 行 1
            8'd66 : O_bits = 32'h07800F00;   // 蛙 行 2
            8'd67 : O_bits = 32'h07800F00;   // 蛙 行 3
            8'd68 : O_bits = 32'h07800F00;   // 蛙 行 4
            8'd69 : O_bits = 32'h0781FFFC;   // 蛙 行 5
            8'd70 : O_bits = 32'h7FF9FFFC;   // 蛙 行 6
            8'd71 : O_bits = 32'h7FF9FFFC;   // 蛙 行 7
            8'd72 : O_bits = 32'h7FF9FFFC;   // 蛙 行 8
            8'd73 : O_bits = 32'h77B80F00;   // 蛙 行 9
            8'd74 : O_bits = 32'h77B80F00;   // 蛙 行 10
            8'd75 : O_bits = 32'h77B80F00;   // 蛙 行 11
            8'd76 : O_bits = 32'h77BBFFFE;   // 蛙 行 12
            8'd77 : O_bits = 32'h77BBFFFE;   // 蛙 行 13
            8'd78 : O_bits = 32'h77BBFFFE;   // 蛙 行 14
            8'd79 : O_bits = 32'h77BBFFFE;   // 蛙 行 15
            8'd80 : O_bits = 32'h77B80000;   // 蛙 行 16
            8'd81 : O_bits = 32'h7FF80F00;   // 蛙 行 17
            8'd82 : O_bits = 32'h7FF80F00;   // 蛙 行 18
            8'd83 : O_bits = 32'h7FF80F00;   // 蛙 行 19
            8'd84 : O_bits = 32'h7783FFFC;   // 蛙 行 20
            8'd85 : O_bits = 32'h779BFFFC;   // 蛙 行 21
            8'd86 : O_bits = 32'h07BBFFFC;   // 蛙 行 22
            8'd87 : O_bits = 32'h07B9FFFC;   // 蛙 行 23
            8'd88 : O_bits = 32'h079C0F00;   // 蛙 行 24
            8'd89 : O_bits = 32'h07FC0F00;   // 蛙 行 25
            8'd90 : O_bits = 32'hFFFC0F00;   // 蛙 行 26
            8'd91 : O_bits = 32'h7FFFFFFF;   // 蛙 行 27
            8'd92 : O_bits = 32'h7FFFFFFF;   // 蛙 行 28
            8'd93 : O_bits = 32'h780FFFFF;   // 蛙 行 29
            8'd94 : O_bits = 32'h0007FFFE;   // 蛙 行 30
            8'd95 : O_bits = 32'h00000000;   // 蛙 行 31
            8'd128: O_bits = 32'h00000000;   // 队 行 0
            8'd129: O_bits = 32'h3FFC1E00;   // 队 行 1
            8'd130: O_bits = 32'h3FFC1E00;   // 队 行 2
            8'd131: O_bits = 32'h3FFC1E00;   // 队 行 3
            8'd132: O_bits = 32'h3FFC1E00;   // 队 行 4
            8'd133: O_bits = 32'h3C781E00;   // 队 行 5
            8'd134: O_bits = 32'h3C781E00;   // 队 行 6
            8'd135: O_bits = 32'h3CF81E00;   // 队 行 7
            8'd136: O_bits = 32'h3CF03E00;   // 队 行 8
            8'd137: O_bits = 32'h3CF03E00;   // 队 行 9
            8'd138: O_bits = 32'h3DE03F00;   // 队 行 10
            8'd139: O_bits = 32'h3DE03F00;   // 队 行 11
            8'd140: O_bits = 32'h3DE03F00;   // 队 行 12
            8'd141: O_bits = 32'h3CF03F00;   // 队 行 13
            8'd142: O_bits = 32'h3CF83F00;   // 队 行 14
            8'd143: O_bits = 32'h3C787F80;   // 队 行 15
            8'd144: O_bits = 32'h3C7C7F80;   // 队 行 16
            8'd145: O_bits = 32'h3C3C7F80;   // 队 行 17
            8'd146: O_bits = 32'h3C7CFBC0;   // 队 行 18
            8'd147: O_bits = 32'h3FFCF3C0;   // 队 行 19
            8'd148: O_bits = 32'h3FF9F3E0;   // 队 行 20
            8'd149: O_bits = 32'h3FFBF1E0;   // 队 行 21
            8'd150: O_bits = 32'h3DE3E1F0;   // 队 行 22
            8'd151: O_bits = 32'h3C07C0F8;   // 队 行 23
            8'd152: O_bits = 32'h3C0FC0FC;   // 队 行 24
            8'd153: O_bits = 32'h3C3F807E;   // 队 行 25
            8'd154: O_bits = 32'h3C3F003E;   // 队 行 26
            8'd155: O_bits = 32'h3C1E003C;   // 队 行 27
            8'd156: O_bits = 32'h3C1C001C;   // 队 行 28
            8'd157: O_bits = 32'h3C080008;   // 队 行 29
            8'd158: O_bits = 32'h3C000000;   // 队 行 30
            8'd159: O_bits = 32'h00000000;   // 队 行 31
            default: O_bits = 32'h0000_0000;
        endcase
    end
endmodule

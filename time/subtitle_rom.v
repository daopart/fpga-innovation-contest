`timescale 1ns/1ps
//=============================================================================
//  subtitle_rom.v -- 字幕艺术字字模 / 文本 ROM（由 tools/gen_subtitle_rom.py 生成）
//
//  【不要手改本文件】
//    改 tools/gen_subtitle_rom.py 里的 SUBTITLE_LINES / 字体，重新运行生成脚本。
//
//  subtitle_font_rom: glyph(1..27) x row(0..23) -> fill/outline 两层 24bit 掩膜
//      bit23 = 该行最左像素；fill = 字身，outline = 向外扩 1 像素的描边
//  subtitle_text_rom: line x x -> 字模号 + 字模内列号
//
//  字模：27 个 24x24 双掩膜，共 31104 bit（≈ 30.4 Kb）。
//  字体：华文行楷 21px；金色渐变和描边色在 RTL 里给。
//=============================================================================

//------------------------------------------------------------------ 字模表
module subtitle_font_rom (
    input  wire [7:0]  glyph,          // 0 = 空白，1..27 = 有效字模
    input  wire [4:0]  row,            // 0..23
    output reg  [23:0] fill,           // 字身掩膜，bit23 在最左
    output reg  [23:0] outline         // 描边掩膜，bit23 在最左
);

    always @(*) begin
        fill    = 24'd0;
        outline = 24'd0;
        case (glyph)
            8'd1: case (row)   // '康' U+5EB7
                5'd0 : begin fill = 24'h000000; outline = 24'h007000; end
                5'd1 : begin fill = 24'h002000; outline = 24'h007C00; end
                5'd2 : begin fill = 24'h003800; outline = 24'h00FC00; end
                5'd3 : begin fill = 24'h007800; outline = 24'h03FF00; end
                5'd4 : begin fill = 24'h01FE00; outline = 24'h0FFF00; end
                5'd5 : begin fill = 24'h07FE00; outline = 24'h0FFF00; end
                5'd6 : begin fill = 24'h07F800; outline = 24'h0FFF80; end
                5'd7 : begin fill = 24'h07DF00; outline = 24'h0FFFC0; end
                5'd8 : begin fill = 24'h01B980; outline = 24'h0FFFC0; end
                5'd9 : begin fill = 24'h01FD80; outline = 24'h07FFC0; end
                5'd10: begin fill = 24'h03BF00; outline = 24'h07FFC0; end
                5'd11: begin fill = 24'h027F00; outline = 24'h07FF80; end
                5'd12: begin fill = 24'h021E00; outline = 24'h0FFF80; end
                5'd13: begin fill = 24'h067D00; outline = 24'h0FFFC0; end
                5'd14: begin fill = 24'h047B80; outline = 24'h1FFFC0; end
                5'd15: begin fill = 24'h0D9F00; outline = 24'h1FFFC0; end
                5'd16: begin fill = 24'h08DB00; outline = 24'h1FFFC0; end
                5'd17: begin fill = 24'h08FB80; outline = 24'h3FFFE0; end
                5'd18: begin fill = 24'h11FBC0; outline = 24'h3FFFE0; end
                5'd19: begin fill = 24'h10B8C0; outline = 24'h3BFFE0; end
                5'd20: begin fill = 24'h001800; outline = 24'h39FDE0; end
                5'd21: begin fill = 24'h000800; outline = 24'h003C00; end
                5'd22: begin fill = 24'h000000; outline = 24'h001C00; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd2: case (row)   // '神' U+795E
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h0003C0; end
                5'd2 : begin fill = 24'h000180; outline = 24'h01F3C0; end
                5'd3 : begin fill = 24'h00E180; outline = 24'h01F3C0; end
                5'd4 : begin fill = 24'h006180; outline = 24'h03F3C0; end
                5'd5 : begin fill = 24'h01E180; outline = 24'h07F7F8; end
                5'd6 : begin fill = 24'h0203F0; outline = 24'h07FFF8; end
                5'd7 : begin fill = 24'h00C7B0; outline = 24'h07FFFC; end
                5'd8 : begin fill = 24'h01FBB8; outline = 24'h1FFFFC; end
                5'd9 : begin fill = 24'h0FFFF0; outline = 24'h1FFFFC; end
                5'd10: begin fill = 24'h0FFFB0; outline = 24'h1FFFF8; end
                5'd11: begin fill = 24'h06CBE0; outline = 24'h1FFFF8; end
                5'd12: begin fill = 24'h01CFE0; outline = 24'h0FFFF0; end
                5'd13: begin fill = 24'h078F00; outline = 24'h0FFFF0; end
                5'd14: begin fill = 24'h078300; outline = 24'h0FDF80; end
                5'd15: begin fill = 24'h048300; outline = 24'h0FC780; end
                5'd16: begin fill = 24'h008300; outline = 24'h0FC780; end
                5'd17: begin fill = 24'h008100; outline = 24'h01C780; end
                5'd18: begin fill = 24'h000100; outline = 24'h01C380; end
                5'd19: begin fill = 24'h000100; outline = 24'h000380; end
                5'd20: begin fill = 24'h000100; outline = 24'h000380; end
                5'd21: begin fill = 24'h000000; outline = 24'h000380; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd3: case (row)   // '开' U+5F00
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd2 : begin fill = 24'h000000; outline = 24'h003F00; end
                5'd3 : begin fill = 24'h001E00; outline = 24'h01FF80; end
                5'd4 : begin fill = 24'h00FF00; outline = 24'h01FF80; end
                5'd5 : begin fill = 24'h007C00; outline = 24'h01FF80; end
                5'd6 : begin fill = 24'h003E00; outline = 24'h00FF00; end
                5'd7 : begin fill = 24'h007600; outline = 24'h01FFF0; end
                5'd8 : begin fill = 24'h00E7E0; outline = 24'h03FFF8; end
                5'd9 : begin fill = 24'h01FFF0; outline = 24'h07FFF8; end
                5'd10: begin fill = 24'h03FE00; outline = 24'h0FFFF8; end
                5'd11: begin fill = 24'h07F600; outline = 24'h1FFF00; end
                5'd12: begin fill = 24'h0FC600; outline = 24'h1FFF00; end
                5'd13: begin fill = 24'h07C600; outline = 24'h1FEF00; end
                5'd14: begin fill = 24'h00C600; outline = 24'h0FEF00; end
                5'd15: begin fill = 24'h00C600; outline = 24'h03EF00; end
                5'd16: begin fill = 24'h01C600; outline = 24'h03EF00; end
                5'd17: begin fill = 24'h018600; outline = 24'h03EF00; end
                5'd18: begin fill = 24'h000600; outline = 24'h03CF00; end
                5'd19: begin fill = 24'h000600; outline = 24'h000F00; end
                5'd20: begin fill = 24'h000200; outline = 24'h000F00; end
                5'd21: begin fill = 24'h000000; outline = 24'h000700; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd4: case (row)   // '播' U+64AD
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd2 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd3 : begin fill = 24'h000000; outline = 24'h038F80; end
                5'd4 : begin fill = 24'h010700; outline = 24'h03DF80; end
                5'd5 : begin fill = 24'h018F00; outline = 24'h03FF80; end
                5'd6 : begin fill = 24'h019D00; outline = 24'h03FF80; end
                5'd7 : begin fill = 24'h01CF00; outline = 24'h07FF80; end
                5'd8 : begin fill = 24'h03FF00; outline = 24'h1FFFC0; end
                5'd9 : begin fill = 24'h0F9F80; outline = 24'h1FFFC0; end
                5'd10: begin fill = 24'h0F3E00; outline = 24'h1FFFF0; end
                5'd11: begin fill = 24'h07BFE0; outline = 24'h1FFFF0; end
                5'd12: begin fill = 24'h011CE0; outline = 24'h0FFFF0; end
                5'd13: begin fill = 24'h077780; outline = 24'h3FFFF0; end
                5'd14: begin fill = 24'h1FFEC0; outline = 24'h3FFFE0; end
                5'd15: begin fill = 24'h09BEC0; outline = 24'h3FFFE0; end
                5'd16: begin fill = 24'h011CC0; outline = 24'h1FFFE0; end
                5'd17: begin fill = 24'h031780; outline = 24'h07BFE0; end
                5'd18: begin fill = 24'h011B80; outline = 24'h07BFC0; end
                5'd19: begin fill = 24'h010000; outline = 24'h03BFC0; end
                5'd20: begin fill = 24'h000000; outline = 24'h038000; end
                5'd21: begin fill = 24'h000000; outline = 24'h000000; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd5: case (row)   // '了' U+4E86
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd2 : begin fill = 24'h000000; outline = 24'h000F00; end
                5'd3 : begin fill = 24'h000600; outline = 24'h007F80; end
                5'd4 : begin fill = 24'h003F00; outline = 24'h03FF80; end
                5'd5 : begin fill = 24'h01E700; outline = 24'h07FF80; end
                5'd6 : begin fill = 24'h03CF00; outline = 24'h07FF80; end
                5'd7 : begin fill = 24'h039E00; outline = 24'h07FF80; end
                5'd8 : begin fill = 24'h037C00; outline = 24'h07FF00; end
                5'd9 : begin fill = 24'h003800; outline = 24'h07FE00; end
                5'd10: begin fill = 24'h001800; outline = 24'h007C00; end
                5'd11: begin fill = 24'h000800; outline = 24'h003C00; end
                5'd12: begin fill = 24'h000800; outline = 24'h001C00; end
                5'd13: begin fill = 24'h000800; outline = 24'h001C00; end
                5'd14: begin fill = 24'h000800; outline = 24'h001E00; end
                5'd15: begin fill = 24'h000C00; outline = 24'h001E00; end
                5'd16: begin fill = 24'h000C00; outline = 24'h003E00; end
                5'd17: begin fill = 24'h001C00; outline = 24'h01FE00; end
                5'd18: begin fill = 24'h00F800; outline = 24'h01FE00; end
                5'd19: begin fill = 24'h007800; outline = 24'h01FC00; end
                5'd20: begin fill = 24'h001000; outline = 24'h00FC00; end
                5'd21: begin fill = 24'h000000; outline = 24'h003800; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd6: case (row)   // '真' U+771F
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd2 : begin fill = 24'h000000; outline = 24'h000E00; end
                5'd3 : begin fill = 24'h000400; outline = 24'h001F80; end
                5'd4 : begin fill = 24'h000F00; outline = 24'h001F80; end
                5'd5 : begin fill = 24'h000F00; outline = 24'h003F80; end
                5'd6 : begin fill = 24'h001E00; outline = 24'h00FF80; end
                5'd7 : begin fill = 24'h007800; outline = 24'h03FF00; end
                5'd8 : begin fill = 24'h01F600; outline = 24'h03FF80; end
                5'd9 : begin fill = 24'h00FF00; outline = 24'h03FF80; end
                5'd10: begin fill = 24'h003B00; outline = 24'h01FF80; end
                5'd11: begin fill = 24'h003B00; outline = 24'h007F80; end
                5'd12: begin fill = 24'h003F00; outline = 24'h007F80; end
                5'd13: begin fill = 24'h003F00; outline = 24'h007F80; end
                5'd14: begin fill = 24'h003B00; outline = 24'h007FF0; end
                5'd15: begin fill = 24'h003BE0; outline = 24'h00FFF0; end
                5'd16: begin fill = 24'h007FC0; outline = 24'h03FFF0; end
                5'd17: begin fill = 24'h01E000; outline = 24'h0FFFE0; end
                5'd18: begin fill = 24'h0788C0; outline = 24'h0FFDE0; end
                5'd19: begin fill = 24'h0230C0; outline = 24'h0FFFE0; end
                5'd20: begin fill = 24'h00E1C0; outline = 24'h07FBE0; end
                5'd21: begin fill = 24'h00C040; outline = 24'h01F3E0; end
                5'd22: begin fill = 24'h000000; outline = 24'h01E0E0; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd7: case (row)   // '的' U+7684
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd2 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd3 : begin fill = 24'h000000; outline = 24'h000F00; end
                5'd4 : begin fill = 24'h000600; outline = 24'h078F80; end
                5'd5 : begin fill = 24'h030300; outline = 24'h07DF80; end
                5'd6 : begin fill = 24'h018B00; outline = 24'h07DF80; end
                5'd7 : begin fill = 24'h038E00; outline = 24'h0FFF80; end
                5'd8 : begin fill = 24'h071600; outline = 24'h1FFFE0; end
                5'd9 : begin fill = 24'h08EFC0; outline = 24'h1FFFF0; end
                5'd10: begin fill = 24'h09FE60; outline = 24'h1FFFF0; end
                5'd11: begin fill = 24'h0FF860; outline = 24'h1FFFF0; end
                5'd12: begin fill = 24'h0FEC60; outline = 24'h1FFFF0; end
                5'd13: begin fill = 24'h0FFEC0; outline = 24'h1FFFF0; end
                5'd14: begin fill = 24'h0F76C0; outline = 24'h1FFFE0; end
                5'd15: begin fill = 24'h07F8C0; outline = 24'h1FFFE0; end
                5'd16: begin fill = 24'h07CDC0; outline = 24'h0FFFE0; end
                5'd17: begin fill = 24'h00CF80; outline = 24'h0FFFE0; end
                5'd18: begin fill = 24'h000700; outline = 24'h01FFC0; end
                5'd19: begin fill = 24'h000000; outline = 24'h000F80; end
                5'd20: begin fill = 24'h000000; outline = 24'h000000; end
                5'd21: begin fill = 24'h000000; outline = 24'h000000; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd8: case (row)   // '假' U+5047
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd2 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd3 : begin fill = 24'h000000; outline = 24'h03FFC0; end
                5'd4 : begin fill = 24'h019D80; outline = 24'h03FFE0; end
                5'd5 : begin fill = 24'h01BFC0; outline = 24'h07FFE0; end
                5'd6 : begin fill = 24'h03FFC0; outline = 24'h07FFE0; end
                5'd7 : begin fill = 24'h03DD80; outline = 24'h0FFFE0; end
                5'd8 : begin fill = 24'h07FB80; outline = 24'h1FFFC0; end
                5'd9 : begin fill = 24'h0E7380; outline = 24'h1FFFE0; end
                5'd10: begin fill = 24'h0F67C0; outline = 24'h1FFFE0; end
                5'd11: begin fill = 24'h0F7F80; outline = 24'h1FFFE0; end
                5'd12: begin fill = 24'h037F80; outline = 24'h1FFFC0; end
                5'd13: begin fill = 24'h03E980; outline = 24'h07FFC0; end
                5'd14: begin fill = 24'h025F80; outline = 24'h07FFE0; end
                5'd15: begin fill = 24'h0273C0; outline = 24'h07FFF8; end
                5'd16: begin fill = 24'h02DFF0; outline = 24'h07FFF8; end
                5'd17: begin fill = 24'h034470; outline = 24'h07FFFC; end
                5'd18: begin fill = 24'h024018; outline = 24'h07EEFC; end
                5'd19: begin fill = 24'h000000; outline = 24'h07E03C; end
                5'd20: begin fill = 24'h000000; outline = 24'h000000; end
                5'd21: begin fill = 24'h000000; outline = 24'h000000; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd9: case (row)   // '我' U+6211
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h007800; end
                5'd2 : begin fill = 24'h003000; outline = 24'h007C00; end
                5'd3 : begin fill = 24'h001800; outline = 24'h007C00; end
                5'd4 : begin fill = 24'h003800; outline = 24'h007FE0; end
                5'd5 : begin fill = 24'h003DC0; outline = 24'h01FFE0; end
                5'd6 : begin fill = 24'h00FCC0; outline = 24'h03FFE0; end
                5'd7 : begin fill = 24'h01E400; outline = 24'h07FFE0; end
                5'd8 : begin fill = 24'h039F00; outline = 24'h0FFF80; end
                5'd9 : begin fill = 24'h04FE00; outline = 24'h0FFF80; end
                5'd10: begin fill = 24'h00F600; outline = 24'h0FFFC0; end
                5'd11: begin fill = 24'h03E780; outline = 24'h1FFFC0; end
                5'd12: begin fill = 24'h0FCF80; outline = 24'h1FFFC0; end
                5'd13: begin fill = 24'h0FFB80; outline = 24'h1FFFC0; end
                5'd14: begin fill = 24'h00E700; outline = 24'h1FFFC0; end
                5'd15: begin fill = 24'h03CF80; outline = 24'h0FFFF8; end
                5'd16: begin fill = 24'h07C090; outline = 24'h0FFFF8; end
                5'd17: begin fill = 24'h01C0D0; outline = 24'h0FE1F8; end
                5'd18: begin fill = 24'h00C070; outline = 24'h03E1F8; end
                5'd19: begin fill = 24'h004030; outline = 24'h01E0F8; end
                5'd20: begin fill = 24'h000030; outline = 24'h00E078; end
                5'd21: begin fill = 24'h000000; outline = 24'h000078; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd10: case (row)   // '靠' U+9760
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h001C00; end
                5'd2 : begin fill = 24'h000800; outline = 24'h001E00; end
                5'd3 : begin fill = 24'h000C00; outline = 24'h001F00; end
                5'd4 : begin fill = 24'h000E00; outline = 24'h01FF80; end
                5'd5 : begin fill = 24'h00DF00; outline = 24'h01FF80; end
                5'd6 : begin fill = 24'h00FC00; outline = 24'h01FFE0; end
                5'd7 : begin fill = 24'h00FFC0; outline = 24'h01FFF0; end
                5'd8 : begin fill = 24'h007FE0; outline = 24'h07FFF0; end
                5'd9 : begin fill = 24'h03F980; outline = 24'h3FFFF0; end
                5'd10: begin fill = 24'h1FFE00; outline = 24'h3FFFC0; end
                5'd11: begin fill = 24'h1C7F00; outline = 24'h3FFF80; end
                5'd12: begin fill = 24'h005E00; outline = 24'h3EFFC0; end
                5'd13: begin fill = 24'h007D80; outline = 24'h03FFC0; end
                5'd14: begin fill = 24'h01B780; outline = 24'h03FFC0; end
                5'd15: begin fill = 24'h00BD80; outline = 24'h03FFC0; end
                5'd16: begin fill = 24'h01B580; outline = 24'h03FFC0; end
                5'd17: begin fill = 24'h01F480; outline = 24'h03FFC0; end
                5'd18: begin fill = 24'h01B580; outline = 24'h03FFE0; end
                5'd19: begin fill = 24'h01BDC0; outline = 24'h03FFE0; end
                5'd20: begin fill = 24'h010400; outline = 24'h03FFE0; end
                5'd21: begin fill = 24'h000000; outline = 24'h038E00; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd11: case (row)   // '没' U+6CA1
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd2 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd3 : begin fill = 24'h000000; outline = 24'h000F00; end
                5'd4 : begin fill = 24'h000600; outline = 24'h001F80; end
                5'd5 : begin fill = 24'h000F00; outline = 24'h07FF80; end
                5'd6 : begin fill = 24'h033700; outline = 24'h07FF80; end
                5'd7 : begin fill = 24'h03B600; outline = 24'h0FFF80; end
                5'd8 : begin fill = 24'h07B700; outline = 24'h1FFF80; end
                5'd9 : begin fill = 24'h083700; outline = 24'h1FFF80; end
                5'd10: begin fill = 24'h083600; outline = 24'h1E7F80; end
                5'd11: begin fill = 24'h0C3E00; outline = 24'h1FFF00; end
                5'd12: begin fill = 24'h0CBE00; outline = 24'h1FFF00; end
                5'd13: begin fill = 24'h0DF600; outline = 24'h1FFF00; end
                5'd14: begin fill = 24'h097400; outline = 24'h1FFF00; end
                5'd15: begin fill = 24'h031C00; outline = 24'h1FFF00; end
                5'd16: begin fill = 24'h061E00; outline = 24'h1FFFC0; end
                5'd17: begin fill = 24'h0E3F80; outline = 24'h1FFFF0; end
                5'd18: begin fill = 24'h06E3E0; outline = 24'h1FFFF8; end
                5'd19: begin fill = 24'h0401F0; outline = 24'h0FF7F8; end
                5'd20: begin fill = 24'h000000; outline = 24'h0E03F8; end
                5'd21: begin fill = 24'h000000; outline = 24'h000000; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd12: case (row)   // '胖' U+80D6
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h000780; end
                5'd2 : begin fill = 24'h000300; outline = 24'h03E780; end
                5'd3 : begin fill = 24'h01C300; outline = 24'h03F7E0; end
                5'd4 : begin fill = 24'h01E3C0; outline = 24'h0FF7E0; end
                5'd5 : begin fill = 24'h0663C0; outline = 24'h0FFFE0; end
                5'd6 : begin fill = 24'h067FC0; outline = 24'h0FFFE0; end
                5'd7 : begin fill = 24'h07DF80; outline = 24'h0FFFE0; end
                5'd8 : begin fill = 24'h07EF80; outline = 24'h0FFFC0; end
                5'd9 : begin fill = 24'h07FF00; outline = 24'h0FFFC0; end
                5'd10: begin fill = 24'h07CF00; outline = 24'h0FFFE0; end
                5'd11: begin fill = 24'h07CFC0; outline = 24'h0FFFF0; end
                5'd12: begin fill = 24'h07FFE0; outline = 24'h0FFFF0; end
                5'd13: begin fill = 24'h05DF00; outline = 24'h1FFFF0; end
                5'd14: begin fill = 24'h0EC300; outline = 24'h1FFF80; end
                5'd15: begin fill = 24'h0DC300; outline = 24'h3FE780; end
                5'd16: begin fill = 24'h18C300; outline = 24'h3FE780; end
                5'd17: begin fill = 24'h004300; outline = 24'h3DE780; end
                5'd18: begin fill = 24'h000200; outline = 24'h00E780; end
                5'd19: begin fill = 24'h000200; outline = 24'h000700; end
                5'd20: begin fill = 24'h000000; outline = 24'h000700; end
                5'd21: begin fill = 24'h000000; outline = 24'h000000; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd13: case (row)   // '比' U+6BD4
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd2 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd3 : begin fill = 24'h000000; outline = 24'h007800; end
                5'd4 : begin fill = 24'h003000; outline = 24'h007C00; end
                5'd5 : begin fill = 24'h003800; outline = 24'h007C00; end
                5'd6 : begin fill = 24'h001800; outline = 24'h007F80; end
                5'd7 : begin fill = 24'h001B00; outline = 24'h1C3FC0; end
                5'd8 : begin fill = 24'h081B80; outline = 24'h1FFFC0; end
                5'd9 : begin fill = 24'h0DDF80; outline = 24'h1FFFC0; end
                5'd10: begin fill = 24'h0FFE00; outline = 24'h1FFFC0; end
                5'd11: begin fill = 24'h0FDC00; outline = 24'h1FFF00; end
                5'd12: begin fill = 24'h0F1800; outline = 24'h1FFE70; end
                5'd13: begin fill = 24'h0C5820; outline = 24'h1FFC70; end
                5'd14: begin fill = 24'h0FD020; outline = 24'h1FFCF0; end
                5'd15: begin fill = 24'h0F9860; outline = 24'h1FFFF8; end
                5'd16: begin fill = 24'h0F1FF0; outline = 24'h1FFFF8; end
                5'd17: begin fill = 24'h0E0FE0; outline = 24'h1FBFF8; end
                5'd18: begin fill = 24'h000000; outline = 24'h1F1FF0; end
                5'd19: begin fill = 24'h000000; outline = 24'h000000; end
                5'd20: begin fill = 24'h000000; outline = 24'h000000; end
                5'd21: begin fill = 24'h000000; outline = 24'h000000; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd14: case (row)   // '以' U+4EE5
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd2 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd3 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd4 : begin fill = 24'h000000; outline = 24'h000700; end
                5'd5 : begin fill = 24'h000200; outline = 24'h000780; end
                5'd6 : begin fill = 24'h000300; outline = 24'h0007C0; end
                5'd7 : begin fill = 24'h000380; outline = 24'h0007C0; end
                5'd8 : begin fill = 24'h000380; outline = 24'h0007C0; end
                5'd9 : begin fill = 24'h000300; outline = 24'h0007C0; end
                5'd10: begin fill = 24'h000300; outline = 24'h03FF80; end
                5'd11: begin fill = 24'h01E600; outline = 24'h1FFF80; end
                5'd12: begin fill = 24'h0EE600; outline = 24'h1FFFC0; end
                5'd13: begin fill = 24'h0EE780; outline = 24'h1FFFE0; end
                5'd14: begin fill = 24'h0E43C0; outline = 24'h1FFFF0; end
                5'd15: begin fill = 24'h0C01E0; outline = 24'h1FEFF0; end
                5'd16: begin fill = 24'h0007C0; outline = 24'h1E1FF0; end
                5'd17: begin fill = 24'h000E00; outline = 24'h001FE0; end
                5'd18: begin fill = 24'h000000; outline = 24'h001F00; end
                5'd19: begin fill = 24'h000000; outline = 24'h000000; end
                5'd20: begin fill = 24'h000000; outline = 24'h000000; end
                5'd21: begin fill = 24'h000000; outline = 24'h000000; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd15: case (row)   // '前' U+524D
                5'd0 : begin fill = 24'h000000; outline = 24'h000700; end
                5'd1 : begin fill = 24'h000200; outline = 24'h000780; end
                5'd2 : begin fill = 24'h000300; outline = 24'h00FF80; end
                5'd3 : begin fill = 24'h007B00; outline = 24'h00FF80; end
                5'd4 : begin fill = 24'h007F00; outline = 24'h00FF80; end
                5'd5 : begin fill = 24'h007E00; outline = 24'h00FFF0; end
                5'd6 : begin fill = 24'h003FE0; outline = 24'h00FFF0; end
                5'd7 : begin fill = 24'h007FE0; outline = 24'h03FFF0; end
                5'd8 : begin fill = 24'h01FF80; outline = 24'h1FFFF0; end
                5'd9 : begin fill = 24'h0FF380; outline = 24'h3FFFC0; end
                5'd10: begin fill = 24'h1E7F80; outline = 24'h7FFFC0; end
                5'd11: begin fill = 24'h389F80; outline = 24'h7FFFC0; end
                5'd12: begin fill = 24'h00FF80; outline = 24'h7FFFC0; end
                5'd13: begin fill = 24'h01FF80; outline = 24'h03FFC0; end
                5'd14: begin fill = 24'h01FE80; outline = 24'h03FFC0; end
                5'd15: begin fill = 24'h01FF80; outline = 24'h03FFC0; end
                5'd16: begin fill = 24'h015980; outline = 24'h03FFC0; end
                5'd17: begin fill = 24'h013180; outline = 24'h03FFC0; end
                5'd18: begin fill = 24'h003180; outline = 24'h03FBC0; end
                5'd19: begin fill = 24'h002180; outline = 24'h007BC0; end
                5'd20: begin fill = 24'h000100; outline = 24'h0073C0; end
                5'd21: begin fill = 24'h000100; outline = 24'h000380; end
                5'd22: begin fill = 24'h000000; outline = 24'h000380; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd16: case (row)   // '瘦' U+7626
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h007000; end
                5'd2 : begin fill = 24'h002000; outline = 24'h007C00; end
                5'd3 : begin fill = 24'h003800; outline = 24'h007FC0; end
                5'd4 : begin fill = 24'h001F80; outline = 24'h00FFC0; end
                5'd5 : begin fill = 24'h007F80; outline = 24'h03FFC0; end
                5'd6 : begin fill = 24'h01C000; outline = 24'h0FFFC0; end
                5'd7 : begin fill = 24'h07DF80; outline = 24'h0FFFE0; end
                5'd8 : begin fill = 24'h00BDC0; outline = 24'h0FFFE0; end
                5'd9 : begin fill = 24'h01EF80; outline = 24'h1FFFE0; end
                5'd10: begin fill = 24'h0FFF80; outline = 24'h1FFFC0; end
                5'd11: begin fill = 24'h0FBD80; outline = 24'h1FFFC0; end
                5'd12: begin fill = 24'h0D3F00; outline = 24'h1FFFC0; end
                5'd13: begin fill = 24'h0F3E00; outline = 24'h1FFF80; end
                5'd14: begin fill = 24'h0F1F00; outline = 24'h3FFF80; end
                5'd15: begin fill = 24'h1B7A00; outline = 24'h3FFF80; end
                5'd16: begin fill = 24'h1B0E00; outline = 24'h3FFFC0; end
                5'd17: begin fill = 24'h020F80; outline = 24'h3FFFF8; end
                5'd18: begin fill = 24'h067BF0; outline = 24'h1FFFFC; end
                5'd19: begin fill = 24'h0C00F8; outline = 24'h1FFFFC; end
                5'd20: begin fill = 24'h080000; outline = 24'h1E01FC; end
                5'd21: begin fill = 24'h000000; outline = 24'h1C0000; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd17: case (row)   // '再' U+518D
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h000F80; end
                5'd2 : begin fill = 24'h000700; outline = 24'h007FC0; end
                5'd3 : begin fill = 24'h003F80; outline = 24'h01FFC0; end
                5'd4 : begin fill = 24'h00FE00; outline = 24'h0FFFC0; end
                5'd5 : begin fill = 24'h07FC00; outline = 24'h0FFF00; end
                5'd6 : begin fill = 24'h03B800; outline = 24'h0FFE00; end
                5'd7 : begin fill = 24'h013C00; outline = 24'h07FF00; end
                5'd8 : begin fill = 24'h007E00; outline = 24'h03FF80; end
                5'd9 : begin fill = 24'h007B00; outline = 24'h01FF80; end
                5'd10: begin fill = 24'h00DF00; outline = 24'h01FF80; end
                5'd11: begin fill = 24'h00FF00; outline = 24'h03FF80; end
                5'd12: begin fill = 24'h01FF00; outline = 24'h03FF80; end
                5'd13: begin fill = 24'h00DF00; outline = 24'h03FFF0; end
                5'd14: begin fill = 24'h01FFE0; outline = 24'h0FFFF0; end
                5'd15: begin fill = 24'h07FFE0; outline = 24'h3FFFF0; end
                5'd16: begin fill = 24'h1FE320; outline = 24'h3FFFF0; end
                5'd17: begin fill = 24'h0FCB00; outline = 24'h3FFFF0; end
                5'd18: begin fill = 24'h008700; outline = 24'h1FFF80; end
                5'd19: begin fill = 24'h008300; outline = 24'h01CF80; end
                5'd20: begin fill = 24'h000300; outline = 24'h01C780; end
                5'd21: begin fill = 24'h000000; outline = 24'h000780; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd18: case (row)   // '这' U+8FD9
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd2 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd3 : begin fill = 24'h000000; outline = 24'h003F00; end
                5'd4 : begin fill = 24'h001E00; outline = 24'h003F00; end
                5'd5 : begin fill = 24'h000E00; outline = 24'h0E3F00; end
                5'd6 : begin fill = 24'h040C00; outline = 24'h0FBF80; end
                5'd7 : begin fill = 24'h071300; outline = 24'h0FBFC0; end
                5'd8 : begin fill = 24'h060F80; outline = 24'h1FFFC0; end
                5'd9 : begin fill = 24'h083E00; outline = 24'h1FFFC0; end
                5'd10: begin fill = 24'h007E00; outline = 24'h1EFF00; end
                5'd11: begin fill = 24'h0C7600; outline = 24'h3FFF00; end
                5'd12: begin fill = 24'h1E0600; outline = 24'h3FFF00; end
                5'd13: begin fill = 24'h1E7E00; outline = 24'h3FFF80; end
                5'd14: begin fill = 24'h041F00; outline = 24'h3FFFC0; end
                5'd15: begin fill = 24'h04FF80; outline = 24'h0FFFC0; end
                5'd16: begin fill = 24'h027380; outline = 24'h0FFFC0; end
                5'd17: begin fill = 24'h070080; outline = 24'h1FFFC0; end
                5'd18: begin fill = 24'h0FF000; outline = 24'h1FFFFC; end
                5'd19: begin fill = 24'h003FF8; outline = 24'h1FFFFC; end
                5'd20: begin fill = 24'h0007E0; outline = 24'h007FFC; end
                5'd21: begin fill = 24'h000000; outline = 24'h000FF0; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd19: case (row)   // '样' U+6837
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h0001C0; end
                5'd2 : begin fill = 24'h000080; outline = 24'h01C1E0; end
                5'd3 : begin fill = 24'h0080C0; outline = 24'h01E7E0; end
                5'd4 : begin fill = 24'h00C3C0; outline = 24'h01FFE0; end
                5'd5 : begin fill = 24'h00CD80; outline = 24'h01FFE0; end
                5'd6 : begin fill = 24'h00CF80; outline = 24'h07FFC0; end
                5'd7 : begin fill = 24'h03EF80; outline = 24'h1FFFC0; end
                5'd8 : begin fill = 24'h0FCF80; outline = 24'h7FFFC0; end
                5'd9 : begin fill = 24'h3FC780; outline = 24'h7FFFC0; end
                5'd10: begin fill = 24'h1FCF80; outline = 24'h7FFFC0; end
                5'd11: begin fill = 24'h018F00; outline = 24'h3FFFF0; end
                5'd12: begin fill = 24'h0787E0; outline = 24'h0FDFF8; end
                5'd13: begin fill = 24'h078FF0; outline = 24'h0FFFF8; end
                5'd14: begin fill = 24'h03BF00; outline = 24'h0FFFF8; end
                5'd15: begin fill = 24'h019300; outline = 24'h07FF80; end
                5'd16: begin fill = 24'h008300; outline = 24'h03FF80; end
                5'd17: begin fill = 24'h008100; outline = 24'h01C780; end
                5'd18: begin fill = 24'h000100; outline = 24'h01C380; end
                5'd19: begin fill = 24'h000100; outline = 24'h000380; end
                5'd20: begin fill = 24'h000100; outline = 24'h000380; end
                5'd21: begin fill = 24'h000000; outline = 24'h000380; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd20: case (row)   // '说' U+8BF4
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd2 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd3 : begin fill = 24'h000000; outline = 24'h0003C0; end
                5'd4 : begin fill = 24'h000180; outline = 24'h078FC0; end
                5'd5 : begin fill = 24'h030580; outline = 24'h07FFC0; end
                5'd6 : begin fill = 24'h039B80; outline = 24'h07FFC0; end
                5'd7 : begin fill = 24'h03DB00; outline = 24'h0FFFC0; end
                5'd8 : begin fill = 24'h071F00; outline = 24'h3FFFC0; end
                5'd9 : begin fill = 24'h181F80; outline = 24'h7FFFC0; end
                5'd10: begin fill = 24'h273D80; outline = 24'h7FFFC0; end
                5'd11: begin fill = 24'h2F3300; outline = 24'h7FFFC0; end
                5'd12: begin fill = 24'h3F3700; outline = 24'h7FFF80; end
                5'd13: begin fill = 24'h3E3E00; outline = 24'h7FFF80; end
                5'd14: begin fill = 24'h067E00; outline = 24'h7FFF80; end
                5'd15: begin fill = 24'h067F00; outline = 24'h0FFF80; end
                5'd16: begin fill = 24'h073600; outline = 24'h0FFF80; end
                5'd17: begin fill = 24'h076600; outline = 24'h0FFF1C; end
                5'd18: begin fill = 24'h064408; outline = 24'h0FFF3C; end
                5'd19: begin fill = 24'h068418; outline = 24'h0FEFFC; end
                5'd20: begin fill = 24'h0203F8; outline = 24'h0FCFFC; end
                5'd21: begin fill = 24'h000000; outline = 24'h0707FC; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd21: case (row)   // '受' U+53D7
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h001E00; end
                5'd2 : begin fill = 24'h000C00; outline = 24'h003F00; end
                5'd3 : begin fill = 24'h001E00; outline = 24'h007F00; end
                5'd4 : begin fill = 24'h003800; outline = 24'h01FF00; end
                5'd5 : begin fill = 24'h00CE00; outline = 24'h01FF00; end
                5'd6 : begin fill = 24'h001200; outline = 24'h01FF00; end
                5'd7 : begin fill = 24'h00B600; outline = 24'h03FF00; end
                5'd8 : begin fill = 24'h019400; outline = 24'h03FFE0; end
                5'd9 : begin fill = 24'h018FC0; outline = 24'h03FFE0; end
                5'd10: begin fill = 24'h00F9C0; outline = 24'h03FFE0; end
                5'd11: begin fill = 24'h01E380; outline = 24'h0FFFE0; end
                5'd12: begin fill = 24'h071E00; outline = 24'h0FFFC0; end
                5'd13: begin fill = 24'h047C00; outline = 24'h1FFF00; end
                5'd14: begin fill = 24'h0DEC00; outline = 24'h1FFE00; end
                5'd15: begin fill = 24'h0C7C00; outline = 24'h1FFE00; end
                5'd16: begin fill = 24'h083C00; outline = 24'h1EFE00; end
                5'd17: begin fill = 24'h003C00; outline = 24'h1DFF80; end
                5'd18: begin fill = 24'h00FF00; outline = 24'h07FFE0; end
                5'd19: begin fill = 24'h03C3C0; outline = 24'h07FFF8; end
                5'd20: begin fill = 24'h0001F0; outline = 24'h07E7F8; end
                5'd21: begin fill = 24'h000070; outline = 24'h0003F8; end
                5'd22: begin fill = 24'h000000; outline = 24'h0000F8; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd22: case (row)   // '不' U+4E0D
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd2 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd3 : begin fill = 24'h000000; outline = 24'h003E00; end
                5'd4 : begin fill = 24'h001C00; outline = 24'h00FF00; end
                5'd5 : begin fill = 24'h007E00; outline = 24'h07FF00; end
                5'd6 : begin fill = 24'h03FE00; outline = 24'h07FF00; end
                5'd7 : begin fill = 24'h01FC00; outline = 24'h07FF00; end
                5'd8 : begin fill = 24'h003800; outline = 24'h03FE00; end
                5'd9 : begin fill = 24'h007000; outline = 24'h07FC00; end
                5'd10: begin fill = 24'h03F000; outline = 24'h07F800; end
                5'd11: begin fill = 24'h01E000; outline = 24'h07F800; end
                5'd12: begin fill = 24'h01E000; outline = 24'h07F000; end
                5'd13: begin fill = 24'h03E000; outline = 24'h0FFFE0; end
                5'd14: begin fill = 24'h077FC0; outline = 24'h1FFFF0; end
                5'd15: begin fill = 24'h0E67E0; outline = 24'h1FFFF0; end
                5'd16: begin fill = 24'h0C60E0; outline = 24'h1FFFF0; end
                5'd17: begin fill = 24'h006000; outline = 24'h1EF1F0; end
                5'd18: begin fill = 24'h006000; outline = 24'h00F000; end
                5'd19: begin fill = 24'h000000; outline = 24'h00F000; end
                5'd20: begin fill = 24'h000000; outline = 24'h000000; end
                5'd21: begin fill = 24'h000000; outline = 24'h000000; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd23: case (row)   // '嘞' U+561E
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd2 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd3 : begin fill = 24'h000000; outline = 24'h000F00; end
                5'd4 : begin fill = 24'h000600; outline = 24'h007F00; end
                5'd5 : begin fill = 24'h003600; outline = 24'h007F00; end
                5'd6 : begin fill = 24'h003E00; outline = 24'h07FF00; end
                5'd7 : begin fill = 24'h03FC00; outline = 24'h3FFFE0; end
                5'd8 : begin fill = 24'h17FCC0; outline = 24'h3FFFF0; end
                5'd9 : begin fill = 24'h1DBC60; outline = 24'h3FFFF8; end
                5'd10: begin fill = 24'h0FDEF0; outline = 24'h3FFFFC; end
                5'd11: begin fill = 24'h0FFFF8; outline = 24'h1FFFFC; end
                5'd12: begin fill = 24'h0C5CD0; outline = 24'h1FFFFC; end
                5'd13: begin fill = 24'h0078B0; outline = 24'h1EFFF8; end
                5'd14: begin fill = 24'h007FB0; outline = 24'h00FFF8; end
                5'd15: begin fill = 24'h007930; outline = 24'h03FFF8; end
                5'd16: begin fill = 24'h01D320; outline = 24'h03FFF8; end
                5'd17: begin fill = 24'h009AE0; outline = 24'h03FFF0; end
                5'd18: begin fill = 24'h001CC0; outline = 24'h01FFF0; end
                5'd19: begin fill = 24'h000000; outline = 24'h003FE0; end
                5'd20: begin fill = 24'h000000; outline = 24'h000000; end
                5'd21: begin fill = 24'h000000; outline = 24'h000000; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd24: case (row)   // '懂' U+61C2
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd2 : begin fill = 24'h000000; outline = 24'h000380; end
                5'd3 : begin fill = 24'h000100; outline = 24'h0777C0; end
                5'd4 : begin fill = 24'h022380; outline = 24'h07FFC0; end
                5'd5 : begin fill = 24'h031F80; outline = 24'h07FFC0; end
                5'd6 : begin fill = 24'h033B00; outline = 24'h07FFE0; end
                5'd7 : begin fill = 24'h033F40; outline = 24'h07FFE0; end
                5'd8 : begin fill = 24'h031FC0; outline = 24'h3FFFE0; end
                5'd9 : begin fill = 24'h1B3F00; outline = 24'h3FFFE0; end
                5'd10: begin fill = 24'h1F76C0; outline = 24'h3FFFE0; end
                5'd11: begin fill = 24'h1FDEC0; outline = 24'h7FFFE0; end
                5'd12: begin fill = 24'h3E2F80; outline = 24'h7FFFE0; end
                5'd13: begin fill = 24'h1A3F80; outline = 24'h7FFFC0; end
                5'd14: begin fill = 24'h031F00; outline = 24'h3FFFC0; end
                5'd15: begin fill = 24'h031F00; outline = 24'h07BF80; end
                5'd16: begin fill = 24'h030F00; outline = 24'h07BFC0; end
                5'd17: begin fill = 24'h030F80; outline = 24'h079FE0; end
                5'd18: begin fill = 24'h030FC0; outline = 24'h07BFE0; end
                5'd19: begin fill = 24'h011C40; outline = 24'h07BFE0; end
                5'd20: begin fill = 24'h000000; outline = 24'h03BEE0; end
                5'd21: begin fill = 24'h000000; outline = 24'h000000; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd25: case (row)   // '你' U+4F60
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd2 : begin fill = 24'h000000; outline = 24'h003800; end
                5'd3 : begin fill = 24'h001000; outline = 24'h003C00; end
                5'd4 : begin fill = 24'h001800; outline = 24'h073E00; end
                5'd5 : begin fill = 24'h020C00; outline = 24'h07BE00; end
                5'd6 : begin fill = 24'h031C00; outline = 24'h07FFE0; end
                5'd7 : begin fill = 24'h039FC0; outline = 24'h07FFE0; end
                5'd8 : begin fill = 24'h03BFC0; outline = 24'h0FFFE0; end
                5'd9 : begin fill = 24'h073FC0; outline = 24'h0FFFE0; end
                5'd10: begin fill = 24'h067B80; outline = 24'h1FFFE0; end
                5'd11: begin fill = 24'h0E7E00; outline = 24'h3FFFC0; end
                5'd12: begin fill = 24'h1E2C00; outline = 24'h3FFFC0; end
                5'd13: begin fill = 24'h0E0E80; outline = 24'h3F7FF0; end
                5'd14: begin fill = 24'h061EE0; outline = 24'h1FFFF0; end
                5'd15: begin fill = 24'h06F6E0; outline = 24'h0FFFF0; end
                5'd16: begin fill = 24'h06EEE0; outline = 24'h0FFFF0; end
                5'd17: begin fill = 24'h06DE00; outline = 24'h0FFFF0; end
                5'd18: begin fill = 24'h020C00; outline = 24'h0FFF00; end
                5'd19: begin fill = 24'h000400; outline = 24'h071E00; end
                5'd20: begin fill = 24'h000000; outline = 24'h000E00; end
                5'd21: begin fill = 24'h000000; outline = 24'h000000; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd26: case (row)   // '意' U+610F
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h007C00; end
                5'd2 : begin fill = 24'h003800; outline = 24'h007E00; end
                5'd3 : begin fill = 24'h001C00; outline = 24'h007F00; end
                5'd4 : begin fill = 24'h003E00; outline = 24'h01FF00; end
                5'd5 : begin fill = 24'h00FC00; outline = 24'h01FF00; end
                5'd6 : begin fill = 24'h007C00; outline = 24'h01FF00; end
                5'd7 : begin fill = 24'h00FE00; outline = 24'h01FFE0; end
                5'd8 : begin fill = 24'h00FFC0; outline = 24'h03FFE0; end
                5'd9 : begin fill = 24'h01FC00; outline = 24'h3FFFE0; end
                5'd10: begin fill = 24'h1FBE00; outline = 24'h3FFF00; end
                5'd11: begin fill = 24'h19FE00; outline = 24'h3FFF00; end
                5'd12: begin fill = 24'h01FE00; outline = 24'h3FFF00; end
                5'd13: begin fill = 24'h00B600; outline = 24'h03FF00; end
                5'd14: begin fill = 24'h00FC00; outline = 24'h01FFE0; end
                5'd15: begin fill = 24'h00D1C0; outline = 24'h03FFF0; end
                5'd16: begin fill = 24'h01DEE0; outline = 24'h07FFF0; end
                5'd17: begin fill = 24'h034E60; outline = 24'h07FFF0; end
                5'd18: begin fill = 24'h036300; outline = 24'h07FFF0; end
                5'd19: begin fill = 24'h033F80; outline = 24'h07FFC0; end
                5'd20: begin fill = 24'h020F80; outline = 24'h07FFC0; end
                5'd21: begin fill = 24'h000000; outline = 24'h071FC0; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            8'd27: case (row)   // '思' U+601D
                5'd0 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd1 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd2 : begin fill = 24'h000000; outline = 24'h000000; end
                5'd3 : begin fill = 24'h000000; outline = 24'h001F80; end
                5'd4 : begin fill = 24'h000F00; outline = 24'h00FFE0; end
                5'd5 : begin fill = 24'h0079C0; outline = 24'h07FFE0; end
                5'd6 : begin fill = 24'h03F9C0; outline = 24'h07FFE0; end
                5'd7 : begin fill = 24'h039F80; outline = 24'h07FFE0; end
                5'd8 : begin fill = 24'h01FB80; outline = 24'h07FFC0; end
                5'd9 : begin fill = 24'h01F300; outline = 24'h03FFC0; end
                5'd10: begin fill = 24'h01BF00; outline = 24'h03FF80; end
                5'd11: begin fill = 24'h01FE00; outline = 24'h03FF80; end
                5'd12: begin fill = 24'h01C000; outline = 24'h03FFF8; end
                5'd13: begin fill = 24'h001AF0; outline = 24'h07FFF8; end
                5'd14: begin fill = 24'h029E70; outline = 24'h07FFF8; end
                5'd15: begin fill = 24'h03CD30; outline = 24'h0FFFF8; end
                5'd16: begin fill = 24'h064480; outline = 24'h0FFFF8; end
                5'd17: begin fill = 24'h0630E0; outline = 24'h0FFFF8; end
                5'd18: begin fill = 24'h021FF0; outline = 24'h0F7FF8; end
                5'd19: begin fill = 24'h0007E0; outline = 24'h073FF8; end
                5'd20: begin fill = 24'h000000; outline = 24'h000FF0; end
                5'd21: begin fill = 24'h000000; outline = 24'h000000; end
                5'd22: begin fill = 24'h000000; outline = 24'h000000; end
                5'd23: begin fill = 24'h000000; outline = 24'h000000; end
                default: begin fill = 24'd0; outline = 24'd0; end
            endcase
            default: begin fill = 24'd0; outline = 24'd0; end
        endcase
    end

endmodule


//------------------------------------------------------------------ 文本表
module subtitle_text_rom (
    input  wire [2:0]  line,           // 行号 0..7（每页 2 行）
    input  wire [9:0]  x,              // 行内像素 x（0..639）
    output reg  [7:0]  glyph,          // 0 = 空白/无字符
    output reg  [4:0]  col             // 字模内列号 0..31（汉字步进 32）
);

    // 每行最多 24 个字符的区间比较：x 落在哪个 [x0, x0+步进) 就取那个字。
    always @(*) begin
        glyph = 8'd0;
        col   = 5'd0;
        case (line)
            3'd0: begin
                if (x >= 10'd232 && x < 10'd264) begin
                    glyph = 8'd1;
                    col   = x - 10'd232;
                end
                else if (x >= 10'd268 && x < 10'd300) begin
                    glyph = 8'd2;
                    col   = x - 10'd268;
                end
                else if (x >= 10'd304 && x < 10'd336) begin
                    glyph = 8'd3;
                    col   = x - 10'd304;
                end
                else if (x >= 10'd340 && x < 10'd372) begin
                    glyph = 8'd4;
                    col   = x - 10'd340;
                end
                else if (x >= 10'd376 && x < 10'd408) begin
                    glyph = 8'd5;
                    col   = x - 10'd376;
                end
            end
            3'd1: begin
                if (x >= 10'd250 && x < 10'd282) begin
                    glyph = 8'd6;
                    col   = x - 10'd250;
                end
                else if (x >= 10'd286 && x < 10'd318) begin
                    glyph = 8'd7;
                    col   = x - 10'd286;
                end
                else if (x >= 10'd322 && x < 10'd354) begin
                    glyph = 8'd8;
                    col   = x - 10'd322;
                end
                else if (x >= 10'd358 && x < 10'd390) begin
                    glyph = 8'd7;
                    col   = x - 10'd358;
                end
            end
            3'd2: begin
                if (x >= 10'd214 && x < 10'd246) begin
                    glyph = 8'd9;
                    col   = x - 10'd214;
                end
                else if (x >= 10'd250 && x < 10'd282) begin
                    glyph = 8'd10;
                    col   = x - 10'd250;
                end
                else if (x >= 10'd286 && x < 10'd318) begin
                    glyph = 8'd6;
                    col   = x - 10'd286;
                end
                else if (x >= 10'd322 && x < 10'd354) begin
                    glyph = 8'd3;
                    col   = x - 10'd322;
                end
                else if (x >= 10'd358 && x < 10'd390) begin
                    glyph = 8'd4;
                    col   = x - 10'd358;
                end
                else if (x >= 10'd394 && x < 10'd426) begin
                    glyph = 8'd5;
                    col   = x - 10'd394;
                end
            end
            3'd3: begin
                if (x >= 10'd250 && x < 10'd282) begin
                    glyph = 8'd11;
                    col   = x - 10'd250;
                end
                else if (x >= 10'd286 && x < 10'd318) begin
                    glyph = 8'd12;
                    col   = x - 10'd286;
                end
                else if (x >= 10'd322 && x < 10'd354) begin
                    glyph = 8'd9;
                    col   = x - 10'd322;
                end
                else if (x >= 10'd358 && x < 10'd390) begin
                    glyph = 8'd10;
                    col   = x - 10'd358;
                end
            end
            3'd4: begin
                if (x >= 10'd196 && x < 10'd228) begin
                    glyph = 8'd9;
                    col   = x - 10'd196;
                end
                else if (x >= 10'd232 && x < 10'd264) begin
                    glyph = 8'd6;
                    col   = x - 10'd232;
                end
                else if (x >= 10'd268 && x < 10'd300) begin
                    glyph = 8'd13;
                    col   = x - 10'd268;
                end
                else if (x >= 10'd304 && x < 10'd336) begin
                    glyph = 8'd14;
                    col   = x - 10'd304;
                end
                else if (x >= 10'd340 && x < 10'd372) begin
                    glyph = 8'd15;
                    col   = x - 10'd340;
                end
                else if (x >= 10'd376 && x < 10'd408) begin
                    glyph = 8'd16;
                    col   = x - 10'd376;
                end
                else if (x >= 10'd412 && x < 10'd444) begin
                    glyph = 8'd5;
                    col   = x - 10'd412;
                end
            end
            3'd5: begin
                if (x >= 10'd142 && x < 10'd174) begin
                    glyph = 8'd17;
                    col   = x - 10'd142;
                end
                else if (x >= 10'd178 && x < 10'd210) begin
                    glyph = 8'd18;
                    col   = x - 10'd178;
                end
                else if (x >= 10'd214 && x < 10'd246) begin
                    glyph = 8'd19;
                    col   = x - 10'd214;
                end
                else if (x >= 10'd250 && x < 10'd282) begin
                    glyph = 8'd20;
                    col   = x - 10'd250;
                end
                else if (x >= 10'd286 && x < 10'd318) begin
                    glyph = 8'd9;
                    col   = x - 10'd286;
                end
                else if (x >= 10'd322 && x < 10'd354) begin
                    glyph = 8'd6;
                    col   = x - 10'd322;
                end
                else if (x >= 10'd358 && x < 10'd390) begin
                    glyph = 8'd21;
                    col   = x - 10'd358;
                end
                else if (x >= 10'd394 && x < 10'd426) begin
                    glyph = 8'd22;
                    col   = x - 10'd394;
                end
                else if (x >= 10'd430 && x < 10'd462) begin
                    glyph = 8'd5;
                    col   = x - 10'd430;
                end
                else if (x >= 10'd466 && x < 10'd498) begin
                    glyph = 8'd23;
                    col   = x - 10'd466;
                end
            end
            3'd6: begin
                if (x >= 10'd286 && x < 10'd318) begin
                    glyph = 8'd24;
                    col   = x - 10'd286;
                end
                else if (x >= 10'd322 && x < 10'd354) begin
                    glyph = 8'd25;
                    col   = x - 10'd322;
                end
            end
            3'd7: begin
                if (x >= 10'd286 && x < 10'd318) begin
                    glyph = 8'd26;
                    col   = x - 10'd286;
                end
                else if (x >= 10'd322 && x < 10'd354) begin
                    glyph = 8'd27;
                    col   = x - 10'd322;
                end
            end
            default: begin glyph = 8'd0; col = 5'd0; end
        endcase
    end

endmodule

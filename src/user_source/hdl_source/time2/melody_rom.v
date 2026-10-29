// -----------------------------------------------------------------------------
// melody_rom.v  —— 由 tools/gen_melody_rom.py 自动生成，请勿手改
// 曲目：《东南苦行山》（殷正洋）/ 简谱旋律，音符 142 个
// 速度：72 BPM    采样率：48000 Hz    一个循环约 108.7 秒
// 半音基准：0 = E2（82.41Hz），最大 63
// 改法：改脚本里的简谱 / --bpm / --octave，重跑脚本生成，再重新综合
// -----------------------------------------------------------------------------

module melody_rom #(
    parameter integer NOTE_NUM = 142
) (
    input  wire [11:0]  I_idx,      // 音符序号
    output reg  [5:0]   O_semi,     // 半音序号（0 = A3）
    output reg  [3:0]   O_dur_q2    // 时值，单位 1/2 拍（1..8）
);

    always @(*) begin
        O_semi   = 6'd0;
        O_dur_q2 = 4'd2;
        case (I_idx)
            12'd0: begin O_semi = 6'd17; O_dur_q2 = 4'd2; end
            12'd1: begin O_semi = 6'd24; O_dur_q2 = 4'd2; end
            12'd2: begin O_semi = 6'd22; O_dur_q2 = 4'd1; end
            12'd3: begin O_semi = 6'd27; O_dur_q2 = 4'd1; end
            12'd4: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd5: begin O_semi = 6'd22; O_dur_q2 = 4'd1; end
            12'd6: begin O_semi = 6'd24; O_dur_q2 = 4'd2; end
            12'd7: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd8: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd9: begin O_semi = 6'd22; O_dur_q2 = 4'd4; end
            12'd10: begin O_semi = 6'd20; O_dur_q2 = 4'd2; end
            12'd11: begin O_semi = 6'd17; O_dur_q2 = 4'd2; end
            12'd12: begin O_semi = 6'd15; O_dur_q2 = 4'd2; end
            12'd13: begin O_semi = 6'd12; O_dur_q2 = 4'd1; end
            12'd14: begin O_semi = 6'd15; O_dur_q2 = 4'd1; end
            12'd15: begin O_semi = 6'd17; O_dur_q2 = 4'd8; end
            12'd16: begin O_semi = 6'd20; O_dur_q2 = 4'd2; end
            12'd17: begin O_semi = 6'd17; O_dur_q2 = 4'd2; end
            12'd18: begin O_semi = 6'd22; O_dur_q2 = 4'd1; end
            12'd19: begin O_semi = 6'd20; O_dur_q2 = 4'd1; end
            12'd20: begin O_semi = 6'd22; O_dur_q2 = 4'd1; end
            12'd21: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd22: begin O_semi = 6'd27; O_dur_q2 = 4'd2; end
            12'd23: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd24: begin O_semi = 6'd22; O_dur_q2 = 4'd1; end
            12'd25: begin O_semi = 6'd24; O_dur_q2 = 4'd2; end
            12'd26: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd27: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd28: begin O_semi = 6'd22; O_dur_q2 = 4'd2; end
            12'd29: begin O_semi = 6'd20; O_dur_q2 = 4'd2; end
            12'd30: begin O_semi = 6'd17; O_dur_q2 = 4'd2; end
            12'd31: begin O_semi = 6'd15; O_dur_q2 = 4'd2; end
            12'd32: begin O_semi = 6'd17; O_dur_q2 = 4'd8; end
            12'd33: begin O_semi = 6'd17; O_dur_q2 = 4'd2; end
            12'd34: begin O_semi = 6'd24; O_dur_q2 = 4'd2; end
            12'd35: begin O_semi = 6'd22; O_dur_q2 = 4'd1; end
            12'd36: begin O_semi = 6'd27; O_dur_q2 = 4'd1; end
            12'd37: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd38: begin O_semi = 6'd22; O_dur_q2 = 4'd1; end
            12'd39: begin O_semi = 6'd24; O_dur_q2 = 4'd2; end
            12'd40: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd41: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd42: begin O_semi = 6'd22; O_dur_q2 = 4'd4; end
            12'd43: begin O_semi = 6'd20; O_dur_q2 = 4'd2; end
            12'd44: begin O_semi = 6'd17; O_dur_q2 = 4'd2; end
            12'd45: begin O_semi = 6'd15; O_dur_q2 = 4'd2; end
            12'd46: begin O_semi = 6'd12; O_dur_q2 = 4'd1; end
            12'd47: begin O_semi = 6'd15; O_dur_q2 = 4'd1; end
            12'd48: begin O_semi = 6'd17; O_dur_q2 = 4'd8; end
            12'd49: begin O_semi = 6'd20; O_dur_q2 = 4'd2; end
            12'd50: begin O_semi = 6'd17; O_dur_q2 = 4'd2; end
            12'd51: begin O_semi = 6'd22; O_dur_q2 = 4'd1; end
            12'd52: begin O_semi = 6'd20; O_dur_q2 = 4'd1; end
            12'd53: begin O_semi = 6'd22; O_dur_q2 = 4'd1; end
            12'd54: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd55: begin O_semi = 6'd27; O_dur_q2 = 4'd2; end
            12'd56: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd57: begin O_semi = 6'd22; O_dur_q2 = 4'd1; end
            12'd58: begin O_semi = 6'd24; O_dur_q2 = 4'd2; end
            12'd59: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd60: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd61: begin O_semi = 6'd22; O_dur_q2 = 4'd2; end
            12'd62: begin O_semi = 6'd20; O_dur_q2 = 4'd2; end
            12'd63: begin O_semi = 6'd17; O_dur_q2 = 4'd2; end
            12'd64: begin O_semi = 6'd15; O_dur_q2 = 4'd2; end
            12'd65: begin O_semi = 6'd17; O_dur_q2 = 4'd8; end
            12'd66: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd67: begin O_semi = 6'd27; O_dur_q2 = 4'd1; end
            12'd68: begin O_semi = 6'd29; O_dur_q2 = 4'd2; end
            12'd69: begin O_semi = 6'd29; O_dur_q2 = 4'd1; end
            12'd70: begin O_semi = 6'd29; O_dur_q2 = 4'd1; end
            12'd71: begin O_semi = 6'd27; O_dur_q2 = 4'd2; end
            12'd72: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd73: begin O_semi = 6'd22; O_dur_q2 = 4'd1; end
            12'd74: begin O_semi = 6'd24; O_dur_q2 = 4'd2; end
            12'd75: begin O_semi = 6'd27; O_dur_q2 = 4'd1; end
            12'd76: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd77: begin O_semi = 6'd22; O_dur_q2 = 4'd4; end
            12'd78: begin O_semi = 6'd24; O_dur_q2 = 4'd2; end
            12'd79: begin O_semi = 6'd24; O_dur_q2 = 4'd2; end
            12'd80: begin O_semi = 6'd22; O_dur_q2 = 4'd1; end
            12'd81: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd82: begin O_semi = 6'd22; O_dur_q2 = 4'd1; end
            12'd83: begin O_semi = 6'd20; O_dur_q2 = 4'd1; end
            12'd84: begin O_semi = 6'd17; O_dur_q2 = 4'd2; end
            12'd85: begin O_semi = 6'd19; O_dur_q2 = 4'd1; end
            12'd86: begin O_semi = 6'd15; O_dur_q2 = 4'd1; end
            12'd87: begin O_semi = 6'd17; O_dur_q2 = 4'd3; end
            12'd88: begin O_semi = 6'd20; O_dur_q2 = 4'd1; end
            12'd89: begin O_semi = 6'd22; O_dur_q2 = 4'd2; end
            12'd90: begin O_semi = 6'd17; O_dur_q2 = 4'd1; end
            12'd91: begin O_semi = 6'd20; O_dur_q2 = 4'd1; end
            12'd92: begin O_semi = 6'd22; O_dur_q2 = 4'd2; end
            12'd93: begin O_semi = 6'd22; O_dur_q2 = 4'd1; end
            12'd94: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd95: begin O_semi = 6'd27; O_dur_q2 = 4'd6; end
            12'd96: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd97: begin O_semi = 6'd27; O_dur_q2 = 4'd1; end
            12'd98: begin O_semi = 6'd29; O_dur_q2 = 4'd2; end
            12'd99: begin O_semi = 6'd32; O_dur_q2 = 4'd2; end
            12'd100: begin O_semi = 6'd31; O_dur_q2 = 4'd1; end
            12'd101: begin O_semi = 6'd29; O_dur_q2 = 4'd1; end
            12'd102: begin O_semi = 6'd27; O_dur_q2 = 4'd2; end
            12'd103: begin O_semi = 6'd29; O_dur_q2 = 4'd6; end
            12'd104: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd105: begin O_semi = 6'd27; O_dur_q2 = 4'd1; end
            12'd106: begin O_semi = 6'd29; O_dur_q2 = 4'd2; end
            12'd107: begin O_semi = 6'd29; O_dur_q2 = 4'd1; end
            12'd108: begin O_semi = 6'd29; O_dur_q2 = 4'd1; end
            12'd109: begin O_semi = 6'd27; O_dur_q2 = 4'd2; end
            12'd110: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd111: begin O_semi = 6'd22; O_dur_q2 = 4'd1; end
            12'd112: begin O_semi = 6'd24; O_dur_q2 = 4'd2; end
            12'd113: begin O_semi = 6'd27; O_dur_q2 = 4'd1; end
            12'd114: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd115: begin O_semi = 6'd22; O_dur_q2 = 4'd4; end
            12'd116: begin O_semi = 6'd24; O_dur_q2 = 4'd2; end
            12'd117: begin O_semi = 6'd24; O_dur_q2 = 4'd2; end
            12'd118: begin O_semi = 6'd22; O_dur_q2 = 4'd1; end
            12'd119: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd120: begin O_semi = 6'd22; O_dur_q2 = 4'd1; end
            12'd121: begin O_semi = 6'd20; O_dur_q2 = 4'd1; end
            12'd122: begin O_semi = 6'd17; O_dur_q2 = 4'd2; end
            12'd123: begin O_semi = 6'd19; O_dur_q2 = 4'd1; end
            12'd124: begin O_semi = 6'd15; O_dur_q2 = 4'd1; end
            12'd125: begin O_semi = 6'd17; O_dur_q2 = 4'd3; end
            12'd126: begin O_semi = 6'd20; O_dur_q2 = 4'd1; end
            12'd127: begin O_semi = 6'd22; O_dur_q2 = 4'd2; end
            12'd128: begin O_semi = 6'd17; O_dur_q2 = 4'd1; end
            12'd129: begin O_semi = 6'd20; O_dur_q2 = 4'd1; end
            12'd130: begin O_semi = 6'd22; O_dur_q2 = 4'd2; end
            12'd131: begin O_semi = 6'd22; O_dur_q2 = 4'd1; end
            12'd132: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd133: begin O_semi = 6'd27; O_dur_q2 = 4'd6; end
            12'd134: begin O_semi = 6'd24; O_dur_q2 = 4'd1; end
            12'd135: begin O_semi = 6'd27; O_dur_q2 = 4'd1; end
            12'd136: begin O_semi = 6'd29; O_dur_q2 = 4'd2; end
            12'd137: begin O_semi = 6'd32; O_dur_q2 = 4'd2; end
            12'd138: begin O_semi = 6'd31; O_dur_q2 = 4'd1; end
            12'd139: begin O_semi = 6'd29; O_dur_q2 = 4'd1; end
            12'd140: begin O_semi = 6'd27; O_dur_q2 = 4'd2; end
            12'd141: begin O_semi = 6'd29; O_dur_q2 = 4'd8; end
            default: begin O_semi = 6'd0; O_dur_q2 = 4'd2; end
        endcase
    end

endmodule

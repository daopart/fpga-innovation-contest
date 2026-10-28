#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把《东南苦行山》简谱转成 FPGA 音符 ROM（melody_rom.v）+ 一段 WAV 预览。

简谱来源：jianpu.space 的《東南苦行山》(殷正洋) 记谱，纯旋律、含节奏记号。
记号约定（Jianpu Space 格式）：
    1..7    音级（1 = do）
    ,       低八度        '  高八度
    _       八分音符（半拍）
    .       附点（×1.5）
    -       延长一拍（可连续）

用法：
    python gen_melody_rom.py                 # 生成 melody_rom.v + melody_preview.wav
    python gen_melody_rom.py --bpm 66        # 改速度
    python gen_melody_rom.py --octave 1      # 整体升八度
"""

import argparse
import math
import os
import re
import struct
import wave

# ----------------------------------------------------------------------------
# 简谱（主歌 2 段 + 副歌 1 段，副歌重复两次，与歌词一致）
# ----------------------------------------------------------------------------
VERSE1 = "6,32_5_3_2_|33_3_2-|16,5,3,_5,_|6,---|16,2_1_2_3_|53_2_33_3_|216,5,|6,---|"
VERSE2 = "6,32_5_3_2_|33_3_2-|16,5,3,_5,_|6,---|16,2_1_2_3_|53_2_33_3_|216,5,|6,--|"
CHORUS = ("3_5_|66_6_53_2_|35_3_2-|332_3_2_1_|6,7,_5,_6,.1_|26,_1_22_3_|5--3_5_|61'7_6_5|"
          "6--3_5_|66_6_53_2_|35_3_2-|332_3_2_1_|6,7,_5,_6,.1_|26,_1_22_3_|5--3_5_|61'7_6_5|6---|")

SECTIONS = [("主歌1", VERSE1), ("主歌2", VERSE2), ("副歌", CHORUS)]

# 音级 -> 半音（相对 do）
DEGREE_PC = {1: 0, 2: 2, 3: 4, 4: 5, 5: 7, 6: 9, 7: 11}

TOKEN_RE = re.compile(r"([1-7])([,']?)(\.?)(_?)(-*)")

FS = 48000                 # I2S 采样率
SIN_POINTS = 64            # 正弦表点数
AMP = 7000000              # 正弦表峰值（叠加二次谐波后峰值约 7.5M，约 -1dBFS）
HARM2_SHIFT = 2            # 二次谐波衰减：2 = 1/4 幅度，必须与 Verilog 的 HARM2_SHIFT 一致
ATTACK_RELEASE = 2         # env 每采样最大变化量（约 2ms 上升 / 2.5ms 释放）
RELEASE_SAMPLES = 480      # 音符最后 10ms 做释放


def midi_of(deg, acc):
    octave = 4
    if acc == ",":
        octave -= 1
    elif acc == "'":
        octave += 1
    return 12 * (octave + 1) + DEGREE_PC[deg]


def parse_score(text, first_bar_pickup=False):
    """返回 (events, report)；event = (midi, beats, label, bar_index)。"""
    events = []
    report = []
    bar_no = 0
    for chunk in text.split("|"):
        chunk = chunk.strip()
        if not chunk:
            continue
        bar_no += 1
        total = 0.0
        bar_events = []
        for m in TOKEN_RE.finditer(chunk):
            deg = int(m.group(1))
            acc = m.group(2)
            dotted = m.group(3) == "."
            eighth = m.group(4) == "_"
            holds = len(m.group(5))

            beats = 0.5 if eighth else 1.0
            if dotted:
                beats *= 1.5
            beats += holds
            total += beats
            bar_events.append([midi_of(deg, acc), beats])

        if not bar_events:
            continue
        is_pickup = first_bar_pickup and bar_no == 1 and total < 4.0 - 1e-9
        if total < 4.0 - 1e-9 and not is_pickup:
            # 简谱里个别小节记谱偏短（漏了半拍），把这半拍补给最后一拍
            bar_events[-1][1] += 4.0 - total
            report.append("bar %-3d sum=%.1f -> 补齐到 4.0" % (bar_no, total))
        elif is_pickup:
            report.append("bar %-3d sum=%.1f（弱起小节，保持原样）" % (bar_no, total))
        elif total > 4.0 + 1e-9:
            report.append("bar %-3d sum=%.1f (偏长，保持原样)" % (bar_no, total))
        for midi, beats in bar_events:
            events.append((midi, beats, "", bar_no))
    return events, report


def sine_table(n=SIN_POINTS):
    return [int(round(AMP * math.sin(2.0 * math.pi * i / n))) for i in range(n)]


def step_of(midi):
    """midi -> 48kHz 相位步进（2^32 = 一个周期）。"""
    f = 440.0 * (2.0 ** ((midi - 69) / 12.0))
    return int(round(f * (1 << 32) / FS))


def render(events, bpm, octave_shift, loop_gap_s=1.2):
    """按和 Verilog 完全相同的算法渲染 48kHz/24bit 单声道，返回采样列表。

    波形 = 正弦基频 + 1/2^HARM2_SHIFT 的二次谐波（与 hdmi_audio_melody_i2s_64fs.v 一致）。
    """
    sin_tbl = sine_table()
    spb = FS * 60.0 / bpm
    samples = []
    phase = 0
    env = 0
    for midi, beats, _lbl, _bar in events:
        midi += 12 * octave_shift
        step = step_of(midi)
        n = max(1, int(round(beats * spb)))
        for i in range(n):
            phase = (phase + step) & 0xFFFFFFFF
            i1 = (phase >> 26) & 0x3F
            i2 = (phase >> 25) & 0x3F
            mix = sin_tbl[i1] + (sin_tbl[i2] >> HARM2_SHIFT)
            target = 0 if i >= n - RELEASE_SAMPLES else 255
            if env < target:
                env = min(target, env + ATTACK_RELEASE)
            elif env > target:
                env = max(target, env - ATTACK_RELEASE)
            samples.append((mix * env) >> 8)
        phase = 0  # 每个音重新起振，避免相位跳变
    # 循环前的静音
    samples.extend([0] * int(loop_gap_s * FS))
    return samples


def write_wav(path, samples, fs=FS):
    with wave.open(path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(3)
        wf.setframerate(fs)
        buf = bytearray()
        for s in samples:
            s = max(-(1 << 23), min((1 << 23) - 1, s))
            buf += int(s & 0xFFFFFF).to_bytes(3, "little")
        wf.writeframes(bytes(buf))


def emit_verilog(path, events, bpm, octave_shift):
    """生成 melody_rom.v：note_semitone(idx) + note_dur_q2(idx)，半音以 A3(57) 为 0。"""
    BASE_MIDI = 40                    # E2 = 82Hz（半音索引 0，最大 63）
    semis = []
    dur_q2 = []
    for midi, beats, _l, _b in events:
        m = midi + 12 * octave_shift
        semi = m - BASE_MIDI
        assert 0 <= semi <= 63, "音高超出范围: midi=%d octave=%d" % (m, octave_shift)
        q2 = int(round(beats * 2))
        assert 1 <= q2 <= 8, (midi, beats, q2)
        semis.append(semi)
        dur_q2.append(q2)

    n = len(events)
    spb = FS * 60.0 / bpm
    loops = int(round(sum(dur_q2) * spb / 2 + 1.2 * FS))

    lines = []
    lines.append("// -----------------------------------------------------------------------------")
    lines.append("// melody_rom.v  —— 由 tools/gen_melody_rom.py 自动生成，请勿手改")
    lines.append("// 曲目：《东南苦行山》（殷正洋）/ 简谱旋律，音符 %d 个" % n)
    lines.append("// 速度：%d BPM    采样率：%d Hz    一个循环约 %.1f 秒" % (bpm, FS, loops / FS))
    lines.append("// 半音基准：0 = E2（82.41Hz），最大 63")
    lines.append("// 改法：改脚本里的简谱 / --bpm / --octave，重跑脚本生成，再重新综合")
    lines.append("// -----------------------------------------------------------------------------")
    lines.append("")
    lines.append("module melody_rom #(")
    lines.append("    parameter integer NOTE_NUM = %d" % n)
    lines.append(") (")
    lines.append("    input  wire [11:0]  I_idx,      // 音符序号")
    lines.append("    output reg  [5:0]   O_semi,     // 半音序号（0 = A3）")
    lines.append("    output reg  [3:0]   O_dur_q2    // 时值，单位 1/2 拍（1..8）")
    lines.append(");")
    lines.append("")
    lines.append("    always @(*) begin")
    lines.append("        O_semi   = 6'd0;")
    lines.append("        O_dur_q2 = 4'd2;")
    lines.append("        case (I_idx)")
    for i in range(n):
        lines.append("            12'd%d: begin O_semi = 6'd%d; O_dur_q2 = 4'd%d; end"
                     % (i, semis[i], dur_q2[i]))
    lines.append("            default: begin O_semi = 6'd0; O_dur_q2 = 4'd2; end")
    lines.append("        endcase")
    lines.append("    end")
    lines.append("")
    lines.append("endmodule")
    lines.append("")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    return n, loops


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bpm", type=int, default=72)
    ap.add_argument("--octave", type=int, default=0, help="整体升降八度")
    ap.add_argument("--outdir", default=".")
    args = ap.parse_args()

    events = []
    problems = 0
    for name, text in SECTIONS:
        ev, rep = parse_score(text, first_bar_pickup=(name == "副歌"))
        print("[%s] %d 个音" % (name, len(ev)))
        for r in rep:
            print("   " + r)
            problems += 1
        events.extend(ev)

    total_beats = sum(e[1] for e in events)
    print("合计：%d 个音，%.1f 拍，%d BPM 时约 %.1f 秒" %
          (len(events), total_beats, args.bpm, total_beats * 60.0 / args.bpm))

    n, loop_samples = emit_verilog(os.path.join(args.outdir, "melody_rom.v"),
                                   events, args.bpm, args.octave)
    samples = render(events, args.bpm, args.octave)
    write_wav(os.path.join(args.outdir, "melody_preview.wav"), samples)
    peak = max(abs(s) for s in samples)
    print("已生成 melody_rom.v（%d 个音）与 melody_preview.wav（%.1f 秒，峰值 %d）"
          % (n, len(samples) / FS, peak))


if __name__ == "__main__":
    main()

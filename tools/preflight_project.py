#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""TD 工程自检（换电脑 / 交接前跑一遍）。

专门查那些"我这台能过、别人那台有时崩"的原因：
  1. 工程路径含中文/空格（TD 对非 ASCII 路径敏感）
  2. .al 登记的文件是否都存在（缺 IP/生成文件 → 别人那边黑盒或直接崩）
  3. 源码是否 UTF-8 带 BOM / 混用换行
  4. 是否有重复 module 名（TD 可能挑中不同实现 → 行为不一致）
  5. 被例化但"定义在被排除文件/根本不存在"的模块 = 黑盒风险
  6. TD 版本、run 目录里的崩溃转储、上次是否真的跑完了

用法：
    python tools/preflight_project.py [工程根目录]
"""

import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")

KEYWORDS = {
    "module", "endmodule", "input", "output", "inout", "wire", "reg", "assign",
    "always", "initial", "begin", "end", "if", "else", "case", "casez", "casex",
    "endcase", "function", "endfunction", "task", "endtask", "parameter",
    "localparam", "generate", "endgenerate", "for", "while", "repeat", "forever",
    "posedge", "negedge", "or", "and", "not", "default", "integer", "real",
    "genvar", "always_ff", "always_comb", "always_latch", "logic", "signed",
    "unsigned", "defparam", "specify", "endspecify", "buf", "bufif0", "bufif1",
    "nand", "nor", "xor", "xnor", "supply0", "supply1", "tri", "wand", "wor",
}

problems, warnings, infos = [], [], []


def add(level, msg):
    {"ERR": problems, "WARN": warnings}.get(level, infos).append(msg)


def parse_al(al_path):
    txt = open(al_path, encoding="utf-8", errors="replace").read()
    m = re.search(r"<TOP_MODULE>\s*<LABEL>([^<]+)</LABEL>", txt)
    top = m.group(1).strip() if m else None
    files = []
    for mm in re.finditer(r'<File Path="([^"]+)">(.*?)(?=<File Path=|\Z)', txt, re.S):
        path, body = mm.group(1), mm.group(2)
        p = os.path.normpath(os.path.join(os.path.dirname(al_path), path))
        excluded = 'Name="AutoExcluded" Val="true"' in body
        files.append((p, excluded, path))
    return top, files


def check_path(root):
    if any(ord(c) > 127 for c in root):
        add("ERR", "工程路径含非 ASCII 字符：%s\n        → 建议挪到 D:\\fpga\\merged 这种纯英文路径" % root)
    if " " in root:
        add("WARN", "工程路径含空格：%s\n        → 少数机器上 TD 调脚本会被空格截断" % root)


def check_files(root, files):
    for p, _, raw in files:
        if not os.path.isfile(p):
            add("ERR", "登记的文件不存在：%s\n        → 拷工程时漏了它（常见：IP/ 下的生成文件、al_ip/）" % raw)
    syn = [p for p, ex, _ in files if not ex]
    add("INFO", "登记 %d 个文件：参与综合 %d / 被排除 %d"
        % (len(files), len(syn), len(files) - len(syn)))


def check_encoding(root, files):
    bom, nonutf8, mixed = [], [], []
    for p, _, _ in files:
        if not os.path.isfile(p) or not p.lower().endswith((".v", ".sv", ".vh")):
            continue
        raw = open(p, "rb").read()
        if raw.startswith(b"\xef\xbb\xbf"):
            bom.append(p)
        try:
            raw.decode("utf-8")
        except UnicodeDecodeError:
            nonutf8.append(p)
        if b"\r\n" in raw and re.search(rb"(?<!\r)\n", raw):
            mixed.append(p)
    for p in bom:
        add("WARN", "带 UTF-8 BOM：%s（TD 偶尔会把 BOM 当字符）" % os.path.basename(p))
    for p in nonutf8:
        add("ERR", "不是 UTF-8（可能被存成 GBK）：%s → 别人机器上中文注释会乱码/报错" % os.path.basename(p))
    for p in mixed:
        add("WARN", "换行 CRLF/LF 混用：%s" % os.path.basename(p))
    if not (bom or nonutf8 or mixed):
        add("INFO", "源码编码：全部 UTF-8 无 BOM，换行统一")


def scan_modules(files):
    """返回 (定义 name->[(path, excluded)], 例化 name->[filename])"""
    defs, insts = {}, {}
    for p, excluded, _ in files:
        if not os.path.isfile(p):
            continue
        txt = open(p, encoding="utf-8", errors="replace").read()
        for m in re.finditer(r"^\s*module\s+([A-Za-z_]\w*)", txt, re.M):
            defs.setdefault(m.group(1), []).append((p, excluded))
        if excluded:
            continue
        for line in txt.splitlines():
            s = line.strip()
            if not s or s.startswith("//"):
                continue
            m = re.match(r"([A-Za-z_]\w*)\s*(#\s*\([^;]*\)\s*)?[A-Za-z_]\w*\s*\(", s)
            if not m:
                continue
            name = m.group(1)
            if name in KEYWORDS:
                continue
            insts.setdefault(name, []).append(os.path.basename(p))
    return defs, insts


def check_blackbox(root, files):
    """只查真正危险的一种：模块被例化，但它的定义只存在于被排除（AutoExcluded）的文件里。
    —— 这正是之前 flip_ctrl / adj_osd 变成黑盒的原因。"""
    defs, insts = scan_modules(files)

    # 只保留“定义存在、但全部被排除”的模块
    excl_only = {k for k, v in defs.items() if v and all(ex for _, ex in v)}

    for name in sorted(insts):
        if name in excl_only:
            where = ",".join(sorted({os.path.basename(p) for p, _ in defs[name]}))
            add("WARN", "'%s' 被例化（%s），但定义只在被排除的文件 %s 里 → 综合时变黑盒（旧版就是这么丢功能的）"
                % (name, ",".join(sorted(set(insts[name]))), where))

    dups = {k: v for k, v in defs.items() if len(set(p for p, _ in v)) > 1}
    for k, v in dups.items():
        add("ERR", "模块名重复 '%s'：%s → 不同机器可能挑中不同实现"
            % (k, " / ".join(sorted({os.path.basename(p) for p, _ in v}))))

    syn_defs = {k for k, v in defs.items() if any(not ex for _, ex in v)}
    add("INFO", "模块：定义 %d 个，参与综合 %d 个，被排除 %d 个"
        % (len(defs), len(syn_defs), len(defs) - len(syn_defs)))


def check_td_and_runs(root):
    bat = None
    for dirpath, _, names in os.walk(root):
        if "run.bat" in names:
            bat = os.path.join(dirpath, "run.bat")
            break
    if bat:
        txt = open(bat, encoding="utf-8", errors="replace").read()
        m = re.search(r"TD_([\d.]+)_Engineer", txt) or re.search(r"Tang Dynasty ([\d.]+)", txt)
        add("INFO", "TD 版本：%s（交接时要求所有人一致）" % (m.group(1) if m else "?"))
    else:
        add("INFO", "未包含 TD 运行目录（提交版只保留源码）；TD 版本见 integration.al，为 6.2.168116")

    for dirpath, dirnames, _ in os.walk(root):
        if os.path.basename(dirpath).endswith("_Runs"):
            for d in sorted(dirnames):
                run = os.path.join(dirpath, d)
                log = os.path.join(run, "run.log")
                dmp = [f for f in os.listdir(run) if f.lower().endswith(".dmp")]
                tail = ""
                if os.path.isfile(log):
                    tail = open(log, encoding="utf-8", errors="replace").read()[-8000:]
                bit = [f for f in os.listdir(run) if f.endswith(".bit")]
                if tail:
                    tag = "跑完了" if "Flow Statistics" in tail else "没跑完"
                else:
                    tag = "（没有 run.log，只是产物目录）"
                if bit:
                    tag += "，有位流 " + bit[0]
                if dmp:
                    add("WARN", "%s：%s，但有崩溃转储 %s → 进程退出时崩了（产物通常仍可用）"
                        % (d, tag, dmp[0]))
                else:
                    add("INFO", "%s：%s" % (d, tag))


def main():
    root = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else
                           os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    al = os.path.join(root, "src", "td_project", "integration.al")
    print("=" * 76)
    print(" TD 工程自检：%s" % root)
    print("=" * 76)
    if not os.path.isfile(al):
        print("找不到 %s" % al)
        return 2

    check_path(root)
    top, files = parse_al(al)
    add("INFO", "TOP_MODULE = %s" % top)
    check_files(root, files)
    check_encoding(root, files)
    check_blackbox(root, files)
    check_td_and_runs(root)

    for m in infos:
        print(" [ OK ] " + m)
    for m in warnings:
        print(" [WARN] " + m)
    for m in problems:
        print(" [ERR ] " + m)
    print("-" * 76)
    print(" 结论：%d 个必须修，%d 个提醒" % (len(problems), len(warnings)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

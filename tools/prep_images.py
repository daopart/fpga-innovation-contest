#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""prep_images.py —— 把任意图片批量转成板子要的 BMP（640x480、24bit、未压缩）。

为什么要这个工具：板子的 HDMI 输出是固定的 640x480（像素时钟 25MHz，TMDS 5x = 125MHz，
再往上 720p 需要 371MHz，硬件做不到）。所以"图看起来清不清楚"取决于**缩放质量**——
用 Lanczos 重采样比让 FPGA 直接丢像素或 2x2 平均干净得多，细线和文字不会出摩尔纹。

用法：
    python tools/prep_images.py 图片目录 [-o 输出目录] [--fit crop|letterbox] [--sharpen 0.6]

选项：
    --fit crop        中心裁剪成 4:3（适合主体在中间的照片）
    --fit letterbox   完整保留画面、上下加黑边（默认）
    --sharpen N       轻度锐化，0 = 不锐化（推荐 0.4~0.8，屏幕小的时候更清楚）
"""
import argparse
import glob
import os
import sys

sys.stdout.reconfigure(encoding='utf-8')
from PIL import Image, ImageFilter

W, H = 640, 480


def convert(src, dst, fit, sharpen):
    img = Image.open(src).convert("RGB")
    w, h = img.size
    if fit == "crop":
        # 按 4:3 中心裁剪
        target_ratio = W / H
        if w / h > target_ratio:
            nw = int(h * target_ratio)
            x0 = (w - nw) // 2
            img = img.crop((x0, 0, x0 + nw, h))
        else:
            nh = int(w / target_ratio)
            y0 = (h - nh) // 2
            img = img.crop((0, y0, w, y0 + nh))
        out = img.resize((W, H), Image.LANCZOS)
    else:
        # letterbox：等比缩放到能放进去，再居中贴到黑底
        scale = min(W / w, H / h)
        nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
        small = img.resize((nw, nh), Image.LANCZOS)
        out = Image.new("RGB", (W, H), (0, 0, 0))
        out.paste(small, ((W - nw) // 2, (H - nh) // 2))
    if sharpen > 0:
        out = out.filter(ImageFilter.UnsharpMask(radius=1.2, percent=int(sharpen * 100), threshold=2))
    out.save(dst, "BMP")          # PIL 的 BMP = 24bit BI_RGB、行按 4 字节对齐，板子能直接读


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("-o", "--out", default=None)
    ap.add_argument("--fit", choices=["crop", "letterbox"], default="letterbox")
    ap.add_argument("--sharpen", type=float, default=0.5)
    a = ap.parse_args()

    if os.path.isdir(a.src):
        seen = set()
        for ext in ("*.jpg", "*.jpeg", "*.png", "*.bmp", "*.webp"):
            for f in glob.glob(os.path.join(a.src, ext)):
                seen.add(os.path.normcase(os.path.abspath(f)))
        files = sorted(seen)
        outdir = a.out or os.path.join(a.src, "bmp_out")
    else:
        files = [a.src]
        outdir = a.out or os.path.dirname(os.path.abspath(a.src))

    os.makedirs(outdir, exist_ok=True)
    if not files:
        print("没找到图片")
        return 1

    for i, f in enumerate(files, 1):
        name = "IMG%02d.BMP" % i
        dst = os.path.join(outdir, name)
        try:
            convert(f, dst, a.fit, a.sharpen)
            sz = os.path.getsize(dst)
            print("  %-40s -> %-12s %dx%d  %d 字节" % (os.path.basename(f), name, W, H, sz))
        except Exception as e:
            print("  [失败] %s: %s" % (os.path.basename(f), e))
    print("完成，输出目录：%s  共 %d 张" % (outdir, len(files)))
    print("提示：卡上的 BMP 建议命名成 IMG01.BMP、IMG02.BMP…（板子按目录顺序扫）")
    return 0


if __name__ == "__main__":
    sys.exit(main())

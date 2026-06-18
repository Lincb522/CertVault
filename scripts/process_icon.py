#!/usr/bin/env python3
"""处理 AppIcon 图片：裁切为正方形、缩放到 1024x1024，并复制到多个目标位置"""

import shutil
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("错误: 请先安装 Pillow: pip install Pillow")
    exit(1)

ROOT = Path(__file__).resolve().parents[1]
TARGETS = [
    ROOT / "ios/CertVault/Assets.xcassets/AppIcon.appiconset/icon_1024.png",
    ROOT / "ios/CertVault/Assets.xcassets/AppLogo.imageset/icon_1024.png",
    ROOT / "client/src/assets/app-icon.png",
    ROOT / "client/public/app-icon.png",
]

def main():
    if len(sys.argv) != 2:
        print(f"用法: {Path(sys.argv[0]).name} /path/to/app-icon.png")
        exit(1)

    source = Path(sys.argv[1]).expanduser().resolve()
    if not source.exists():
        print(f"错误: 源文件不存在: {source}")
        exit(1)

    img = Image.open(source).convert("RGBA")
    w, h = img.size
    print(f"原始尺寸: {w} x {h}")

    # 如果不是正方形，从中心裁切为正方形
    if w != h:
        size = min(w, h)
        left = (w - size) // 2
        top = (h - size) // 2
        img = img.crop((left, top, left + size, top + size))
        print(f"裁切后尺寸: {size} x {size}")

    # 缩放为 1024x1024
    img = img.resize((1024, 1024), Image.Resampling.LANCZOS)
    print(f"缩放后尺寸: 1024 x 1024")

    # 保存覆盖原文件
    img.save(source, "PNG")
    source_size = source.stat().st_size
    print(f"保存完成，文件大小: {source_size} 字节")

    # 复制到目标位置
    print("\n复制到目标位置:")
    for dst in TARGETS:
        try:
            dst.parent.mkdir(parents=True, exist_ok=True)
            if dst.exists():
                dst.unlink()
            shutil.copy2(source, dst)
            sz = dst.stat().st_size
            print(f"  ✓ {dst} ({sz} 字节)")
        except Exception as e:
            print(f"  ✗ {dst}: {e}")

    # 验证所有目标文件大小一致
    print("\n验证目标文件大小:")
    sizes = [t.stat().st_size for t in TARGETS if t.exists()]
    if len(sizes) == len(TARGETS) and len(set(sizes)) == 1:
        print(f"  全部一致: {sizes[0]} 字节")
    else:
        for t in TARGETS:
            if t.exists():
                print(f"  {t}: {t.stat().st_size} 字节")

if __name__ == "__main__":
    main()

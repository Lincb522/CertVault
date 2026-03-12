#!/usr/bin/env python3
"""处理 AppIcon 图片：裁切为正方形、缩放到 1024x1024，并复制到多个目标位置"""

import os
import shutil
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("错误: 请先安装 Pillow: pip install Pillow")
    exit(1)

SOURCE = "/Users/linchengbo/.cursor/projects/Users-linchengbo-appuploader-p12/assets/AppIcon_v3_light.png"
TARGETS = [
    "/Users/linchengbo/appuploader/p12/ios/CertVault/Assets.xcassets/AppIcon.appiconset/icon_1024.png",
    "/Users/linchengbo/appuploader/p12/ios/CertVault/Assets.xcassets/AppLogo.imageset/icon_1024.png",
    "/Users/linchengbo/appuploader/p12/client/src/assets/app-icon.png",
    "/Users/linchengbo/appuploader/p12/client/public/app-icon.png",
    "/Users/linchengbo/appuploader/p12/client/dist/app-icon.png",
]

def main():
    if not os.path.exists(SOURCE):
        print(f"错误: 源文件不存在: {SOURCE}")
        exit(1)

    img = Image.open(SOURCE).convert("RGBA")
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
    img.save(SOURCE, "PNG")
    source_size = os.path.getsize(SOURCE)
    print(f"保存完成，文件大小: {source_size} 字节")

    # 复制到目标位置
    print("\n复制到目标位置:")
    for dst in TARGETS:
        try:
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            if os.path.exists(dst):
                os.remove(dst)
            shutil.copy2(SOURCE, dst)
            sz = os.path.getsize(dst)
            print(f"  ✓ {dst} ({sz} 字节)")
        except Exception as e:
            print(f"  ✗ {dst}: {e}")

    # 验证所有目标文件大小一致
    print("\n验证目标文件大小:")
    sizes = [os.path.getsize(t) for t in TARGETS if os.path.exists(t)]
    if len(sizes) == len(TARGETS) and len(set(sizes)) == 1:
        print(f"  全部一致: {sizes[0]} 字节")
    else:
        for t in TARGETS:
            if os.path.exists(t):
                print(f"  {t}: {os.path.getsize(t)} 字节")

if __name__ == "__main__":
    main()

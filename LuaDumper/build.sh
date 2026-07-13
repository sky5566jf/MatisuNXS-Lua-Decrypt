#!/bin/bash
# 一键编译 LuaDumper.dylib (需要 Mac + Xcode Command Line Tools)
# Usage: bash build.sh

set -e

echo "=== LuaDumper.dylib 一键编译脚本 ==="

# 检查 clang 是否可用
if ! command -v clang &> /dev/null; then
    echo "错误: 需要安装 Xcode Command Line Tools"
    echo "运行: xcode-select --install"
    exit 1
fi

echo "找到 clang: $(clang --version | head -1)"

# 编译为 iOS ARM64 动态库
echo "正在编译 LuaDumper.dylib (arm64)..."

clang -dynamiclib \
    -arch arm64 \
    -isysroot $(xcrun --sdk iphoneos --show-sdk-path) \
    -miphoneos-version-min=13.0 \
    -fobjc-arc \
    -O2 \
    -o LuaDumper.dylib \
    LuaDumper.m \
    -lSystem

if [ $? -eq 0 ]; then
    echo ""
    echo "=== 编译成功! ==="
    echo "输出文件: LuaDumper.dylib"
    echo "大小: $(ls -lh LuaDumper.dylib | awk '{print $5}')"
    echo ""
    echo "下一步:"
    echo "1. 将 LuaDumper.dylib 上传到 iOS 设备"
    echo "2. 放入 RootService.app/Root/Frameworks/ 目录"
    echo "3. 使用 luadump 版本的 IPA 安装"
    echo "4. 运行脚本后查看 /tmp/lua_dump/ 目录"
else
    echo "编译失败!"
    exit 1
fi

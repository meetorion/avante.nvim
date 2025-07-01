#!/usr/bin/env bash

# Script to install prebuilt binaries for avante.nvim
# This avoids the need to compile from source

set -e

echo "=== Avante.nvim 预构建安装脚本 ==="

# Get system info
PLATFORM="linux"
ARCH=$(uname -m)
LUA_VERSION="luajit"

echo "检测到系统: $PLATFORM $ARCH"

# Map architecture names
case "$ARCH" in
    "x86_64")
        DOWNLOAD_ARCH="x86_64"
        ;;
    "aarch64"|"arm64")
        DOWNLOAD_ARCH="aarch64"
        ;;
    *)
        echo "错误: 不支持的架构 $ARCH"
        echo "支持的架构: x86_64, aarch64"
        exit 1
        ;;
esac

# Set artifact name
ARTIFACT_NAME="avante_lib-$PLATFORM-$DOWNLOAD_ARCH-$LUA_VERSION"
echo "下载文件: $ARTIFACT_NAME.tar.gz"

# Get the script directory
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"

# Create build directory
echo "创建构建目录: $BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Get latest release info
echo "获取最新版本信息..."
LATEST_TAG=$(curl -s "https://api.github.com/repos/yetone/avante.nvim/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_TAG" ]; then
    echo "错误: 无法获取最新版本信息"
    exit 1
fi

echo "最新版本: $LATEST_TAG"

# Download URL
DOWNLOAD_URL="https://github.com/yetone/avante.nvim/releases/download/$LATEST_TAG/$ARTIFACT_NAME.tar.gz"
echo "下载地址: $DOWNLOAD_URL"

# Download and extract
echo "开始下载..."
if curl -L "$DOWNLOAD_URL" | tar -zxv -C "$BUILD_DIR"; then
    echo "✅ 预构建文件安装成功！"
    echo ""
    echo "安装的文件:"
    ls -la "$BUILD_DIR"
    echo ""
    echo "现在可以在 Neovim 中使用 avante.nvim 了！"
    echo "运行 :checkhealth avante 来验证安装"
else
    echo "❌ 下载失败，请检查网络连接或手动下载"
    echo "手动下载地址: $DOWNLOAD_URL"
    exit 1
fi
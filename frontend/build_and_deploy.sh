#!/bin/bash

# 自动获取后端IP并打包Flutter app
# 用法: ./build_and_deploy.sh [apk|ipa]

set -e

# 确保在frontend目录执行
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# 获取局域网IP（排除127.0.0.1）
LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
echo "[Build] 检测到本机IP: $LOCAL_IP"

if [ -z "$LOCAL_IP" ]; then
    echo "[Error] 无法获取局域网IP，请检查网络连接"
    exit 1
fi

# API配置文件路径
API_FILE="lib/services/api_service.dart"

# 更新baseUrl配置
echo "[Build] 更新API地址为: http://$LOCAL_IP:8000"

# 使用sed替换baseUrl和_defaultBaseUrl
sed -i '' "s|static String baseUrl = 'http://[^:]*:[^/]*/api'|static String baseUrl = 'http://$LOCAL_IP:8000/api'|g" "$API_FILE"
sed -i '' "s|static const String _defaultBaseUrl = 'http://[^:]*:[^/]*/api'|static const String _defaultBaseUrl = 'http://$LOCAL_IP:8000/api'|g" "$API_FILE"

echo "[Build] API配置已更新"
echo ""

# 显示更新后的配置
grep -n "baseUrl" "$API_FILE" | head -3
echo ""

# 执行打包
BUILD_TYPE=${1:-apk}

echo "[Build] 开始Flutter打包 ($BUILD_TYPE)..."

flutter clean
flutter pub get

if [ "$BUILD_TYPE" == "apk" ]; then
    flutter build apk --release
    echo ""
    echo "[Build] APK打包完成: build/app/outputs/flutter-apk/app-release.apk"
elif [ "$BUILD_TYPE" == "ipa" ]; then
    flutter build ios --release
    echo ""
    echo "[Build] iOS打包完成，请在Xcode中进一步处理"
else
    echo "[Error] 未知的打包类型: $BUILD_TYPE (支持: apk, ipa)"
    exit 1
fi

echo ""
echo "[Done] 打包完成！后端地址: http://$LOCAL_IP:8000"
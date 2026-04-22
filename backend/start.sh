#!/bin/bash
# 自动检测本机WiFi IP并启动后端服务

echo "正在检测本机IP地址..."

# 获取本机所有IP地址，优先选择WiFi相关的IP
IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)

if [ -z "$IP" ]; then
    echo "未检测到有效IP，使用默认地址 0.0.0.0"
    IP="0.0.0.0"
fi

echo "检测到IP: $IP"
echo "启动后端服务..."
echo "API地址: http://$IP:8000"
echo "========================================"

python3 -m uvicorn app.main:app --host "$IP" --port 8000 --reload

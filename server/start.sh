#!/bin/bash

# Apple 证书托管工具 — 宝塔部署启动脚本
# 端口: 3006

cd "$(dirname "$0")"

# 安装依赖（首次部署时）
if [ ! -d "node_modules" ]; then
  echo "首次部署，安装依赖..."
  npm install --production
fi

# 创建数据目录
mkdir -p data/certificates data/profiles data/p8keys data/uploads

# 启动
export PORT=3006
export NODE_ENV=production
node src/app.js

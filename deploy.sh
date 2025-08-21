#!/bin/bash

# 阿里云服务器部署脚本
echo "🚀 开始部署 English Learning Backend..."

# 1. 创建日志目录
mkdir -p logs

# 2. 安装依赖
echo "📦 安装依赖..."
npm install --production

# 3. 设置环境变量（生产环境）
echo "⚙️ 设置环境变量..."
cat > .env << EOF
PORT=3000
JWT_SECRET=$(openssl rand -base64 32)
NODE_ENV=production
DB_PATH=./learning.db
EOF

# 4. 停止旧进程（如果存在）
echo "🛑 停止旧进程..."
pm2 delete english-learning-api 2>/dev/null || true

# 5. 启动新进程
echo "🚀 启动服务..."
pm2 start ecosystem.config.js --env production

# 6. 保存 PM2 配置
pm2 save

# 7. 设置 PM2 开机自启
pm2 startup

echo "✅ 部署完成！"
echo "📊 查看状态: pm2 status"
echo "📝 查看日志: pm2 logs english-learning-api"

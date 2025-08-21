#!/bin/bash

# 从 Git 仓库部署 English Learning API 脚本
echo "🚀 开始从 Git 部署 English Learning Backend..."

# 设置变量
PROJECT_DIR="/www/english-learning-api"
REPO_URL="your-git-repository-url"  # 替换为您的 Git 仓库地址
BRANCH="main"  # 或者 master

# 1. 检查是否已有项目目录
if [ -d "$PROJECT_DIR" ]; then
    echo "📁 项目目录已存在，更新代码..."
    cd $PROJECT_DIR
    git pull origin $BRANCH
else
    echo "📁 创建新项目目录..."
    mkdir -p $PROJECT_DIR
    cd $PROJECT_DIR
    git clone $REPO_URL .
    git checkout $BRANCH
fi

# 2. 设置环境变量（如果不存在）
if [ ! -f ".env" ]; then
    echo "⚙️ 创建环境变量文件..."
    cat > .env << EOF
PORT=3000
JWT_SECRET=$(openssl rand -base64 32)
NODE_ENV=production
DB_PATH=./learning.db
CORS_ORIGIN=*
EOF
    echo "✅ 环境变量文件已创建"
else
    echo "✅ 环境变量文件已存在"
fi

# 3. 创建日志目录
mkdir -p logs

# 4. 安装/更新依赖
echo "📦 安装依赖..."
npm install --production

# 5. 停止旧进程（如果存在）
echo "🛑 停止旧进程..."
pm2 delete english-learning-api 2>/dev/null || true

# 6. 启动新进程
echo "🚀 启动服务..."
pm2 start ecosystem.config.js --env production

# 7. 保存 PM2 配置
pm2 save

# 8. 设置 PM2 开机自启（仅首次）
pm2 startup

echo ""
echo "✅ 部署完成！"
echo "📊 查看状态: pm2 status"
echo "📝 查看日志: pm2 logs english-learning-api"
echo "🔗 测试接口: curl http://localhost:3000/api/test"
echo ""

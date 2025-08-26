#!/bin/bash

echo "🚀 开始阿里云 ECS 部署..."

# 1. 更新系统
echo "📦 更新系统包..."
sudo apt-get update -y || sudo yum makecache -y

# 2. 安装 Node.js (18.x LTS)
echo "📦 安装 Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - 2>/dev/null || curl -sL https://rpm.nodesource.com/setup_18.x | sudo bash -
    sudo apt-get install -y nodejs || sudo yum install -y nodejs
fi

# 3. 安装编译工具 (better-sqlite3 需要)
echo "🔧 安装编译工具..."
sudo apt-get install -y build-essential python3 || sudo yum groupinstall -y "Development Tools" && sudo yum install -y python3

# 4. 安装 PM2
echo "📦 安装 PM2..."
sudo npm install -g pm2

# 5. 创建项目目录
echo "📁 创建项目目录..."
sudo mkdir -p /opt/lengthwords
sudo chown -R $USER:$USER /opt/lengthwords

# 6. 进入项目目录
cd /opt/lengthwords

# 7. 复制文件 (你需要手动上传代码到这个目录)
echo "📂 请确保以下文件已上传到 /opt/lengthwords/:"
echo "   - start.js"
echo "   - package.json" 
echo "   - ecosystem.config.js"
echo "   - lengthwords.top.key"
echo "   - lengthwords.top.pem"

# 8. 安装依赖
echo "📦 安装项目依赖..."
npm install

# 9. 创建日志目录
mkdir -p logs

# 10. 设置证书权限
if [ -f "lengthwords.top.key" ]; then
    chmod 600 lengthwords.top.key
    chmod 644 lengthwords.top.pem
fi

# 11. 启动服务
echo "🚀 启动服务..."
pm2 start ecosystem.config.js --env production

# 12. 保存 PM2 配置
pm2 save

# 13. 设置开机自启
pm2 startup

echo "✅ 部署完成！"
echo "📊 查看状态: pm2 status"
echo "📝 查看日志: pm2 logs lengthwords-api"
echo "🔗 测试地址: https://lengthwords.top/api/test"

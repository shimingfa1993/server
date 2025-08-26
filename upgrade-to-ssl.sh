#!/bin/bash

# SSL升级脚本 - 为现有的english-learning-api添加HTTPS支持
# 适用于已部署在 /www/english-learning-api 的项目

echo "🚀 开始为现有项目升级SSL支持..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
DOMAIN="lengthwords.top"
SSL_DIR="/etc/ssl/lengthwords"
PROJECT_DIR="/www/english-learning-api"
CERT_LOCAL_KEY="lengthwords.top.key"
CERT_LOCAL_PEM="lengthwords.top.pem"

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请以root权限运行此脚本${NC}"
    echo "使用: sudo bash upgrade-to-ssl.sh"
    exit 1
fi

# 检查项目目录是否存在
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${RED}❌ 项目目录不存在: $PROJECT_DIR${NC}"
    echo "请确认项目路径是否正确"
    exit 1
fi

# 1. 备份现有配置
echo -e "${BLUE}📦 备份现有配置...${NC}"
BACKUP_DIR="$PROJECT_DIR/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p $BACKUP_DIR
cp $PROJECT_DIR/server.js $BACKUP_DIR/ 2>/dev/null || true
cp $PROJECT_DIR/ecosystem.config.js $BACKUP_DIR/ 2>/dev/null || true
cp $PROJECT_DIR/package.json $BACKUP_DIR/ 2>/dev/null || true
echo -e "${GREEN}✅ 配置文件已备份到: $BACKUP_DIR${NC}"

# 2. 创建SSL证书目录
echo -e "${BLUE}📁 创建SSL证书目录...${NC}"
mkdir -p $SSL_DIR
chmod 700 $SSL_DIR

# 3. 检查证书文件是否存在
echo -e "${BLUE}🔍 检查SSL证书文件...${NC}"
if [ ! -f "$CERT_LOCAL_KEY" ] || [ ! -f "$CERT_LOCAL_PEM" ]; then
    echo -e "${RED}❌ 证书文件不存在！${NC}"
    echo "请确保以下文件在当前目录："
    echo "  - $CERT_LOCAL_KEY"
    echo "  - $CERT_LOCAL_PEM"
    echo ""
    echo "从阿里云SSL证书管理下载证书文件，选择Nginx格式"
    exit 1
fi

# 4. 复制证书文件
echo -e "${BLUE}📋 安装SSL证书文件...${NC}"
cp $CERT_LOCAL_KEY $SSL_DIR/
cp $CERT_LOCAL_PEM $SSL_DIR/

# 设置证书文件权限
chmod 600 $SSL_DIR/$CERT_LOCAL_KEY
chmod 644 $SSL_DIR/$CERT_LOCAL_PEM

echo -e "${GREEN}✅ SSL证书文件安装完成${NC}"

# 5. 停止现有服务
echo -e "${BLUE}⏸️  停止现有服务...${NC}"
cd $PROJECT_DIR
pm2 stop all 2>/dev/null || true
pm2 delete all 2>/dev/null || true

# 6. 更新环境配置
echo -e "${BLUE}⚙️  更新环境配置...${NC}"
cat > $PROJECT_DIR/.env << EOF
# 环境配置
NODE_ENV=production

# 端口配置
HTTP_PORT=80
HTTPS_PORT=443

# JWT密钥 (使用随机生成的密钥)
JWT_SECRET=$(openssl rand -hex 32)

# SSL证书路径
SSL_KEY_PATH=$SSL_DIR/$CERT_LOCAL_KEY
SSL_CERT_PATH=$SSL_DIR/$CERT_LOCAL_PEM

# 数据库配置
DB_PATH=./learning.db

# 日志配置
LOG_LEVEL=info

# CORS配置
ALLOWED_ORIGINS=https://lengthwords.top,https://www.lengthwords.top
EOF

echo -e "${GREEN}✅ 环境配置文件创建完成${NC}"

# 7. 更新package.json添加HTTPS脚本
echo -e "${BLUE}📝 更新package.json...${NC}"
if [ -f "$PROJECT_DIR/package.json" ]; then
    # 备份原package.json
    cp $PROJECT_DIR/package.json $PROJECT_DIR/package.json.backup
    
    # 使用Node.js脚本更新package.json
    cat > /tmp/update_package.js << 'EOF'
const fs = require('fs');
const packagePath = process.argv[2];
const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));

// 添加HTTPS相关脚本
packageJson.scripts = packageJson.scripts || {};
packageJson.scripts['start:https'] = 'node server-https.js';
packageJson.scripts['dev:https'] = 'nodemon server-https.js';
packageJson.scripts['pm2:start:https'] = 'pm2 start ecosystem.config.js --only english-learning-https --env production';
packageJson.scripts['pm2:stop:https'] = 'pm2 stop english-learning-https';
packageJson.scripts['pm2:restart:https'] = 'pm2 restart english-learning-https';
packageJson.scripts['pm2:delete:https'] = 'pm2 delete english-learning-https';
packageJson.scripts['pm2:logs:https'] = 'pm2 logs english-learning-https';

fs.writeFileSync(packagePath, JSON.stringify(packageJson, null, 2));
console.log('package.json 更新完成');
EOF
    
    node /tmp/update_package.js $PROJECT_DIR/package.json
    rm /tmp/update_package.js
fi

# 8. 复制HTTPS服务器文件
echo -e "${BLUE}📄 复制HTTPS服务器文件...${NC}"
if [ -f "server-https.js" ]; then
    cp server-https.js $PROJECT_DIR/
    echo -e "${GREEN}✅ server-https.js 已复制${NC}"
else
    echo -e "${YELLOW}⚠️  server-https.js 文件不存在，请手动复制${NC}"
fi

# 9. 更新ecosystem.config.js
echo -e "${BLUE}⚙️  更新PM2配置...${NC}"
cat > $PROJECT_DIR/ecosystem.config.js << 'EOF'
module.exports = {
  apps: [
    {
      // 原HTTP版本 (内部使用)
      name: 'english-learning-api',
      script: 'server.js',
      instances: 1,
      exec_mode: 'cluster',
      env: {
        NODE_ENV: 'development',
        PORT: 3000
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3000
      },
      error_file: './logs/err.log',
      out_file: './logs/out.log',
      log_file: './logs/combined.log',
      time: true,
      watch: false,
      max_memory_restart: '1G',
      restart_delay: 4000
    },
    {
      // HTTPS版本 (对外服务)
      name: 'english-learning-https',
      script: 'server-https.js',
      instances: 1,
      exec_mode: 'cluster',
      env: {
        NODE_ENV: 'development',
        HTTP_PORT: 8080,
        HTTPS_PORT: 8443
      },
      env_production: {
        NODE_ENV: 'production',
        HTTP_PORT: 80,
        HTTPS_PORT: 443
      },
      error_file: './logs/https-err.log',
      out_file: './logs/https-out.log',
      log_file: './logs/https-combined.log',
      time: true,
      watch: false,
      max_memory_restart: '1G',
      restart_delay: 4000
    }
  ]
};
EOF

echo -e "${GREEN}✅ PM2配置文件更新完成${NC}"

# 10. 创建日志目录
echo -e "${BLUE}📁 创建日志目录...${NC}"
mkdir -p $PROJECT_DIR/logs
chmod 755 $PROJECT_DIR/logs

# 11. 安装/更新依赖
echo -e "${BLUE}📦 检查依赖...${NC}"
cd $PROJECT_DIR
if [ ! -d "node_modules" ] || [ ! -f "node_modules/.package-lock.json" ]; then
    echo "安装/更新Node.js依赖..."
    npm install
fi

# 确保安装了必需的SSL相关依赖
npm ls https > /dev/null 2>&1 || npm install https

# 12. 配置防火墙
echo -e "${BLUE}🔥 配置防火墙规则...${NC}"
if command -v ufw &> /dev/null; then
    # Ubuntu/Debian
    ufw allow 80/tcp
    ufw allow 443/tcp
    echo -e "${GREEN}✅ UFW防火墙规则配置完成${NC}"
elif command -v firewall-cmd &> /dev/null; then
    # CentOS/RHEL
    firewall-cmd --permanent --add-port=80/tcp
    firewall-cmd --permanent --add-port=443/tcp
    firewall-cmd --reload
    echo -e "${GREEN}✅ FirewallD防火墙规则配置完成${NC}"
else
    echo -e "${YELLOW}⚠️  请手动配置防火墙开放80和443端口${NC}"
fi

# 13. 启动HTTPS服务
echo -e "${BLUE}🚀 启动HTTPS服务...${NC}"
if [ -f "server-https.js" ]; then
    pm2 start ecosystem.config.js --only english-learning-https --env production
    pm2 startup
    pm2 save
    echo -e "${GREEN}✅ HTTPS服务启动完成${NC}"
else
    echo -e "${RED}❌ server-https.js 文件不存在，无法启动HTTPS服务${NC}"
    echo "请先复制 server-https.js 文件到项目目录"
fi

# 14. 验证服务状态
echo -e "${BLUE}🔍 验证服务状态...${NC}"
sleep 3

# 检查PM2状态
pm2 status

# 检查端口
if netstat -tuln | grep -q ":443"; then
    echo -e "${GREEN}✅ HTTPS端口443正在监听${NC}"
else
    echo -e "${RED}❌ HTTPS端口443未开放${NC}"
fi

if netstat -tuln | grep -q ":80"; then
    echo -e "${GREEN}✅ HTTP端口80正在监听${NC}"
else
    echo -e "${RED}❌ HTTP端口80未开放${NC}"
fi

# 15. 输出升级完成信息
echo -e "\n${GREEN}🎉 SSL升级完成！${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📋 升级信息:${NC}"
echo -e "   🌐 HTTPS域名: https://$DOMAIN"
echo -e "   📁 项目路径: $PROJECT_DIR"
echo -e "   🔒 SSL证书路径: $SSL_DIR/"
echo -e "   📝 备份路径: $BACKUP_DIR"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}🧪 测试命令:${NC}"
echo -e "   curl -k https://$DOMAIN/api/test"
echo -e "   curl http://$DOMAIN/api/test"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📱 小程序更新:${NC}"
echo -e "   将API地址改为: https://$DOMAIN"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}🔧 管理命令:${NC}"
echo -e "   pm2 status                    # 查看服务状态"
echo -e "   pm2 logs english-learning-https  # 查看HTTPS日志"
echo -e "   pm2 restart english-learning-https  # 重启HTTPS服务"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${GREEN}现有项目已成功升级为HTTPS！您的小程序现在可以安全访问API了！${NC}"

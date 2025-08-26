#!/bin/bash

# SSL证书部署脚本
# 用于在阿里云ECS上部署lengthwords.top的SSL证书

echo "🚀 开始部署SSL证书..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
DOMAIN="lengthwords.top"
SSL_DIR="/home/ssl"
PROJECT_DIR="/home/english-learning"
CERT_LOCAL_KEY="lengthwords.top.key"
CERT_LOCAL_PEM="lengthwords.top.pem"

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请以root权限运行此脚本${NC}"
    echo "使用: sudo bash deploy-ssl.sh"
    exit 1
fi

# 1. 创建SSL证书目录
echo -e "${BLUE}📁 创建SSL证书目录...${NC}"
mkdir -p $SSL_DIR
chmod 700 $SSL_DIR

# 2. 检查证书文件是否存在
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

# 3. 复制证书文件到指定目录
echo -e "${BLUE}📋 复制SSL证书文件...${NC}"
cp $CERT_LOCAL_KEY $SSL_DIR/
cp $CERT_LOCAL_PEM $SSL_DIR/

# 设置证书文件权限
chmod 600 $SSL_DIR/$CERT_LOCAL_KEY
chmod 644 $SSL_DIR/$CERT_LOCAL_PEM

echo -e "${GREEN}✅ SSL证书文件复制完成${NC}"

# 4. 创建环境变量文件
echo -e "${BLUE}⚙️  创建环境变量文件...${NC}"
cat > $PROJECT_DIR/.env << EOF
# 环境配置
NODE_ENV=production

# 端口配置
HTTP_PORT=80
HTTPS_PORT=443

# JWT密钥
JWT_SECRET=$(openssl rand -hex 32)

# SSL证书路径
SSL_KEY_PATH=$SSL_DIR/$CERT_LOCAL_KEY
SSL_CERT_PATH=$SSL_DIR/$CERT_LOCAL_PEM

# 数据库配置
DB_PATH=./learning.db

# 日志配置
LOG_LEVEL=info
EOF

echo -e "${GREEN}✅ 环境变量文件创建完成${NC}"

# 5. 安装依赖（如果需要）
echo -e "${BLUE}📦 检查Node.js依赖...${NC}"
cd $PROJECT_DIR
if [ ! -d "node_modules" ]; then
    echo "安装Node.js依赖..."
    npm install
fi

# 6. 测试证书配置
echo -e "${BLUE}🧪 测试SSL证书配置...${NC}"
openssl x509 -in $SSL_DIR/$CERT_LOCAL_PEM -text -noout | grep -E "(Subject:|Issuer:|Not Before:|Not After:)"

# 7. 配置防火墙
echo -e "${BLUE}🔥 配置防火墙规则...${NC}"
# 检查防火墙类型并配置
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

# 8. 使用PM2启动HTTPS服务器
echo -e "${BLUE}🚀 启动HTTPS服务器...${NC}"
if command -v pm2 &> /dev/null; then
    # 停止旧的服务
    pm2 delete english-learning-api 2>/dev/null || true
    
    # 启动新的HTTPS服务
    pm2 start server-https.js --name "english-learning-https" --env production
    pm2 startup
    pm2 save
    
    echo -e "${GREEN}✅ PM2服务启动完成${NC}"
else
    echo -e "${YELLOW}⚠️  PM2未安装，使用node直接启动...${NC}"
    nohup node server-https.js > server.log 2>&1 &
    echo -e "${GREEN}✅ 服务启动完成${NC}"
fi

# 9. 验证HTTPS服务
echo -e "${BLUE}🔍 验证HTTPS服务...${NC}"
sleep 3

# 检查端口是否开放
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

# 10. 输出重要信息
echo -e "\n${GREEN}🎉 SSL证书部署完成！${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📋 部署信息:${NC}"
echo -e "   🌐 域名: https://$DOMAIN"
echo -e "   🔒 SSL证书路径: $SSL_DIR/"
echo -e "   📁 项目路径: $PROJECT_DIR"
echo -e "   ⚙️  环境配置: $PROJECT_DIR/.env"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}🧪 测试命令:${NC}"
echo -e "   curl -k https://$DOMAIN/api/test"
echo -e "   curl http://$DOMAIN/api/test (应该重定向到HTTPS)"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📝 小程序配置:${NC}"
echo -e "   将请求域名改为: https://$DOMAIN"
echo -e "   在微信小程序管理后台配置服务器域名"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${GREEN}部署完成！您的小程序现在可以通过HTTPS访问API了！${NC}"

#!/bin/bash

# 环境检查脚本 - 检查现有部署环境
# 在运行SSL升级前使用此脚本检查环境状态

echo "🔍 检查现有部署环境..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
PROJECT_DIR="/www/english-learning-api"
DOMAIN="lengthwords.top"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📋 环境检查报告${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 1. 检查项目目录
echo -e "\n${BLUE}1. 项目目录检查${NC}"
if [ -d "$PROJECT_DIR" ]; then
    echo -e "   ✅ 项目目录存在: $PROJECT_DIR"
    
    # 检查关键文件
    files_check=()
    [ -f "$PROJECT_DIR/server.js" ] && files_check+=("✅ server.js") || files_check+=("❌ server.js")
    [ -f "$PROJECT_DIR/package.json" ] && files_check+=("✅ package.json") || files_check+=("❌ package.json")
    [ -f "$PROJECT_DIR/ecosystem.config.js" ] && files_check+=("✅ ecosystem.config.js") || files_check+=("❌ ecosystem.config.js")
    [ -d "$PROJECT_DIR/node_modules" ] && files_check+=("✅ node_modules") || files_check+=("❌ node_modules")
    
    for file_status in "${files_check[@]}"; do
        echo "   $file_status"
    done
else
    echo -e "   ❌ 项目目录不存在: $PROJECT_DIR"
fi

# 2. 检查Node.js环境
echo -e "\n${BLUE}2. Node.js环境检查${NC}"
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    echo -e "   ✅ Node.js版本: $NODE_VERSION"
else
    echo -e "   ❌ Node.js未安装"
fi

if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    echo -e "   ✅ NPM版本: $NPM_VERSION"
else
    echo -e "   ❌ NPM未安装"
fi

# 3. 检查PM2
echo -e "\n${BLUE}3. PM2进程管理检查${NC}"
if command -v pm2 &> /dev/null; then
    PM2_VERSION=$(pm2 --version)
    echo -e "   ✅ PM2版本: $PM2_VERSION"
    
    echo -e "   📊 当前PM2进程:"
    pm2 jlist 2>/dev/null | jq -r '.[] | "      \(.name): \(.pm2_env.status) (PID: \(.pid // "N/A"))"' 2>/dev/null || \
    pm2 status --no-colors | grep -E "(App name|english-learning)" | head -10
else
    echo -e "   ❌ PM2未安装"
fi

# 4. 检查端口占用
echo -e "\n${BLUE}4. 端口占用检查${NC}"
ports=(80 443 3000 8080)
for port in "${ports[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        process=$(netstat -tulnp 2>/dev/null | grep ":$port " | awk '{print $7}' | head -1)
        echo -e "   🔸 端口 $port: 已占用 ($process)"
    else
        echo -e "   ⚪ 端口 $port: 空闲"
    fi
done

# 5. 检查防火墙状态
echo -e "\n${BLUE}5. 防火墙状态检查${NC}"
if command -v ufw &> /dev/null; then
    echo -e "   🔥 防火墙类型: UFW"
    ufw_status=$(ufw status 2>/dev/null | head -1)
    echo -e "   📊 状态: $ufw_status"
    
    # 检查端口规则
    if ufw status 2>/dev/null | grep -q "80/tcp"; then
        echo -e "   ✅ 端口80已开放"
    else
        echo -e "   ❌ 端口80未开放"
    fi
    
    if ufw status 2>/dev/null | grep -q "443/tcp"; then
        echo -e "   ✅ 端口443已开放"
    else
        echo -e "   ❌ 端口443未开放"
    fi
elif command -v firewall-cmd &> /dev/null; then
    echo -e "   🔥 防火墙类型: FirewallD"
    firewall_status=$(firewall-cmd --state 2>/dev/null)
    echo -e "   📊 状态: $firewall_status"
    
    # 检查端口
    if firewall-cmd --list-ports 2>/dev/null | grep -q "80/tcp"; then
        echo -e "   ✅ 端口80已开放"
    else
        echo -e "   ❌ 端口80未开放"
    fi
    
    if firewall-cmd --list-ports 2>/dev/null | grep -q "443/tcp"; then
        echo -e "   ✅ 端口443已开放"
    else
        echo -e "   ❌ 端口443未开放"
    fi
else
    echo -e "   ⚠️  无法检测防火墙类型"
fi

# 6. 检查域名解析
echo -e "\n${BLUE}6. 域名解析检查${NC}"
if command -v dig &> /dev/null; then
    domain_ip=$(dig +short $DOMAIN 2>/dev/null | head -1)
    if [ -n "$domain_ip" ]; then
        echo -e "   ✅ 域名解析: $DOMAIN → $domain_ip"
        
        # 获取本机IP进行对比
        if command -v curl &> /dev/null; then
            local_ip=$(curl -s ipinfo.io/ip 2>/dev/null || curl -s ifconfig.me 2>/dev/null)
            if [ "$domain_ip" = "$local_ip" ]; then
                echo -e "   ✅ 域名指向本服务器"
            else
                echo -e "   ⚠️  域名未指向本服务器 (本机IP: $local_ip)"
            fi
        fi
    else
        echo -e "   ❌ 域名解析失败"
    fi
else
    echo -e "   ⚠️  dig命令不可用，无法检查域名解析"
fi

# 7. 检查SSL证书文件
echo -e "\n${BLUE}7. SSL证书文件检查${NC}"
ssl_files=("lengthwords.top.key" "lengthwords.top.pem")
all_ssl_present=true

for ssl_file in "${ssl_files[@]}"; do
    if [ -f "$ssl_file" ]; then
        echo -e "   ✅ $ssl_file 存在"
        
        # 检查文件大小
        file_size=$(stat -f%z "$ssl_file" 2>/dev/null || stat -c%s "$ssl_file" 2>/dev/null)
        if [ "$file_size" -gt 0 ]; then
            echo -e "      📏 文件大小: $file_size 字节"
        else
            echo -e "      ⚠️  文件为空"
        fi
    else
        echo -e "   ❌ $ssl_file 不存在"
        all_ssl_present=false
    fi
done

# 如果证书文件存在，验证证书
if [ -f "lengthwords.top.pem" ] && command -v openssl &> /dev/null; then
    echo -e "\n   🔍 证书信息验证:"
    cert_subject=$(openssl x509 -in lengthwords.top.pem -subject -noout 2>/dev/null | cut -d'=' -f2-)
    cert_issuer=$(openssl x509 -in lengthwords.top.pem -issuer -noout 2>/dev/null | cut -d'=' -f2-)
    cert_dates=$(openssl x509 -in lengthwords.top.pem -dates -noout 2>/dev/null)
    
    if [ -n "$cert_subject" ]; then
        echo -e "      📋 证书主体: $cert_subject"
        echo -e "      🏢 颁发机构: $cert_issuer"
        echo -e "      📅 有效期: $cert_dates"
    else
        echo -e "      ❌ 证书文件格式错误"
    fi
fi

# 8. 检查系统资源
echo -e "\n${BLUE}8. 系统资源检查${NC}"
if command -v free &> /dev/null; then
    memory_info=$(free -h | grep "Mem:" | awk '{print "使用: "$3"/"$2" (可用: "$7")"}')
    echo -e "   💾 内存: $memory_info"
fi

if command -v df &> /dev/null; then
    disk_info=$(df -h / | tail -1 | awk '{print "使用: "$3"/"$2" ("$5")"}')
    echo -e "   💿 磁盘: $disk_info"
fi

# 9. 生成升级建议
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📝 升级建议${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 检查必要条件
ready_for_upgrade=true

if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "❌ 项目目录不存在，请确认项目路径"
    ready_for_upgrade=false
fi

if ! command -v pm2 &> /dev/null; then
    echo -e "❌ 需要安装PM2: npm install -g pm2"
    ready_for_upgrade=false
fi

if [ "$all_ssl_present" = false ]; then
    echo -e "❌ 请准备SSL证书文件: lengthwords.top.key 和 lengthwords.top.pem"
    ready_for_upgrade=false
fi

if [ "$ready_for_upgrade" = true ]; then
    echo -e "✅ 环境检查通过，可以运行SSL升级脚本"
    echo -e ""
    echo -e "🚀 下一步操作:"
    echo -e "   1. 确保 lengthwords.top.key 和 lengthwords.top.pem 在当前目录"
    echo -e "   2. 确保 server-https.js 在当前目录"
    echo -e "   3. 运行: sudo ./upgrade-to-ssl.sh"
else
    echo -e "⚠️  环境检查发现问题，请先解决上述问题后再进行升级"
fi

echo -e "\n${GREEN}环境检查完成！${NC}"

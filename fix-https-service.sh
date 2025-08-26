#!/bin/bash

# HTTPS服务修复脚本
echo "🔧 诊断和修复HTTPS服务问题..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/www/english-learning-api"
DOMAIN="lengthwords.top"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}🔍 HTTPS服务诊断${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 1. 检查PM2服务状态
echo -e "\n${BLUE}1. PM2服务状态检查${NC}"
pm2 status

# 查找HTTPS相关服务
echo -e "\n   🔍 查找HTTPS服务:"
pm2 jlist 2>/dev/null | grep -i https || echo "   ❌ 未找到HTTPS服务"

# 2. 检查端口监听
echo -e "\n${BLUE}2. 端口监听检查${NC}"
echo -e "   📊 当前监听的端口:"
netstat -tuln | grep -E ":(80|443|8080|8443)" | while read line; do
    echo "      $line"
done

# 检查443端口是否被监听
if netstat -tuln | grep -q ":443 "; then
    echo -e "   ✅ 端口443正在监听"
    process=$(netstat -tulnp | grep ":443 " | awk '{print $7}' | head -1)
    echo -e "      进程: $process"
else
    echo -e "   ❌ 端口443未监听 - 这是问题所在！"
fi

# 3. 检查项目文件
echo -e "\n${BLUE}3. 项目文件检查${NC}"
cd $PROJECT_DIR

if [ -f "server-https.js" ]; then
    echo -e "   ✅ server-https.js 存在"
else
    echo -e "   ❌ server-https.js 不存在"
fi

if [ -f ".env" ]; then
    echo -e "   ✅ .env 配置文件存在"
    echo -e "   📋 环境变量内容:"
    grep -E "(SSL_|HTTPS_|HTTP_)" .env | sed 's/^/      /'
else
    echo -e "   ❌ .env 配置文件不存在"
fi

# 4. 检查SSL证书
echo -e "\n${BLUE}4. SSL证书检查${NC}"
ssl_dirs=("/etc/ssl/lengthwords" "/home/ssl")
cert_found=false

for ssl_dir in "${ssl_dirs[@]}"; do
    if [ -d "$ssl_dir" ]; then
        echo -e "   📁 SSL目录: $ssl_dir"
        if [ -f "$ssl_dir/lengthwords.top.key" ] && [ -f "$ssl_dir/lengthwords.top.pem" ]; then
            echo -e "      ✅ 证书文件完整"
            echo -e "         Key: $(ls -la $ssl_dir/lengthwords.top.key | awk '{print $1, $5}') bytes"
            echo -e "         Cert: $(ls -la $ssl_dir/lengthwords.top.pem | awk '{print $1, $5}') bytes"
            cert_found=true
            
            # 检查证书权限
            key_perm=$(stat -c "%a" "$ssl_dir/lengthwords.top.key" 2>/dev/null)
            cert_perm=$(stat -c "%a" "$ssl_dir/lengthwords.top.pem" 2>/dev/null)
            
            if [ "$key_perm" = "600" ]; then
                echo -e "      ✅ 私钥权限正确 (600)"
            else
                echo -e "      ⚠️  私钥权限: $key_perm (建议600)"
            fi
            
            if [ "$cert_perm" = "644" ]; then
                echo -e "      ✅ 证书权限正确 (644)"
            else
                echo -e "      ⚠️  证书权限: $cert_perm (建议644)"
            fi
        else
            echo -e "      ❌ 证书文件缺失"
        fi
    fi
done

if [ "$cert_found" = false ]; then
    echo -e "   ❌ 未找到SSL证书文件"
fi

# 5. 测试本地连接
echo -e "\n${BLUE}5. 本地连接测试${NC}"

# 测试HTTP
echo -e "   🧪 测试本地HTTP:"
if timeout 5 curl -s http://localhost/api/test > /dev/null 2>&1; then
    echo -e "      ✅ HTTP连接正常"
else
    echo -e "      ❌ HTTP连接失败"
fi

# 测试HTTPS
echo -e "   🧪 测试本地HTTPS:"
if timeout 5 curl -s -k https://localhost/api/test > /dev/null 2>&1; then
    echo -e "      ✅ HTTPS连接正常"
else
    echo -e "      ❌ HTTPS连接失败"
fi

# 6. 查看服务日志
echo -e "\n${BLUE}6. 服务日志检查${NC}"
echo -e "   📋 最近的错误日志:"

# 查找所有可能的HTTPS服务
for service_name in "english-learning-https" "english-api-80" "english-api-8080"; do
    if pm2 describe "$service_name" > /dev/null 2>&1; then
        echo -e "   📊 $service_name 服务日志:"
        pm2 logs "$service_name" --lines 5 --nostream 2>/dev/null | tail -10 | sed 's/^/      /'
    fi
done

# 7. 生成修复建议
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}💡 修复建议${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if ! netstat -tuln | grep -q ":443 "; then
    echo -e "\n❌ ${RED}主要问题: 端口443未监听${NC}"
    echo -e "   原因: HTTPS服务未正确启动"
    echo -e "   解决方案:"
    
    if [ ! -f "$PROJECT_DIR/server-https.js" ]; then
        echo -e "   1. 缺少server-https.js文件，需要上传"
    fi
    
    echo -e "   2. 启动HTTPS服务:"
    echo -e "      cd $PROJECT_DIR"
    echo -e "      pm2 start server-https.js --name english-learning-https --env production"
    
    if [ "$cert_found" = false ]; then
        echo -e "   3. 需要配置SSL证书文件"
    fi
fi

echo -e "\n🔧 ${GREEN}立即执行的修复命令${NC}:"
echo -e ""
echo -e "# 1. 进入项目目录"
echo -e "cd $PROJECT_DIR"
echo -e ""
echo -e "# 2. 检查server-https.js是否存在"
echo -e "ls -la server-https.js"
echo -e ""
echo -e "# 3. 如果存在，启动HTTPS服务"
echo -e "pm2 start server-https.js --name english-learning-https --env production"
echo -e ""
echo -e "# 4. 查看服务状态"
echo -e "pm2 status"
echo -e ""
echo -e "# 5. 查看HTTPS服务日志"
echo -e "pm2 logs english-learning-https"
echo -e ""
echo -e "# 6. 测试HTTPS连接"
echo -e "curl -k https://localhost/api/test"

echo -e "\n${GREEN}诊断完成！${NC}"

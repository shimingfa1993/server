#!/bin/bash

# 连接问题诊断脚本
echo "🔍 诊断HTTPS连接问题..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOMAIN="lengthwords.top"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}🔍 HTTPS连接问题诊断报告${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 1. 检查本地网络连通性
echo -e "\n${BLUE}1. 网络连通性检查${NC}"
ping -c 2 8.8.8.8 > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "   ✅ 外网连通正常"
else
    echo -e "   ❌ 外网连通异常"
fi

# 2. 检查域名解析
echo -e "\n${BLUE}2. 域名解析检查${NC}"

# 使用nslookup
if command -v nslookup &> /dev/null; then
    echo -e "   📡 使用nslookup查询:"
    nslookup_result=$(nslookup $DOMAIN 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')
    if [ -n "$nslookup_result" ]; then
        echo -e "      ✅ nslookup: $DOMAIN → $nslookup_result"
    else
        echo -e "      ❌ nslookup解析失败"
    fi
fi

# 使用dig
if command -v dig &> /dev/null; then
    echo -e "   📡 使用dig查询:"
    dig_result=$(dig +short $DOMAIN 2>/dev/null | head -1)
    if [ -n "$dig_result" ]; then
        echo -e "      ✅ dig: $DOMAIN → $dig_result"
    else
        echo -e "      ❌ dig解析失败"
    fi
fi

# 使用host
if command -v host &> /dev/null; then
    echo -e "   📡 使用host查询:"
    host_result=$(host $DOMAIN 2>/dev/null | grep "has address" | awk '{print $4}' | head -1)
    if [ -n "$host_result" ]; then
        echo -e "      ✅ host: $DOMAIN → $host_result"
    else
        echo -e "      ❌ host解析失败"
    fi
fi

# 3. 检查本机IP
echo -e "\n${BLUE}3. 本机IP检查${NC}"
if command -v curl &> /dev/null; then
    local_ip=$(curl -s --connect-timeout 5 ipinfo.io/ip 2>/dev/null || curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || curl -s --connect-timeout 5 ip.sb 2>/dev/null)
    if [ -n "$local_ip" ]; then
        echo -e "   🌐 本机公网IP: $local_ip"
        
        # 比较域名解析IP和本机IP
        if [ -n "$dig_result" ]; then
            if [ "$dig_result" = "$local_ip" ]; then
                echo -e "   ✅ 域名解析IP与本机IP一致"
            else
                echo -e "   ❌ 域名解析IP($dig_result) 与本机IP($local_ip) 不一致"
                echo -e "      💡 建议: 在阿里云域名解析中将A记录指向 $local_ip"
            fi
        fi
    else
        echo -e "   ❌ 无法获取本机公网IP"
    fi
fi

# 4. 检查端口监听
echo -e "\n${BLUE}4. 端口监听检查${NC}"
ports=(80 443)
for port in "${ports[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        process=$(netstat -tulnp 2>/dev/null | grep ":$port " | awk '{print $7}' | head -1 | cut -d'/' -f2)
        echo -e "   ✅ 端口 $port 正在监听 (进程: $process)"
    else
        echo -e "   ❌ 端口 $port 未监听"
    fi
done

# 5. 检查防火墙规则
echo -e "\n${BLUE}5. 防火墙检查${NC}"
if command -v ufw &> /dev/null; then
    ufw_status=$(ufw status 2>/dev/null)
    echo -e "   🔥 UFW状态:"
    echo "$ufw_status" | head -5 | sed 's/^/      /'
    
    if echo "$ufw_status" | grep -q "80/tcp.*ALLOW"; then
        echo -e "   ✅ UFW允许端口80"
    else
        echo -e "   ❌ UFW未开放端口80"
        echo -e "      💡 解决: sudo ufw allow 80/tcp"
    fi
    
    if echo "$ufw_status" | grep -q "443/tcp.*ALLOW"; then
        echo -e "   ✅ UFW允许端口443"
    else
        echo -e "   ❌ UFW未开放端口443"
        echo -e "      💡 解决: sudo ufw allow 443/tcp"
    fi
elif command -v firewall-cmd &> /dev/null; then
    echo -e "   🔥 FirewallD状态: $(firewall-cmd --state 2>/dev/null)"
    
    if firewall-cmd --list-ports 2>/dev/null | grep -q "80/tcp"; then
        echo -e "   ✅ FirewallD允许端口80"
    else
        echo -e "   ❌ FirewallD未开放端口80"
        echo -e "      💡 解决: sudo firewall-cmd --permanent --add-port=80/tcp && sudo firewall-cmd --reload"
    fi
    
    if firewall-cmd --list-ports 2>/dev/null | grep -q "443/tcp"; then
        echo -e "   ✅ FirewallD允许端口443"
    else
        echo -e "   ❌ FirewallD未开放端口443"
        echo -e "      💡 解决: sudo firewall-cmd --permanent --add-port=443/tcp && sudo firewall-cmd --reload"
    fi
else
    echo -e "   ⚠️  无法检测防火墙状态"
fi

# 6. 测试本地连接
echo -e "\n${BLUE}6. 本地连接测试${NC}"

# 测试本地HTTP
if curl -s --connect-timeout 5 http://localhost/api/test > /dev/null 2>&1; then
    echo -e "   ✅ 本地HTTP连接正常"
else
    echo -e "   ❌ 本地HTTP连接失败"
fi

# 测试本地HTTPS
if curl -s -k --connect-timeout 5 https://localhost/api/test > /dev/null 2>&1; then
    echo -e "   ✅ 本地HTTPS连接正常"
else
    echo -e "   ❌ 本地HTTPS连接失败"
fi

# 7. 检查SSL证书
echo -e "\n${BLUE}7. SSL证书检查${NC}"
ssl_paths=("/etc/ssl/lengthwords" "/home/ssl")
cert_found=false

for ssl_path in "${ssl_paths[@]}"; do
    if [ -f "$ssl_path/lengthwords.top.pem" ]; then
        echo -e "   ✅ 证书文件存在: $ssl_path/lengthwords.top.pem"
        cert_found=true
        
        # 检查证书有效期
        if command -v openssl &> /dev/null; then
            cert_info=$(openssl x509 -in "$ssl_path/lengthwords.top.pem" -dates -noout 2>/dev/null)
            if [ -n "$cert_info" ]; then
                echo -e "      📅 证书有效期:"
                echo "$cert_info" | sed 's/^/         /'
            fi
        fi
        break
    fi
done

if [ "$cert_found" = false ]; then
    echo -e "   ❌ 未找到SSL证书文件"
fi

# 8. 检查DNS配置
echo -e "\n${BLUE}8. DNS配置检查${NC}"
echo -e "   📋 当前DNS服务器:"
if [ -f "/etc/resolv.conf" ]; then
    grep "nameserver" /etc/resolv.conf | head -3 | sed 's/^/      /'
fi

# 测试不同DNS服务器的解析
dns_servers=("8.8.8.8" "1.1.1.1" "223.5.5.5")
echo -e "   🧪 测试不同DNS解析:"
for dns in "${dns_servers[@]}"; do
    if command -v nslookup &> /dev/null; then
        result=$(nslookup $DOMAIN $dns 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')
        if [ -n "$result" ]; then
            echo -e "      ✅ DNS $dns: $DOMAIN → $result"
        else
            echo -e "      ❌ DNS $dns: 解析失败"
        fi
    fi
done

# 9. 生成解决方案
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}💡 问题分析和解决方案${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 根据检查结果提供解决方案
echo -e "\n基于检查结果，可能的问题和解决方案:"

if [ -z "$dig_result" ]; then
    echo -e "\n❌ ${RED}域名解析问题${NC}"
    echo -e "   问题: 域名 $DOMAIN 无法解析"
    echo -e "   解决: 在阿里云域名管理中配置A记录"
    echo -e "   步骤:"
    echo -e "     1. 登录阿里云控制台"
    echo -e "     2. 进入域名管理 → DNS解析"
    echo -e "     3. 添加A记录: $DOMAIN → $local_ip"
elif [ -n "$local_ip" ] && [ "$dig_result" != "$local_ip" ]; then
    echo -e "\n⚠️  ${YELLOW}域名指向问题${NC}"
    echo -e "   问题: 域名指向IP($dig_result) 与服务器IP($local_ip) 不匹配"
    echo -e "   解决: 更新域名A记录指向正确的服务器IP"
fi

if ! netstat -tuln 2>/dev/null | grep -q ":443 "; then
    echo -e "\n❌ ${RED}HTTPS端口未监听${NC}"
    echo -e "   问题: 端口443未开启监听"
    echo -e "   解决: 启动HTTPS服务"
    echo -e "     pm2 start english-learning-https"
fi

echo -e "\n🔧 ${GREEN}快速修复命令${NC}:"
echo -e "   # 重启HTTPS服务"
echo -e "   pm2 restart english-learning-https"
echo -e ""
echo -e "   # 开放防火墙端口"
echo -e "   sudo ufw allow 80/tcp"
echo -e "   sudo ufw allow 443/tcp"
echo -e ""
echo -e "   # 测试本地连接"
echo -e "   curl -k https://localhost/api/test"

echo -e "\n${GREEN}诊断完成！${NC}"

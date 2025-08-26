# SSL证书部署指南 - lengthwords.top

本指南详细说明如何在阿里云ECS服务器上部署SSL证书，让小程序能够通过HTTPS访问您的Node.js后端API。

## 📋 前置准备

### 1. 阿里云SSL证书
- ✅ 已申请域名 `lengthwords.top` 的SSL证书
- ✅ 已下载证书文件：
  - `lengthwords.top.key` (私钥文件)
  - `lengthwords.top.pem` (证书文件)

### 2. 服务器要求
- 阿里云ECS实例
- 已安装Node.js (建议v16+)
- 已安装PM2 (可选，用于进程管理)
- Root权限或sudo权限

## 🚀 快速部署

### 方法一：自动部署脚本 (推荐)

1. **上传文件到服务器**
```bash
# 在服务器上创建项目目录
sudo mkdir -p /home/english-learning
cd /home/english-learning

# 上传您的项目文件和SSL证书
# 包括：server-https.js, package.json, deploy-ssl.sh, lengthwords.top.key, lengthwords.top.pem
```

2. **运行部署脚本**
```bash
# 给脚本执行权限
chmod +x deploy-ssl.sh

# 运行部署脚本
sudo ./deploy-ssl.sh
```

### 方法二：手动部署

#### 步骤1：创建SSL证书目录
```bash
sudo mkdir -p /home/ssl
sudo chmod 700 /home/ssl
```

#### 步骤2：复制SSL证书文件
```bash
# 复制证书文件到SSL目录
sudo cp lengthwords.top.key /home/ssl/
sudo cp lengthwords.top.pem /home/ssl/

# 设置合适的权限
sudo chmod 600 /home/ssl/lengthwords.top.key
sudo chmod 644 /home/ssl/lengthwords.top.pem
```

#### 步骤3：创建环境配置文件
```bash
# 在项目目录创建.env文件
cat > /home/english-learning/.env << 'EOF'
NODE_ENV=production
HTTP_PORT=80
HTTPS_PORT=443
JWT_SECRET=your-super-secret-jwt-key-change-this
SSL_KEY_PATH=/home/ssl/lengthwords.top.key
SSL_CERT_PATH=/home/ssl/lengthwords.top.pem
DB_PATH=./learning.db
LOG_LEVEL=info
EOF
```

#### 步骤4：安装依赖并启动服务
```bash
cd /home/english-learning

# 安装依赖
npm install

# 使用PM2启动HTTPS服务器
pm2 start server-https.js --name "english-learning-https" --env production
pm2 startup
pm2 save
```

#### 步骤5：配置防火墙
```bash
# Ubuntu/Debian
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload
```

## 🔍 验证部署

### 1. 检查服务状态
```bash
# 检查PM2进程
pm2 status

# 检查端口监听
sudo netstat -tuln | grep -E "(80|443)"

# 查看服务日志
pm2 logs english-learning-https
```

### 2. 测试HTTPS连接
```bash
# 测试HTTPS API
curl -k https://lengthwords.top/api/test

# 测试HTTP重定向
curl -i http://lengthwords.top/api/test
```

### 3. 预期响应
HTTPS请求应该返回：
```json
{
  "message": "🎉 HTTPS服务器运行正常！",
  "timestamp": "2024-01-20T10:30:00.000Z",
  "server": "English Learning API with SSL",
  "protocol": "HTTPS",
  "host": "lengthwords.top",
  "availableRoutes": [...]
}
```

## 📱 小程序配置

### 1. 修改小程序API请求域名
将您的小程序中的API请求地址改为：
```javascript
const API_BASE_URL = 'https://lengthwords.top';
```

### 2. 微信小程序管理后台配置
1. 登录微信小程序管理后台
2. 进入 `开发` -> `开发管理` -> `开发设置`
3. 在 `服务器域名` 中添加：
   - request合法域名：`https://lengthwords.top`

## 🛠️ 常见问题解决

### Q1: 证书文件权限错误
```bash
# 重新设置证书文件权限
sudo chmod 600 /home/ssl/lengthwords.top.key
sudo chmod 644 /home/ssl/lengthwords.top.pem
sudo chown root:root /home/ssl/*
```

### Q2: 端口被占用
```bash
# 查看端口占用
sudo lsof -i :443
sudo lsof -i :80

# 停止占用端口的进程
sudo kill -9 <PID>
```

### Q3: 防火墙问题
```bash
# 阿里云安全组配置
# 1. 登录阿里云控制台
# 2. 进入ECS实例 -> 安全组
# 3. 添加规则：允许入方向 80/tcp 和 443/tcp
```

### Q4: SSL证书过期
```bash
# 检查证书有效期
openssl x509 -in /home/ssl/lengthwords.top.pem -text -noout | grep -A2 "Validity"

# 重新下载新证书并替换文件
sudo cp new-lengthwords.top.key /home/ssl/lengthwords.top.key
sudo cp new-lengthwords.top.pem /home/ssl/lengthwords.top.pem

# 重启服务
pm2 restart english-learning-https
```

## 📊 监控和维护

### 日志监控
```bash
# 查看实时日志
pm2 logs english-learning-https --lines 100

# 查看错误日志
pm2 logs english-learning-https --err

# 重启服务
pm2 restart english-learning-https
```

### 自动备份SSL证书
```bash
# 创建备份脚本
cat > /home/backup-ssl.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/home/ssl-backup/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR
cp /home/ssl/* $BACKUP_DIR/
echo "SSL证书备份完成: $BACKUP_DIR"
EOF

chmod +x /home/backup-ssl.sh

# 添加到定时任务（每月1号备份）
echo "0 0 1 * * /home/backup-ssl.sh" | sudo crontab -
```

## 🎯 小程序API测试

部署完成后，您的小程序可以使用以下HTTPS API：

```javascript
// 小程序中的API调用示例
const apiRequest = (url, data = {}, method = 'GET') => {
  return new Promise((resolve, reject) => {
    wx.request({
      url: `https://lengthwords.top/api${url}`,
      method,
      data,
      header: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${wx.getStorageSync('token')}`
      },
      success: resolve,
      fail: reject
    });
  });
};

// 测试连接
apiRequest('/test').then(res => {
  console.log('API连接成功:', res.data);
}).catch(err => {
  console.error('API连接失败:', err);
});
```

## 📝 总结

完成以上步骤后，您的英语学习小程序后端已经成功部署SSL证书，支持HTTPS访问。主要特性：

- ✅ HTTPS安全连接
- ✅ 自动HTTP到HTTPS重定向
- ✅ 小程序兼容的API接口
- ✅ PM2进程管理
- ✅ 完整的错误处理和日志

如遇到问题，请检查：
1. 阿里云安全组配置
2. 服务器防火墙设置
3. SSL证书文件路径和权限
4. 域名DNS解析配置

祝您部署顺利！🎉

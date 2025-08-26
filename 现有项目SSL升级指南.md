# 现有项目SSL升级指南 🔄

基于您在 `/www/english-learning-api` 的现有部署，这是一个简化的SSL升级方案。

## 📋 当前环境分析

- ✅ 项目已部署在: `/www/english-learning-api`
- ✅ 使用PM2进行进程管理
- ✅ 已有完整的Node.js环境
- 🔄 需要: 添加HTTPS支持

## 🚀 快速升级步骤

### 第1步：准备SSL证书文件

将您从阿里云下载的SSL证书文件准备好：
- `lengthwords.top.key` (私钥文件)
- `lengthwords.top.pem` (证书文件)

### 第2步：上传升级文件

将以下文件上传到您的服务器任意目录（比如 `/tmp/ssl-upgrade/`）：
```
server-https.js           # HTTPS服务器文件
upgrade-to-ssl.sh         # 自动升级脚本
lengthwords.top.key       # SSL私钥
lengthwords.top.pem       # SSL证书
```

### 第3步：运行升级脚本

```bash
# SSH连接到您的阿里云服务器
ssh root@your-server-ip

# 进入上传文件的目录
cd /tmp/ssl-upgrade/

# 给脚本执行权限
chmod +x upgrade-to-ssl.sh

# 运行升级脚本
./upgrade-to-ssl.sh
```

## 🔧 升级脚本功能

这个升级脚本会自动完成以下操作：

1. **🔒 安全备份**: 备份现有配置文件到时间戳目录
2. **📁 创建SSL目录**: 在 `/etc/ssl/lengthwords/` 安装证书
3. **⚙️ 更新配置**: 
   - 生成 `.env` 环境配置
   - 更新 `package.json` 添加HTTPS脚本
   - 更新 `ecosystem.config.js` 支持HTTPS服务
4. **🚀 部署HTTPS服务**: 
   - 复制 `server-https.js` 到项目目录
   - 启动新的HTTPS服务
   - 保持原HTTP服务作为内部服务
5. **🔥 配置防火墙**: 自动开放80和443端口
6. **✅ 验证部署**: 检查服务状态和端口监听

## 📱 小程序配置更新

升级完成后，更新您的小程序API请求：

```javascript
// 原来的请求地址
// const API_BASE_URL = 'http://your-server-ip:3000';

// 更新为HTTPS地址
const API_BASE_URL = 'https://lengthwords.top';

// 示例API调用
wx.request({
  url: `${API_BASE_URL}/api/test`,
  method: 'GET',
  success: (res) => {
    console.log('HTTPS连接成功:', res.data);
  }
});
```

## 🔍 验证升级结果

升级完成后，运行以下命令验证：

```bash
# 1. 检查PM2服务状态
pm2 status

# 2. 测试HTTPS API
curl -k https://lengthwords.top/api/test

# 3. 测试HTTP重定向
curl -i http://lengthwords.top/api/test

# 4. 查看HTTPS服务日志
pm2 logs english-learning-https
```

预期结果：
- ✅ PM2显示两个服务：`english-learning-api` 和 `english-learning-https`
- ✅ HTTPS API返回成功响应
- ✅ HTTP请求自动重定向到HTTPS
- ✅ 日志显示正常运行

## 🛠️ 管理命令

升级后的常用管理命令：

```bash
# HTTPS服务管理
pm2 restart english-learning-https    # 重启HTTPS服务
pm2 stop english-learning-https       # 停止HTTPS服务  
pm2 logs english-learning-https       # 查看HTTPS日志

# 原HTTP服务管理（内部使用）
pm2 restart english-learning-api      # 重启HTTP服务
pm2 logs english-learning-api         # 查看HTTP日志

# 查看所有服务
pm2 status                            # 服务状态总览
```

## ⚠️ 重要提醒

### 1. 微信小程序配置
升级完成后，记得在微信小程序管理后台添加服务器域名：
- 登录微信小程序管理后台
- 进入 `开发` → `开发管理` → `开发设置`
- 在 `服务器域名` 中添加：`https://lengthwords.top`

### 2. 阿里云安全组配置
确保阿里云ECS安全组已开放：
- 入方向：80/tcp (HTTP)
- 入方向：443/tcp (HTTPS)

### 3. 域名解析
确认域名 `lengthwords.top` 已正确解析到您的服务器IP。

## 🔄 回滚方案

如果升级出现问题，可以快速回滚：

```bash
# 停止HTTPS服务
pm2 stop english-learning-https
pm2 delete english-learning-https

# 恢复原配置（如果需要）
cd /www/english-learning-api
cp backup-*/server.js ./
cp backup-*/ecosystem.config.js ./

# 重启原服务
pm2 restart english-learning-api
```

## 📞 故障排除

### 常见问题

1. **证书文件权限错误**
```bash
sudo chmod 600 /etc/ssl/lengthwords/lengthwords.top.key
sudo chmod 644 /etc/ssl/lengthwords/lengthwords.top.pem
```

2. **端口被占用**
```bash
sudo lsof -i :443
sudo kill -9 <PID>
```

3. **服务启动失败**
```bash
pm2 logs english-learning-https --err
```

4. **防火墙问题**
```bash
sudo ufw status
sudo ufw allow 443/tcp
```

## 🎯 升级优势

完成升级后，您将获得：

- ✅ **安全的HTTPS连接**: 数据传输加密保护
- ✅ **小程序兼容**: 满足微信小程序HTTPS要求
- ✅ **自动重定向**: HTTP自动跳转到HTTPS
- ✅ **双重保障**: HTTP和HTTPS服务并存
- ✅ **生产就绪**: 完整的日志和监控
- ✅ **易于管理**: PM2进程管理和自动重启

---

🎉 **准备好了吗？运行升级脚本，让您的英语学习小程序支持安全的HTTPS访问！**

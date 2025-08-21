# English Learning Backend Server

## 🚀 快速开始

### 环境要求
- Node.js >= 14.0.0
- npm >= 6.0.0
- PM2 (生产环境)

### 本地开发

1. 克隆仓库并进入目录：
```bash
git clone your-repository-url
cd your-repository/@server
```

2. 安装依赖：
```bash
npm install
```

3. 配置环境变量：
```bash
cp .env.example .env
# 编辑 .env 文件，设置您的配置
```

4. 启动开发服务器：
```bash
npm run dev
```

5. 启动生产服务器：
```bash
npm start
```

### 生产环境部署

#### 方法一：Git 自动部署（推荐）

```bash
# 在服务器上执行
wget https://raw.githubusercontent.com/your-username/your-repo/main/@server/deploy-from-git.sh
chmod +x deploy-from-git.sh
./deploy-from-git.sh
```

#### 方法二：手动部署

```bash
# 1. 上传代码到服务器
scp -r @server root@your-server:/www/english-learning-api

# 2. 在服务器上执行
cd /www/english-learning-api
npm install --production
pm2 start ecosystem.config.js --env production
```

### 环境变量配置

复制 `.env.example` 为 `.env` 并配置：
```
PORT=3000
JWT_SECRET=your-super-secret-jwt-key-here
NODE_ENV=production
DB_PATH=./learning.db
CORS_ORIGIN=*
```

### API 接口

- GET `/api/test` - 服务器健康检查
- POST `/api/register` - 用户注册
- POST `/api/login` - 用户登录
- GET `/api/learning/stats` - 获取学习统计
- POST `/api/learning/record` - 记录学习
- GET `/api/learning/review-words` - 获取复习单词
- POST `/api/learning/review-result` - 提交复习结果

### 数据库

使用 SQLite 数据库，文件：`learning.db`

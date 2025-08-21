# English Learning Backend Server

## 🚀 快速开始

### 环境要求
- Node.js >= 14.0.0
- npm >= 6.0.0

### 本地开发

1. 安装依赖：
```bash
cd @server
npm install
```

2. 启动开发服务器：
```bash
npm run dev
```

3. 启动生产服务器：
```bash
npm start
```

### 环境变量配置

创建 `.env` 文件：
```
PORT=3000
JWT_SECRET=your-super-secret-jwt-key-here
NODE_ENV=production
DB_PATH=./learning.db
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

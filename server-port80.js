const express = require('express');
const cors = require('cors');

const app = express();
const PORT = 80; // 使用80端口

// 中间件 - 超宽松的 CORS 配置
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
  credentials: true
}));

app.use(express.json());

// 手动处理 OPTIONS 请求
app.options('*', (req, res) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept');
  res.status(200).send();
});

// 请求日志中间件
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  console.log('请求头:', req.headers);
  next();
});

// 测试接口
app.get('/api/test', (req, res) => {
  console.log('收到测试请求');
  res.json({
    message: '🎉 80端口服务器运行正常！',
    timestamp: new Date().toISOString(),
    server: 'English Learning API (80端口版)',
    status: 'OK',
    port: PORT
  });
});

// 启动服务器
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 80端口服务器启动成功！`);
  console.log(`📍 端口: ${PORT}`);
  console.log(`🌐 监听地址: 0.0.0.0:${PORT}`);
  console.log(`🔗 测试地址: http://172.24.214.5/api/test`);
  console.log(`📊 状态: 运行中...`);
});

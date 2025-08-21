const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

// 中间件 - 更宽松的 CORS 配置
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

// 内存存储（临时用于测试）
let users = [];
let currentUserId = 1;

// 测试路由
app.get('/api/test', (req, res) => {
  res.json({ 
    message: '🎉 服务器运行正常！', 
    timestamp: new Date().toISOString(),
    server: 'English Learning API (简化版)',
    status: 'OK'
  });
});

// 添加请求日志中间件
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
  console.log('Headers:', req.headers);
  console.log('Body:', req.body);
  next();
});

// 用户注册（简化版，不加密密码）
app.post('/api/register', (req, res) => {
  const { username, password } = req.body;
  
  if (!username || !password) {
    return res.status(400).json({ error: '用户名和密码不能为空' });
  }
  
  // 检查用户是否已存在
  const existingUser = users.find(user => user.username === username);
  if (existingUser) {
    return res.status(400).json({ error: '用户名已存在' });
  }
  
  // 创建新用户
  const newUser = {
    id: currentUserId++,
    username: username,
    password: password, // 简化版直接存储，实际应该加密
    createdAt: new Date().toISOString()
  };
  
  users.push(newUser);
  
  res.json({ 
    message: '注册成功',
    userId: newUser.id,
    token: `simple-token-${newUser.id}` // 简化版token
  });
});

// 用户登录（简化版）
app.post('/api/login', (req, res) => {
  const { username, password } = req.body;
  
  if (!username || !password) {
    return res.status(400).json({ error: '用户名和密码不能为空' });
  }
  
  const user = users.find(u => u.username === username && u.password === password);
  
  if (!user) {
    return res.status(400).json({ error: '用户名或密码错误' });
  }
  
  res.json({ 
    message: '登录成功',
    userId: user.id,
    token: `simple-token-${user.id}`
  });
});

// 简单的认证中间件
const simpleAuth = (req, res, next) => {
  const token = req.headers.authorization;
  
  if (!token || !token.startsWith('simple-token-')) {
    return res.status(401).json({ error: '需要登录' });
  }
  
  const userId = parseInt(token.replace('simple-token-', ''));
  const user = users.find(u => u.id === userId);
  
  if (!user) {
    return res.status(403).json({ error: '无效token' });
  }
  
  req.userId = userId;
  next();
};

// 获取学习统计（简化版）
app.get('/api/learning/stats', simpleAuth, (req, res) => {
  res.json({
    totalWords: 0,
    todayLearned: 0,
    todayTarget: 10,
    todayProgress: 0,
    learningStreak: 0,
    reviewCount: 0,
    message: '这是简化版本，数据为模拟数据'
  });
});

// 记录学习（简化版）
app.post('/api/learning/record', simpleAuth, (req, res) => {
  const { word, difficulty = 'normal' } = req.body;
  
  if (!word) {
    return res.status(400).json({ error: '单词不能为空' });
  }
  
  console.log(`用户 ${req.userId} 学习了单词: ${word}, 难度: ${difficulty}`);
  
  res.json({ 
    message: '学习记录成功（简化版）',
    word: word,
    difficulty: difficulty
  });
});

// 获取复习单词（简化版）
app.get('/api/learning/review-words', simpleAuth, (req, res) => {
  const mockWords = [
    { word: 'hello', difficulty: 'easy', review_count: 1 },
    { word: 'world', difficulty: 'easy', review_count: 2 },
    { word: 'javascript', difficulty: 'medium', review_count: 1 }
  ];
  
  res.json({
    words: mockWords,
    count: mockWords.length,
    message: '这是简化版本，返回模拟数据'
  });
});

// 记录复习结果（简化版）
app.post('/api/learning/review-result', simpleAuth, (req, res) => {
  const { word, isCorrect } = req.body;
  
  if (!word || typeof isCorrect !== 'boolean') {
    return res.status(400).json({ error: '参数不正确' });
  }
  
  console.log(`用户 ${req.userId} 复习单词 ${word}: ${isCorrect ? '正确' : '错误'}`);
  
  res.json({ 
    message: '复习结果记录成功（简化版）',
    word: word,
    result: isCorrect ? '正确' : '错误'
  });
});

// 健康检查
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage()
  });
});

// 错误处理中间件
app.use((err, req, res, next) => {
  console.error('错误:', err);
  res.status(500).json({ error: '服务器内部错误' });
});

// 404 处理
app.use('*', (req, res) => {
  res.status(404).json({ error: '接口不存在' });
});

// 启动服务器
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 简化版服务器启动成功！`);
  console.log(`📍 端口: ${PORT}`);
  console.log(`🌐 监听地址: 0.0.0.0:${PORT}`);
  console.log(`🔗 本地测试: http://localhost:${PORT}/api/test`);
  console.log(`🔗 外网访问: http://172.24.214.5:${PORT}/api/test`);
  console.log(`💡 这是简化版本，不使用数据库`);
  console.log(`📊 状态: 运行中...`);
});

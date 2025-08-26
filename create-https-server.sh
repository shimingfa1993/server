#!/bin/bash

# 创建server-https.js文件到服务器
echo "🔧 创建server-https.js文件..."

PROJECT_DIR="/www/english-learning-api"
cd $PROJECT_DIR

# 创建server-https.js文件
cat > server-https.js << 'EOF'
const express = require('express');
const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');
const cors = require('cors');
const sqlite3 = require('sqlite3').verbose();
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

// 加载环境变量
try {
  require('dotenv').config();
} catch (e) {
  console.log('dotenv not found, using default values');
}

const app = express();
const HTTP_PORT = process.env.HTTP_PORT || 80;
const HTTPS_PORT = process.env.HTTPS_PORT || 443;
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

// SSL证书路径
const SSL_KEY_PATH = process.env.SSL_KEY_PATH || '/etc/ssl/lengthwords/lengthwords.top.key';
const SSL_CERT_PATH = process.env.SSL_CERT_PATH || '/etc/ssl/lengthwords/lengthwords.top.pem';

// 中间件
app.use(cors({
  origin: ['https://lengthwords.top', 'https://www.lengthwords.top', 'http://localhost:3000'],
  credentials: true
}));
app.use(express.json());

// 强制HTTPS重定向中间件
const forceHTTPS = (req, res, next) => {
  if (!req.secure && req.get('x-forwarded-proto') !== 'https') {
    return res.redirect(301, `https://${req.get('host')}${req.url}`);
  }
  next();
};

// 在生产环境中使用HTTPS重定向
if (process.env.NODE_ENV === 'production') {
  app.use(forceHTTPS);
}

// 初始化数据库
const db = new sqlite3.Database('learning.db');

// 创建表
db.serialize(() => {
  // 用户表
  db.run(`CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE,
    password TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);
  
  // 学习进度表
  db.run(`CREATE TABLE IF NOT EXISTS user_progress (
    user_id INTEGER PRIMARY KEY,
    total_words INTEGER DEFAULT 0,
    today_learned INTEGER DEFAULT 0,
    learning_streak INTEGER DEFAULT 0,
    last_study_date DATE,
    daily_target INTEGER DEFAULT 10,
    FOREIGN KEY (user_id) REFERENCES users (id)
  )`);
  
  // 学习记录表
  db.run(`CREATE TABLE IF NOT EXISTS learning_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    word TEXT,
    learned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    difficulty TEXT DEFAULT 'normal',
    review_count INTEGER DEFAULT 0,
    correct_count INTEGER DEFAULT 0,
    next_review_at DATETIME,
    FOREIGN KEY (user_id) REFERENCES users (id)
  )`);
});

// 测试路由
app.get('/api/test', (req, res) => {
  res.json({ 
    message: '🎉 HTTPS服务器运行正常！', 
    timestamp: new Date().toISOString(),
    server: 'English Learning API with SSL',
    protocol: req.secure ? 'HTTPS' : 'HTTP',
    host: req.get('host'),
    availableRoutes: [
      'POST /api/register',
      'POST /api/login', 
      'GET /api/learning/stats (需要认证)',
      'POST /api/learning/record (需要认证)',
      'GET /api/learning/review-words (需要认证)',
      'POST /api/learning/review-result (需要认证)'
    ]
  });
});

// 用户注册
app.post('/api/register', async (req, res) => {
  const { username, password } = req.body;
  
  if (!username || !password) {
    return res.status(400).json({ error: '用户名和密码不能为空' });
  }
  
  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    
    db.run('INSERT INTO users (username, password) VALUES (?, ?)', 
      [username, hashedPassword], 
      function(err) {
        if (err) {
          return res.status(400).json({ error: '用户名已存在' });
        }
        
        // 创建初始进度记录
        db.run('INSERT INTO user_progress (user_id) VALUES (?)', [this.lastID]);
        
        const token = jwt.sign({ userId: this.lastID }, JWT_SECRET);
        res.json({ token, userId: this.lastID, message: '注册成功' });
      }
    );
  } catch (error) {
    console.error('注册错误:', error);
    res.status(500).json({ error: '注册失败' });
  }
});

// 用户登录
app.post('/api/login', (req, res) => {
  const { username, password } = req.body;
  
  if (!username || !password) {
    return res.status(400).json({ error: '用户名和密码不能为空' });
  }
  
  db.get('SELECT * FROM users WHERE username = ?', [username], async (err, user) => {
    if (err || !user) {
      return res.status(400).json({ error: '用户不存在' });
    }
    
    try {
      const validPassword = await bcrypt.compare(password, user.password);
      if (!validPassword) {
        return res.status(400).json({ error: '密码错误' });
      }
      
      const token = jwt.sign({ userId: user.id }, JWT_SECRET);
      res.json({ token, userId: user.id, message: '登录成功' });
    } catch (error) {
      console.error('登录错误:', error);
      res.status(500).json({ error: '登录失败' });
    }
  });
});

// 认证中间件
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ error: '需要登录' });
  }
  
  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: '无效token' });
    }
    req.userId = user.userId;
    next();
  });
};

// 获取学习统计
app.get('/api/learning/stats', authenticateToken, (req, res) => {
  const userId = req.userId;
  
  const query = `
    SELECT 
      up.*,
      COUNT(lr.id) as review_count
    FROM user_progress up
    LEFT JOIN learning_records lr ON up.user_id = lr.user_id 
      AND lr.next_review_at <= datetime('now')
    WHERE up.user_id = ?
    GROUP BY up.user_id
  `;
  
  db.get(query, [userId], (err, row) => {
    if (err) {
      console.error('获取统计错误:', err);
      return res.status(500).json({ error: '获取统计失败' });
    }
    
    if (!row) {
      return res.json({
        totalWords: 0,
        todayLearned: 0,
        todayTarget: 10,
        todayProgress: 0,
        learningStreak: 0,
        reviewCount: 0
      });
    }
    
    const todayProgress = Math.min((row.today_learned / row.daily_target) * 100, 100);
    
    res.json({
      totalWords: row.total_words,
      todayLearned: row.today_learned,
      todayTarget: row.daily_target,
      todayProgress: todayProgress,
      learningStreak: row.learning_streak,
      reviewCount: row.review_count || 0
    });
  });
});

// 记录学习进度
app.post('/api/learning/record', authenticateToken, (req, res) => {
  const userId = req.userId;
  const { word, difficulty = 'normal' } = req.body;
  
  if (!word) {
    return res.status(400).json({ error: '单词不能为空' });
  }
  
  const today = new Date().toISOString().split('T')[0];
  
  // 检查今日是否已学习过该单词
  db.get('SELECT * FROM learning_records WHERE user_id = ? AND word = ?', 
    [userId, word], (err, existingRecord) => {
      if (err) {
        console.error('查询记录错误:', err);
        return res.status(500).json({ error: '查询失败' });
      }
      
      if (existingRecord) {
        return res.json({ message: '单词已学习过' });
      }
      
      // 添加学习记录
      const nextReview = new Date(Date.now() + 24 * 60 * 60 * 1000); // 1天后复习
      
      const insertQuery = `INSERT INTO learning_records 
        (user_id, word, difficulty, next_review_at) 
        VALUES (?, ?, ?, ?)`;
      
      db.run(insertQuery, [userId, word, difficulty, nextReview.toISOString()], function(err) {
        if (err) {
          console.error('插入记录错误:', err);
          return res.status(500).json({ error: '记录失败' });
        }
        
        // 更新用户进度
        const updateQuery = `
          UPDATE user_progress 
          SET 
            total_words = total_words + 1,
            today_learned = CASE 
              WHEN last_study_date = ? THEN today_learned + 1
              ELSE 1
            END,
            learning_streak = CASE
              WHEN last_study_date = date(?, '-1 day') THEN learning_streak + 1
              WHEN last_study_date != ? THEN 1
              ELSE learning_streak
            END,
            last_study_date = ?
          WHERE user_id = ?
        `;
        
        db.run(updateQuery, [today, today, today, today, userId], (updateErr) => {
          if (updateErr) {
            console.error('更新进度错误:', updateErr);
          }
        });
        
        res.json({ message: '学习记录成功' });
      });
    }
  );
});

// 获取复习单词
app.get('/api/learning/review-words', authenticateToken, (req, res) => {
  const userId = req.userId;
  
  const query = `
    SELECT word, difficulty, review_count 
    FROM learning_records 
    WHERE user_id = ? AND next_review_at <= datetime('now')
    ORDER BY next_review_at
    LIMIT 20
  `;
  
  db.all(query, [userId], (err, rows) => {
    if (err) {
      console.error('获取复习单词错误:', err);
      return res.status(500).json({ error: '获取复习单词失败' });
    }
    
    res.json({
      words: rows,
      count: rows.length
    });
  });
});

// 记录复习结果
app.post('/api/learning/review-result', authenticateToken, (req, res) => {
  const userId = req.userId;
  const { word, isCorrect } = req.body;
  
  if (!word || typeof isCorrect !== 'boolean') {
    return res.status(400).json({ error: '参数不正确' });
  }
  
  // 计算下次复习时间
  const intervals = [1, 3, 7, 15, 30]; // 天数
  
  db.get('SELECT * FROM learning_records WHERE user_id = ? AND word = ?', 
    [userId, word], (err, record) => {
      if (err) {
        console.error('查询复习记录错误:', err);
        return res.status(500).json({ error: '查询失败' });
      }
      
      if (!record) {
        return res.status(404).json({ error: '记录不存在' });
      }
      
      const newReviewCount = record.review_count + 1;
      const newCorrectCount = isCorrect ? record.correct_count + 1 : record.correct_count;
      
      // 根据正确率调整复习间隔
      let intervalIndex = isCorrect ? Math.min(newCorrectCount, intervals.length - 1) : 0;
      
      const nextReviewDays = intervals[intervalIndex];
      const nextReview = new Date(Date.now() + nextReviewDays * 24 * 60 * 60 * 1000);
      
      const updateQuery = `
        UPDATE learning_records 
        SET 
          review_count = ?,
          correct_count = ?,
          next_review_at = ?
        WHERE user_id = ? AND word = ?
      `;
      
      db.run(updateQuery, [newReviewCount, newCorrectCount, nextReview.toISOString(), userId, word], (updateErr) => {
        if (updateErr) {
          console.error('更新复习结果错误:', updateErr);
          return res.status(500).json({ error: '更新失败' });
        }
        
        res.json({ message: '复习结果记录成功' });
      });
    }
  );
});

// 启动服务器函数
function startServers() {
  try {
    // 检查SSL证书文件是否存在
    if (fs.existsSync(SSL_KEY_PATH) && fs.existsSync(SSL_CERT_PATH)) {
      // 读取SSL证书
      const privateKey = fs.readFileSync(SSL_KEY_PATH, 'utf8');
      const certificate = fs.readFileSync(SSL_CERT_PATH, 'utf8');
      const credentials = { key: privateKey, cert: certificate };

      // 创建HTTPS服务器
      const httpsServer = https.createServer(credentials, app);
      httpsServer.listen(HTTPS_PORT, () => {
        console.log('🔒 HTTPS服务器启动成功！');
        console.log(`📍 HTTPS端口: ${HTTPS_PORT}`);
        console.log(`🔗 HTTPS测试地址: https://lengthwords.top/api/test`);
      });

      // 创建HTTP服务器用于重定向到HTTPS
      const httpApp = express();
      httpApp.use('*', (req, res) => {
        res.redirect(301, `https://${req.headers.host}${req.url}`);
      });
      
      const httpServer = http.createServer(httpApp);
      httpServer.listen(HTTP_PORT, () => {
        console.log(`🔄 HTTP重定向服务器启动成功！端口: ${HTTP_PORT}`);
      });

    } else {
      console.log('⚠️  SSL证书文件未找到，启动HTTP服务器...');
      console.log(`SSL密钥路径: ${SSL_KEY_PATH}`);
      console.log(`SSL证书路径: ${SSL_CERT_PATH}`);
      
      // 如果没有SSL证书，则启动HTTP服务器
      const httpServer = http.createServer(app);
      httpServer.listen(HTTP_PORT, () => {
        console.log('🌐 HTTP服务器启动成功！');
        console.log(`📍 HTTP端口: ${HTTP_PORT}`);
        console.log(`🔗 测试地址: http://localhost:${HTTP_PORT}/api/test`);
      });
    }
  } catch (error) {
    console.error('❌ 服务器启动失败:', error);
    process.exit(1);
  }
}

// 启动服务器
startServers();

console.log('📊 服务器状态: 运行中...');
console.log('🎯 域名: lengthwords.top');
console.log('📱 支持小程序HTTPS请求');
EOF

echo "✅ server-https.js 文件创建完成！"

# 设置文件权限
chmod 644 server-https.js

echo "📁 文件位置: $PROJECT_DIR/server-https.js"
echo "📝 文件大小: $(ls -lh server-https.js | awk '{print $5}')"

echo ""
echo "🚀 下一步操作："
echo "1. 删除错误的PM2服务"
echo "   pm2 delete english-learning-https"
echo ""
echo "2. 重新启动HTTPS服务"
echo "   pm2 start server-https.js --name english-learning-https --env production"
echo ""
echo "3. 查看服务状态"
echo "   pm2 status"
echo ""
echo "4. 测试HTTPS连接"
echo "   curl -k https://lengthwords.top/api/test"

echo ""
echo "🎉 server-https.js 文件已准备就绪！"

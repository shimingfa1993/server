const express = require('express');
const cors = require('cors');
const sqlite3 = require('sqlite3').verbose();
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

const app = express();
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

// 加载环境变量
require('dotenv').config();

// 中间件
app.use(cors());
app.use(express.json());

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

// 用户注册
app.post('/api/register', async (req, res) => {
  const { username, password } = req.body;
  
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
        res.json({ token, userId: this.lastID });
      }
    );
  } catch (error) {
    res.status(500).json({ error: '注册失败' });
  }
});

// 用户登录
app.post('/api/login', (req, res) => {
  const { username, password } = req.body;
  
  db.get('SELECT * FROM users WHERE username = ?', [username], async (err, user) => {
    if (err || !user) {
      return res.status(400).json({ error: '用户不存在' });
    }
    
    const validPassword = await bcrypt.compare(password, user.password);
    if (!validPassword) {
      return res.status(400).json({ error: '密码错误' });
    }
    
    const token = jwt.sign({ userId: user.id }, JWT_SECRET);
    res.json({ token, userId: user.id });
  });
});

// 添加一个简单的测试路由（在认证中间件之前）
app.get('/api/test', (req, res) => {
  res.json({ 
    message: '服务器运行正常！', 
    timestamp: new Date().toISOString(),
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
  
  db.get(`
    SELECT 
      up.*,
      COUNT(lr.id) as review_count
    FROM user_progress up
    LEFT JOIN learning_records lr ON up.user_id = lr.user_id 
      AND lr.next_review_at <= datetime('now')
    WHERE up.user_id = ?
    GROUP BY up.user_id
  `, [userId], (err, row) => {
    if (err) {
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
  const today = new Date().toISOString().split('T')[0];
  
  // 检查今日是否已学习过该单词
  db.get('SELECT * FROM learning_records WHERE user_id = ? AND word = ?', 
    [userId, word], (err, existingRecord) => {
      if (existingRecord) {
        return res.json({ message: '单词已学习过' });
      }
      
      // 添加学习记录
      const nextReview = new Date(Date.now() + 24 * 60 * 60 * 1000); // 1天后复习
      
      db.run(`INSERT INTO learning_records 
        (user_id, word, difficulty, next_review_at) 
        VALUES (?, ?, ?, ?)`,
        [userId, word, difficulty, nextReview.toISOString()],
        function(err) {
          if (err) {
            return res.status(500).json({ error: '记录失败' });
          }
          
          // 更新用户进度
          db.run(`
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
          `, [today, today, today, today, userId]);
          
          res.json({ message: '学习记录成功' });
        }
      );
    }
  );
});

// 获取复习单词
app.get('/api/learning/review-words', authenticateToken, (req, res) => {
  const userId = req.userId;
  
  db.all(`
    SELECT word, difficulty, review_count 
    FROM learning_records 
    WHERE user_id = ? AND next_review_at <= datetime('now')
    ORDER BY next_review_at
    LIMIT 20
  `, [userId], (err, rows) => {
    if (err) {
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
  
  // 计算下次复习时间
  const intervals = [1, 3, 7, 15, 30]; // 天数
  
  db.get('SELECT * FROM learning_records WHERE user_id = ? AND word = ?', 
    [userId, word], (err, record) => {
      if (!record) {
        return res.status(404).json({ error: '记录不存在' });
      }
      
      const newReviewCount = record.review_count + 1;
      const newCorrectCount = isCorrect ? record.correct_count + 1 : record.correct_count;
      
      // 根据正确率调整复习间隔
      const correctRate = newCorrectCount / newReviewCount;
      let intervalIndex = isCorrect ? Math.min(newCorrectCount, intervals.length - 1) : 0;
      
      const nextReviewDays = intervals[intervalIndex];
      const nextReview = new Date(Date.now() + nextReviewDays * 24 * 60 * 60 * 1000);
      
      db.run(`
        UPDATE learning_records 
        SET 
          review_count = ?,
          correct_count = ?,
          next_review_at = ?
        WHERE user_id = ? AND word = ?
      `, [newReviewCount, newCorrectCount, nextReview.toISOString(), userId, word]);
      
      res.json({ message: '复习结果记录成功' });
    }
  );
});

// 启动服务器
app.listen(PORT, () => {
  console.log(`服务器运行在端口 ${PORT}`);
});

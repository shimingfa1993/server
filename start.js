const express = require('express');
const https = require('https');
const http = require('http');
const fs = require('fs');
const cors = require('cors');
const Database = require('better-sqlite3');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

try {
  require('dotenv').config();
} catch (_) {}

const app = express();
const HTTP_PORT = Number(process.env.HTTP_PORT) || 80;
const HTTPS_PORT = Number(process.env.HTTPS_PORT) || 443;
const JWT_SECRET = process.env.JWT_SECRET || 'change-this-in-production';

const SSL_KEY_PATH = process.env.SSL_KEY_PATH || '/opt/lengthwords/lengthwords.top.key';
const SSL_CERT_PATH = process.env.SSL_CERT_PATH || '/opt/lengthwords/lengthwords.top.pem';

app.use(cors({
  origin: ['https://lengthwords.top', 'https://www.lengthwords.top'],
  credentials: true
}));
app.use(express.json());

const db = new Database('learning.db');
db.exec(`CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE,
  password TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
)`);
db.exec(`CREATE TABLE IF NOT EXISTS user_progress (
  user_id INTEGER PRIMARY KEY,
  total_words INTEGER DEFAULT 0,
  today_learned INTEGER DEFAULT 0,
  learning_streak INTEGER DEFAULT 0,
  last_study_date DATE,
  daily_target INTEGER DEFAULT 10,
  FOREIGN KEY (user_id) REFERENCES users (id)
)`);
db.exec(`CREATE TABLE IF NOT EXISTS learning_records (
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

// 预编译 SQL 语句
const insertUser = db.prepare('INSERT INTO users (username, password) VALUES (?, ?)');
const insertProgress = db.prepare('INSERT INTO user_progress (user_id) VALUES (?)');
const selectUser = db.prepare('SELECT * FROM users WHERE username = ?');
const selectProgress = db.prepare(`
  SELECT up.*, COALESCE(review_count, 0) as review_count 
  FROM user_progress up
  LEFT JOIN (
    SELECT user_id, COUNT(*) as review_count 
    FROM learning_records 
    WHERE next_review_at <= datetime('now') 
    GROUP BY user_id
  ) reviews ON up.user_id = reviews.user_id
  WHERE up.user_id = ?
`);
const selectLearningRecord = db.prepare('SELECT * FROM learning_records WHERE user_id = ? AND word = ?');
const insertLearningRecord = db.prepare('INSERT INTO learning_records (user_id, word, difficulty, next_review_at) VALUES (?, ?, ?, ?)');
const updateProgress = db.prepare(`
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
`);
const selectReviewWords = db.prepare(`
  SELECT word, difficulty, review_count 
  FROM learning_records 
  WHERE user_id = ? AND next_review_at <= datetime('now')
  ORDER BY next_review_at
  LIMIT 20
`);
const updateLearningRecord = db.prepare(`
  UPDATE learning_records 
  SET review_count = ?, correct_count = ?, next_review_at = ?
  WHERE user_id = ? AND word = ?
`);

app.get('/api/test', (req, res) => {
  res.json({
    message: 'OK',
    protocol: req.secure ? 'HTTPS' : 'HTTP',
    ts: Date.now()
  });
});

app.post('/api/register', async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) return res.status(400).json({ error: '用户名和密码不能为空' });
  
  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    const result = insertUser.run(username, hashedPassword);
    insertProgress.run(result.lastInsertRowid);
    const token = jwt.sign({ userId: result.lastInsertRowid }, JWT_SECRET);
    res.json({ token, userId: result.lastInsertRowid });
  } catch (e) {
    if (e.code === 'SQLITE_CONSTRAINT_UNIQUE') {
      return res.status(400).json({ error: '用户名已存在' });
    }
    res.status(500).json({ error: '注册失败' });
  }
});

app.post('/api/login', async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) return res.status(400).json({ error: '用户名和密码不能为空' });
  
  try {
    const user = selectUser.get(username);
    if (!user) return res.status(400).json({ error: '用户不存在' });
    
    const valid = await bcrypt.compare(password, user.password);
    if (!valid) return res.status(400).json({ error: '密码错误' });
    
    const token = jwt.sign({ userId: user.id }, JWT_SECRET);
    res.json({ token, userId: user.id });
  } catch (e) {
    res.status(500).json({ error: '登录失败' });
  }
});

const authenticateToken = (req, res, next) => {
  const token = (req.headers['authorization'] || '').split(' ')[1];
  if (!token) return res.status(401).json({ error: '需要登录' });
  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) return res.status(403).json({ error: '无效token' });
    req.userId = user.userId;
    next();
  });
};

app.get('/api/learning/stats', authenticateToken, (req, res) => {
  try {
    const row = selectProgress.get(req.userId);
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
      todayProgress,
      learningStreak: row.learning_streak,
      reviewCount: row.review_count || 0
    });
  } catch (e) {
    res.status(500).json({ error: '获取统计失败' });
  }
});

app.post('/api/learning/record', authenticateToken, (req, res) => {
  const { word, difficulty = 'normal' } = req.body;
  if (!word) return res.status(400).json({ error: '单词不能为空' });
  
  try {
    const existing = selectLearningRecord.get(req.userId, word);
    if (existing) return res.json({ message: '单词已学习过' });
    
    const today = new Date().toISOString().split('T')[0];
    const nextReview = new Date(Date.now() + 24 * 60 * 60 * 1000);
    
    insertLearningRecord.run(req.userId, word, difficulty, nextReview.toISOString());
    updateProgress.run(today, today, today, today, req.userId);
    
    res.json({ message: '学习记录成功' });
  } catch (e) {
    res.status(500).json({ error: '记录失败' });
  }
});

app.get('/api/learning/review-words', authenticateToken, (req, res) => {
  try {
    const words = selectReviewWords.all(req.userId);
    res.json({ words, count: words.length });
  } catch (e) {
    res.status(500).json({ error: '获取复习单词失败' });
  }
});

app.post('/api/learning/review-result', authenticateToken, (req, res) => {
  const { word, isCorrect } = req.body;
  if (!word || typeof isCorrect !== 'boolean') {
    return res.status(400).json({ error: '参数不正确' });
  }
  
  try {
    const record = selectLearningRecord.get(req.userId, word);
    if (!record) return res.status(404).json({ error: '记录不存在' });
    
    const intervals = [1, 3, 7, 15, 30];
    const newReviewCount = record.review_count + 1;
    const newCorrectCount = isCorrect ? record.correct_count + 1 : record.correct_count;
    const idx = isCorrect ? Math.min(newCorrectCount, intervals.length - 1) : 0;
    const nextReview = new Date(Date.now() + intervals[idx] * 24 * 60 * 60 * 1000);
    
    updateLearningRecord.run(newReviewCount, newCorrectCount, nextReview.toISOString(), req.userId, word);
    res.json({ message: '复习结果记录成功' });
  } catch (e) {
    res.status(500).json({ error: '更新失败' });
  }
});

function start() {
  let hasCert = false;
  try {
    hasCert = fs.existsSync(SSL_KEY_PATH) && fs.existsSync(SSL_CERT_PATH);
  } catch (_) {}

  if (hasCert) {
    const credentials = { 
      key: fs.readFileSync(SSL_KEY_PATH, 'utf8'), 
      cert: fs.readFileSync(SSL_CERT_PATH, 'utf8') 
    };
    https.createServer(credentials, app).listen(HTTPS_PORT, () => {
      console.log(`🔒 HTTPS Server running on port ${HTTPS_PORT}`);
      console.log(`🌐 HTTPS URL: https://lengthwords.top/api/test`);
    });
    
    const httpApp = express();
    httpApp.use('*', (req, res) => res.redirect(301, `https://${req.headers.host}${req.url}`));
    http.createServer(httpApp).listen(HTTP_PORT, () => {
      console.log(`🔄 HTTP redirect running on port ${HTTP_PORT}`);
    });
  } else {
    console.log('⚠️  SSL certificates not found, starting HTTP only');
    console.log(`SSL Key: ${SSL_KEY_PATH}`);
    console.log(`SSL Cert: ${SSL_CERT_PATH}`);
    http.createServer(app).listen(HTTP_PORT, () => {
      console.log(`🌐 HTTP Server running on port ${HTTP_PORT}`);
    });
  }
}

start();
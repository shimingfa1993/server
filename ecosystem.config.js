module.exports = {
  apps: [
    {
      name: 'lengthwords-api',
      script: 'start-sqlite3.js',
      instances: 1,
      exec_mode: 'cluster',
      env: {
        NODE_ENV: 'development',
        HTTP_PORT: 8080,
        HTTPS_PORT: 8443,
        SSL_KEY_PATH: '/opt/lengthwords/lengthwords.top.key',
        SSL_CERT_PATH: '/opt/lengthwords/lengthwords.top.pem'
      },
      env_production: {
        NODE_ENV: 'production',
        HTTP_PORT: 80,
        HTTPS_PORT: 443,
        SSL_KEY_PATH: '/opt/lengthwords/lengthwords.top.key',
        SSL_CERT_PATH: '/opt/lengthwords/lengthwords.top.pem',
        JWT_SECRET: 'your-secure-jwt-secret-change-in-production'
      },
      error_file: './logs/err.log',
      out_file: './logs/out.log',
      log_file: './logs/combined.log',
      time: true,
      watch: false,
      max_memory_restart: '1G',
      restart_delay: 4000
    }
  ]
};
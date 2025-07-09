module.exports = {
  apps: [{
    name: 'compact-service',
    script: 'index.js',
    instances: 1,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'development',
      PORT: 3002,
      LOG_LEVEL: 'debug'
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: 3002,
      LOG_LEVEL: 'info'
    },
    log_file: './logs/compact-service.log',
    out_file: './logs/compact-service-out.log',
    error_file: './logs/compact-service-error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    restart_delay: 4000,
    max_restarts: 10,
    min_uptime: '10s',
    watch: false,
    ignore_watch: ['node_modules', 'logs', 'temp'],
    max_memory_restart: '500M'
  }]
}; 
# Compact Compiler Service - Digital Ocean Deployment Guide

## 🌐 **Droplet Setup**

### **1. Create Digital Ocean Droplet**

**Recommended Configuration:**
- **Image**: Ubuntu 22.04 LTS x64
- **Plan**: Basic Droplet
- **CPU**: 2 vCPUs  
- **Memory**: 4GB
- **Storage**: 50GB SSD
- **Region**: Choose closest to your users
- **Authentication**: SSH keys (recommended)

**Estimated Cost**: ~$24/month

### **2. Initial Server Setup**

```bash
# Connect to your droplet
ssh root@YOUR_DROPLET_IP

# Update system
apt update && apt upgrade -y

# Install Node.js 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs

# Install PM2 for process management
npm install -g pm2

# Create service user
useradd -m -s /bin/bash compact-service
usermod -aG sudo compact-service

# Create service directory
mkdir -p /opt/compact-service
chown compact-service:compact-service /opt/compact-service
```

## 🔧 **Service Deployment**

### **3. Install Compact Compiler (Linux x64)**

```bash
# Switch to service user
su - compact-service

# Download Linux x64 compactc (adjust version as needed)
cd /tmp
wget https://github.com/midnight-ntwrk/compact/releases/download/v0.24.0/compactc_v0.24.0_x86_64-linux.tar.gz

# Extract and install
tar -xzf compactc_v0.24.0_x86_64-linux.tar.gz
sudo cp compactc_v0.24.0_x86_64-linux/compactc /usr/local/bin/
sudo cp compactc_v0.24.0_x86_64-linux/zkir /usr/local/bin/
sudo chmod +x /usr/local/bin/compactc /usr/local/bin/zkir

# Verify installation
compactc --version
```

### **4. Deploy Service Code**

```bash
# Copy service files to droplet
cd /opt/compact-service

# Upload your local-compact-service directory
# (You can use scp, rsync, or git)
scp -r ./local-compact-service/* compact-service@YOUR_DROPLET_IP:/opt/compact-service/

# Or clone from git if you've pushed it
# git clone YOUR_REPO_URL .

# Install dependencies
npm install --production

# Create necessary directories
mkdir -p temp logs
```

### **5. Environment Configuration**

```bash
# Create environment file
cat > .env << EOF
NODE_ENV=production
PORT=3002
COMPACT_SERVICE_URL=http://localhost:3002
LOG_LEVEL=info
EOF

# Create PM2 ecosystem file
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'compact-service',
    script: 'index.js',
    instances: 1,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      PORT: 3002
    },
    log_file: './logs/compact-service.log',
    out_file: './logs/compact-service-out.log',
    error_file: './logs/compact-service-error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    restart_delay: 4000,
    max_restarts: 10,
    min_uptime: '10s'
  }]
};
EOF
```

## 🛡️ **Security & Networking**

### **6. Firewall Configuration**

```bash
# Configure UFW firewall
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 3002/tcp
sudo ufw status
```

### **7. SSL/TLS Setup (Optional)**

```bash
# Install Certbot for Let's Encrypt
sudo apt install certbot

# Get SSL certificate (if you have a domain)
sudo certbot certonly --standalone -d your-domain.com

# Configure nginx reverse proxy (optional)
sudo apt install nginx
```

## 🚀 **Service Management**

### **8. Start Service with PM2**

```bash
# Start the service
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save

# Set up PM2 to start on boot
pm2 startup
# Follow the instructions provided by the command above

# Monitor service
pm2 status
pm2 logs compact-service
pm2 monit
```

### **9. Health Checks**

```bash
# Test service locally
curl http://localhost:3002/

# Test compilation
curl -X POST http://localhost:3002/compile \
  -H "Content-Type: application/json" \
  -d '{
    "contractCode": "pragma language_version 0.16;\\n\\nimport CompactStandardLibrary;\\n\\nexport ledger round: Counter;\\n\\nexport circuit increment(): [] {\\n  round.increment(1);\\n}",
    "contractName": "test"
  }'
```

## 🔗 **Web3Fast Integration**

### **10. Update Web3Fast Configuration**

Update your Web3Fast app to use the remote service:

```typescript
// app/lib/.server/llm/tools/compact-compiler.ts
const COMPACT_SERVICE_URL = process.env.COMPACT_SERVICE_URL || 'http://YOUR_DROPLET_IP:3002';
```

Add to your `.env`:
```
COMPACT_SERVICE_URL=http://YOUR_DROPLET_IP:3002
```

## 📊 **Monitoring & Maintenance**

### **11. Monitoring Setup**

```bash
# View service logs
pm2 logs compact-service --lines 100

# Monitor system resources
htop

# Check disk usage
df -h

# Monitor service status
pm2 status
```

### **12. Backup Strategy**

```bash
# Create backup script
cat > /opt/compact-service/backup.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
tar -czf /opt/backups/compact-service-$DATE.tar.gz /opt/compact-service
find /opt/backups -name "compact-service-*.tar.gz" -mtime +7 -delete
EOF

chmod +x /opt/compact-service/backup.sh

# Add to crontab for daily backups
echo "0 2 * * * /opt/compact-service/backup.sh" | crontab -
```

## 🎯 **Quick Deployment Script**

Save this as `deploy.sh` for automated deployment:

```bash
#!/bin/bash
set -e

DROPLET_IP="YOUR_DROPLET_IP"
SERVICE_USER="compact-service"

echo "🚀 Deploying Compact Service to $DROPLET_IP"

# Upload service files
echo "📦 Uploading service files..."
rsync -av --exclude node_modules local-compact-service/ $SERVICE_USER@$DROPLET_IP:/opt/compact-service/

# Install dependencies and restart
echo "📦 Installing dependencies..."
ssh $SERVICE_USER@$DROPLET_IP "cd /opt/compact-service && npm install --production"

echo "🔄 Restarting service..."
ssh $SERVICE_USER@$DROPLET_IP "cd /opt/compact-service && pm2 restart compact-service"

echo "✅ Deployment complete!"
echo "🌐 Service available at: http://$DROPLET_IP:3002"
```

## 🔍 **Troubleshooting**

### Common Issues:

1. **Port already in use**: `pm2 kill && pm2 start ecosystem.config.js`
2. **Permission denied**: Check file ownership and permissions
3. **compactc not found**: Verify PATH and binary installation
4. **Out of memory**: Increase droplet RAM or add swap space
5. **Firewall blocking**: Check UFW rules and Digital Ocean firewall

### Useful Commands:

```bash
# Restart service
pm2 restart compact-service

# View real-time logs
pm2 logs compact-service --lines 0

# Check service health
curl http://localhost:3002/check-compiler

# System resources
free -h && df -h
```

---

## 📋 **Pre-Deployment Checklist**

- [ ] Digital Ocean account set up
- [ ] SSH keys configured
- [ ] Domain name (optional)
- [ ] Web3Fast environment variables updated
- [ ] Service code tested locally
- [ ] Backup strategy planned
- [ ] Monitoring approach decided

**Estimated Setup Time**: 30-45 minutes
**Monthly Cost**: ~$24 (4GB droplet) 
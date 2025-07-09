# 🚀 Compact Compiler Service - Complete Deployment Guide

## Overview

This guide provides complete instructions for deploying the Compact compiler service to a Digital Ocean droplet and integrating it with Web3Fast.

## Architecture

```
┌─────────────────┐    HTTPS/HTTP    ┌─────────────────┐    Native    ┌─────────────┐
│   Web3Fast      │ ────────────────> │ Digital Ocean   │ ───────────> │  compactc   │
│   (Local/Cloud) │                  │ Ubuntu Droplet  │              │  (Linux)    │
│                 │                  │ Port 3002       │              │             │
└─────────────────┘                  └─────────────────┘              └─────────────┘
```

## Prerequisites

- **Digital Ocean Account** with billing enabled
- **SSH Key** configured for secure access
- **Linux/macOS** local machine for deployment
- **compactc v0.24.0** Linux binary (will be installed)

## 🌊 Step 1: Create Digital Ocean Droplet

### Recommended Configuration
```yaml
Image: Ubuntu 22.04 LTS x64
Plan: Basic Droplet
CPU: 2 vCPUs
Memory: 4GB
Storage: 50GB SSD
Region: Choose closest to your users
Authentication: SSH keys (recommended)
```

**Estimated Cost**: ~$24/month

### Create Droplet
1. Login to Digital Ocean
2. Click "Create" → "Droplet"
3. Choose Ubuntu 22.04 LTS
4. Select the 4GB / 2 vCPU plan
5. Add your SSH key
6. Create droplet and note the IP address

## 🛠️ Step 2: Server Setup

### Automatic Setup Script
```bash
# Download and run the server setup script
curl -fsSL https://raw.githubusercontent.com/your-repo/deployment/server-setup.sh | sudo bash
```

### Manual Setup (if needed)
```bash
# Connect to your droplet
ssh root@YOUR_DROPLET_IP

# Run the setup script
chmod +x deployment/server-setup.sh
sudo ./deployment/server-setup.sh
```

The setup script will:
- ✅ Install Node.js 18.x
- ✅ Install PM2 process manager
- ✅ Create service user and directories
- ✅ Configure firewall (SSH + port 3002)
- ✅ Install compactc compiler
- ✅ Set up nginx (optional)
- ✅ Configure backups

## 🔐 Step 3: SSH Key Setup

```bash
# Copy your SSH key to the service user
ssh-copy-id compact-service@YOUR_DROPLET_IP

# Test the connection
ssh compact-service@YOUR_DROPLET_IP "echo 'Connection successful'"
```

## 🚀 Step 4: Deploy the Service

### Automated Deployment
```bash
# From your local Web3Fast directory
chmod +x deployment/deploy.sh
./deployment/deploy.sh YOUR_DROPLET_IP
```

### Manual Deployment
```bash
# Upload service files
rsync -av --exclude 'node_modules' ./local-compact-service/ \
  compact-service@YOUR_DROPLET_IP:/opt/compact-service/

# SSH into the server
ssh compact-service@YOUR_DROPLET_IP

# Install dependencies
cd /opt/compact-service
npm install --production

# Start the service
pm2 start ecosystem.config.js --env production
pm2 save
```

## 🧪 Step 5: Verify Deployment

### Health Check
```bash
# Test service health
curl http://YOUR_DROPLET_IP:3002/

# Check compiler
curl http://YOUR_DROPLET_IP:3002/check-compiler

# Test compilation
curl -X POST http://YOUR_DROPLET_IP:3002/compile \
  -H "Content-Type: application/json" \
  -d '{"contractCode": "pragma language_version 0.16;\nimport CompactStandardLibrary;\nexport ledger round: Counter;\nexport circuit increment(): [] { round.increment(1); }", "contractName": "test"}'
```

### Service Status
```bash
# Check PM2 status
ssh compact-service@YOUR_DROPLET_IP "pm2 status"

# View logs
ssh compact-service@YOUR_DROPLET_IP "pm2 logs compact-service"
```

## ⚙️ Step 6: Configure Web3Fast

### Environment Variables
```bash
# Set the remote service URL
export COMPACT_SERVICE_URL=http://YOUR_DROPLET_IP:3002
```

### Production Configuration
```bash
# In your Web3Fast project root
echo "COMPACT_SERVICE_URL=http://YOUR_DROPLET_IP:3002" >> .env.local
```

### Wrangler Configuration (if using Cloudflare)
```toml
# In wrangler.toml
[env.production.vars]
COMPACT_SERVICE_URL = "http://YOUR_DROPLET_IP:3002"
```

## 🔧 Step 7: Optional Enhancements

### Enable Nginx Reverse Proxy
```bash
# SSH into server
ssh compact-service@YOUR_DROPLET_IP

# Start nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Test nginx
curl http://YOUR_DROPLET_IP/
```

### SSL Certificate with Let's Encrypt
```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Get certificate (replace with your domain)
sudo certbot --nginx -d your-domain.com

# Auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

### Container Deployment (Alternative)
```bash
# Using Docker Compose
cd /opt/compact-service
docker-compose up -d
```

## 📊 Step 8: Monitoring & Maintenance

### Service Monitoring
```bash
# Monitor with PM2
ssh compact-service@YOUR_DROPLET_IP "pm2 monit"

# View service logs
ssh compact-service@YOUR_DROPLET_IP "pm2 logs compact-service --lines 50"

# Restart service
ssh compact-service@YOUR_DROPLET_IP "pm2 restart compact-service"
```

### Backup & Recovery
```bash
# Run backup
ssh compact-service@YOUR_DROPLET_IP "/opt/compact-service/backup.sh"

# List backups
ssh compact-service@YOUR_DROPLET_IP "ls -la /opt/backups/"
```

### Updates
```bash
# Update service code
./deployment/deploy.sh YOUR_DROPLET_IP

# Update compactc compiler
ssh compact-service@YOUR_DROPLET_IP "sudo /opt/compact-service/update-compiler.sh"
```

## 🚨 Troubleshooting

### Common Issues

#### Service Not Starting
```bash
# Check PM2 logs
ssh compact-service@YOUR_DROPLET_IP "pm2 logs compact-service"

# Check system logs
ssh compact-service@YOUR_DROPLET_IP "sudo journalctl -u compact-service"

# Restart service
ssh compact-service@YOUR_DROPLET_IP "pm2 restart compact-service"
```

#### Compilation Errors
```bash
# Check compiler installation
ssh compact-service@YOUR_DROPLET_IP "which compactc && compactc --version"

# Test compilation manually
ssh compact-service@YOUR_DROPLET_IP "cd /tmp && echo 'pragma language_version 0.16;' > test.compact && compactc test.compact test"
```

#### Connection Issues
```bash
# Check firewall
ssh compact-service@YOUR_DROPLET_IP "sudo ufw status"

# Check if service is listening
ssh compact-service@YOUR_DROPLET_IP "sudo netstat -tlnp | grep 3002"

# Test from inside server
ssh compact-service@YOUR_DROPLET_IP "curl http://localhost:3002/"
```

### Performance Optimization
```bash
# Monitor resource usage
ssh compact-service@YOUR_DROPLET_IP "htop"

# Optimize PM2 settings
ssh compact-service@YOUR_DROPLET_IP "pm2 reload ecosystem.config.js --env production"
```

## 📱 Step 9: Testing Integration

### Test from Web3Fast
```bash
# Start Web3Fast with remote service
COMPACT_SERVICE_URL=http://YOUR_DROPLET_IP:3002 npm run dev

# Test compilation through Web3Fast UI
# Navigate to chat and ask: "Create a simple Compact counter contract"
```

### API Testing
```bash
# Test all endpoints
curl http://YOUR_DROPLET_IP:3002/
curl http://YOUR_DROPLET_IP:3002/check-compiler
curl -X POST http://YOUR_DROPLET_IP:3002/api/compile -H "Content-Type: application/json" -d '{"contractCode":"pragma language_version 0.16;\nimport CompactStandardLibrary;\nexport ledger round: Counter;\nexport circuit increment(): [] { round.increment(1); }", "contractName": "counter"}'
```

## 🎯 Success Criteria

✅ **Service Health**: HTTP 200 response from service endpoint  
✅ **Compiler Available**: `compactc --version` shows v0.24.0  
✅ **Compilation Works**: Successfully compiles test contract  
✅ **PM2 Running**: Service shows as "online" in PM2 status  
✅ **Firewall Configured**: Port 3002 accessible externally  
✅ **Web3Fast Integration**: Remote compilation works in Web3Fast UI  

## 🌟 Next Steps

1. **Scaling**: Consider load balancing for high traffic
2. **Security**: Implement rate limiting and authentication
3. **Monitoring**: Set up alerting for service downtime
4. **Backup**: Schedule regular automated backups
5. **Updates**: Plan for compiler version updates

## 🆘 Support

- **Service Logs**: `pm2 logs compact-service`
- **System Logs**: `sudo journalctl -u compact-service`
- **Midnight Docs**: https://docs.midnight.network/
- **Web3Fast Issues**: Open issue in project repository

---

**🎉 Congratulations! Your Compact compiler service is now running in production!** 
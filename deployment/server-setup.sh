#!/bin/bash
set -e

# Server Setup Script for Compact Compiler Service
# Run this script on a fresh Ubuntu 22.04 Digital Ocean droplet

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root (use sudo)"
    exit 1
fi

print_status "🚀 Setting up Digital Ocean droplet for Compact Compiler Service"

# Update system
print_status "📦 Updating system packages..."
apt update && apt upgrade -y

print_success "System updated"

# Install Node.js 18.x
print_status "📦 Installing Node.js 18.x..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs

NODE_VERSION=$(node --version)
print_success "Node.js installed: $NODE_VERSION"

# Install PM2 globally
print_status "📦 Installing PM2..."
npm install -g pm2

PM2_VERSION=$(pm2 --version)
print_success "PM2 installed: $PM2_VERSION"

# Install additional useful packages
print_status "📦 Installing additional packages..."
apt-get install -y curl wget unzip htop ufw rsync

# Create service user
print_status "👤 Creating service user..."
if id "compact-service" &>/dev/null; then
    print_warning "User compact-service already exists"
else
    useradd -m -s /bin/bash compact-service
    usermod -aG sudo compact-service
    print_success "User compact-service created"
fi

# Create service directory
print_status "📁 Creating service directories..."
mkdir -p /opt/compact-service/{logs,temp,backups}
chown -R compact-service:compact-service /opt/compact-service

print_success "Service directories created"

# Configure firewall
print_status "🛡️ Configuring firewall..."
ufw --force enable
ufw allow ssh
ufw allow 3002/tcp
ufw status

print_success "Firewall configured"

# Download and install compactc (Linux x64)
print_status "🌙 Installing Compact compiler..."

# Create temp directory for download
cd /tmp

# Download the latest version (adjust URL if needed)
COMPACT_VERSION="0.24.0"
COMPACT_URL="https://docs.midnight.network/compact-compiler/releases/compactc_v${COMPACT_VERSION}_x86_64-linux.tar.gz"

print_status "Downloading compactc v$COMPACT_VERSION..."

# Try to download (this URL might need adjustment based on actual release location)
if wget -q --spider "$COMPACT_URL" 2>/dev/null; then
    wget "$COMPACT_URL" -O compactc.tar.gz
    print_success "Downloaded compactc"
    
    # Extract and install
    tar -xzf compactc.tar.gz
    
    # Find the actual directory name (might vary)
    EXTRACT_DIR=$(tar -tzf compactc.tar.gz | head -1 | cut -f1 -d"/")
    
    if [ -f "$EXTRACT_DIR/compactc" ]; then
        cp "$EXTRACT_DIR/compactc" /usr/local/bin/
        chmod +x /usr/local/bin/compactc
        print_success "compactc installed to /usr/local/bin/"
    fi
    
    if [ -f "$EXTRACT_DIR/zkir" ]; then
        cp "$EXTRACT_DIR/zkir" /usr/local/bin/
        chmod +x /usr/local/bin/zkir
        print_success "zkir installed to /usr/local/bin/"
    fi
    
    # Verify installation
    if command -v compactc &> /dev/null; then
        COMPACTC_VERSION=$(compactc --version || echo "installed")
        print_success "compactc verification: $COMPACTC_VERSION"
    else
        print_warning "compactc installation verification failed"
    fi
    
    # Clean up
    rm -rf compactc.tar.gz $EXTRACT_DIR
    
else
    print_warning "Could not download compactc from $COMPACT_URL"
    print_warning "You may need to install compactc manually"
    print_status "Manual installation steps:"
    echo "1. Download the Linux x64 version from the Midnight Network releases"
    echo "2. Extract: tar -xzf compactc_v*_x86_64-linux.tar.gz"
    echo "3. Copy: sudo cp compactc /usr/local/bin/ && sudo cp zkir /usr/local/bin/"
    echo "4. Make executable: sudo chmod +x /usr/local/bin/compactc /usr/local/bin/zkir"
fi

# Set up PM2 to start on boot for the service user
print_status "⚙️ Configuring PM2 startup..."
su - compact-service -c "pm2 startup" | grep "sudo env" | sh
print_success "PM2 startup configured"

# Create a basic nginx configuration (optional)
if command -v nginx &> /dev/null; then
    print_status "🌐 Nginx already installed"
else
    print_status "📦 Installing nginx (optional reverse proxy)..."
    apt-get install -y nginx
    
    # Create a basic reverse proxy configuration
    cat > /etc/nginx/sites-available/compact-service << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

    # Enable the site (but don't start nginx yet)
    ln -sf /etc/nginx/sites-available/compact-service /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    print_success "Nginx configured (not started automatically)"
    print_warning "To use nginx reverse proxy, start it with: systemctl start nginx"
fi

# Create backup directory and script
print_status "💾 Setting up backup system..."
mkdir -p /opt/backups
chown compact-service:compact-service /opt/backups

cat > /opt/compact-service/backup.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
tar -czf /opt/backups/compact-service-$DATE.tar.gz /opt/compact-service --exclude='node_modules' --exclude='temp' --exclude='logs'
find /opt/backups -name "compact-service-*.tar.gz" -mtime +7 -delete
echo "Backup completed: compact-service-$DATE.tar.gz"
EOF

chmod +x /opt/compact-service/backup.sh
chown compact-service:compact-service /opt/compact-service/backup.sh

print_success "Backup system configured"

# Get the external IP address
EXTERNAL_IP=$(curl -s http://ipv4.icanhazip.com)

print_success "✅ Server setup completed successfully!"
echo ""
print_status "📋 Server Information:"
echo "  - External IP: $EXTERNAL_IP"
echo "  - Service User: compact-service"
echo "  - Service Directory: /opt/compact-service"
echo "  - Node.js Version: $(node --version)"
echo "  - PM2 Version: $(pm2 --version)"
if command -v compactc &> /dev/null; then
    echo "  - Compact Compiler: $(compactc --version || echo 'installed')"
else
    echo "  - Compact Compiler: ⚠️  Manual installation required"
fi
echo ""
print_status "🚀 Next Steps:"
echo "1. Copy your SSH public key to the compact-service user:"
echo "   ssh-copy-id compact-service@$EXTERNAL_IP"
echo ""
echo "2. Run the deployment script from your local machine:"
echo "   ./deployment/deploy.sh $EXTERNAL_IP"
echo ""
echo "3. Update Web3Fast environment:"
echo "   COMPACT_SERVICE_URL=http://$EXTERNAL_IP:3002"
echo ""
print_status "🔧 Optional: Enable nginx reverse proxy (port 80):"
echo "   systemctl start nginx && systemctl enable nginx" 
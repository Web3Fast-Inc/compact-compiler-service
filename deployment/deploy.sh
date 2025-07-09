#!/bin/bash
set -e

# Deployment Configuration
DROPLET_IP="${1:-YOUR_DROPLET_IP}"
SERVICE_USER="compact-service"
SERVICE_DIR="/opt/compact-service"
LOCAL_SERVICE_DIR="./local-compact-service"

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

# Validate arguments
if [ "$DROPLET_IP" = "YOUR_DROPLET_IP" ]; then
    print_error "Please provide the droplet IP address"
    echo "Usage: ./deploy.sh <DROPLET_IP>"
    exit 1
fi

print_status "🚀 Starting deployment to $DROPLET_IP"

# Check if local service exists
if [ ! -d "$LOCAL_SERVICE_DIR" ]; then
    print_error "Local service directory not found: $LOCAL_SERVICE_DIR"
    exit 1
fi

# Test SSH connection
print_status "🔑 Testing SSH connection..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes $SERVICE_USER@$DROPLET_IP "echo 'SSH connection successful'" 2>/dev/null; then
    print_error "Cannot connect to $SERVICE_USER@$DROPLET_IP via SSH"
    print_warning "Make sure SSH keys are set up and the user exists"
    exit 1
fi

print_success "SSH connection successful"

# Create necessary directories on remote server
print_status "📁 Creating directories on remote server..."
ssh $SERVICE_USER@$DROPLET_IP "mkdir -p $SERVICE_DIR/{logs,temp,backups}"

# Upload service files (excluding node_modules and temp files)
print_status "📦 Uploading service files..."
rsync -av --progress \
    --exclude 'node_modules' \
    --exclude 'logs' \
    --exclude 'temp' \
    --exclude '.git' \
    --exclude '*.log' \
    $LOCAL_SERVICE_DIR/ $SERVICE_USER@$DROPLET_IP:$SERVICE_DIR/

print_success "Files uploaded successfully"

# Install dependencies on remote server
print_status "📦 Installing dependencies..."
ssh $SERVICE_USER@$DROPLET_IP "cd $SERVICE_DIR && npm install --production"

print_success "Dependencies installed"

# Check if compactc is available
print_status "🔍 Checking compactc installation..."
if ssh $SERVICE_USER@$DROPLET_IP "which compactc" 2>/dev/null; then
    COMPACTC_VERSION=$(ssh $SERVICE_USER@$DROPLET_IP "compactc --version 2>/dev/null || echo 'unknown'")
    print_success "compactc found: $COMPACTC_VERSION"
else
    print_warning "compactc not found in PATH"
    print_warning "Please install compactc manually on the server"
fi

# Start or restart the service with PM2
print_status "🔄 Managing PM2 service..."
ssh $SERVICE_USER@$DROPLET_IP "cd $SERVICE_DIR && pm2 start ecosystem.config.js --env production || pm2 restart compact-service"

# Save PM2 configuration
ssh $SERVICE_USER@$DROPLET_IP "pm2 save"

print_success "Service restarted successfully"

# Wait a moment for the service to start
print_status "⏳ Waiting for service to start..."
sleep 5

# Test the service
print_status "🧪 Testing service health..."
if ssh $SERVICE_USER@$DROPLET_IP "curl -s http://localhost:3002/ > /dev/null"; then
    print_success "Service is responding correctly"
else
    print_error "Service health check failed"
    print_warning "Check logs with: ssh $SERVICE_USER@$DROPLET_IP 'pm2 logs compact-service'"
fi

# Display service status
print_status "📊 Service status:"
ssh $SERVICE_USER@$DROPLET_IP "pm2 status compact-service"

print_success "✅ Deployment completed successfully!"
echo ""
print_status "🌐 Service URL: http://$DROPLET_IP:3002"
print_status "📋 Useful commands:"
echo "  - View logs: ssh $SERVICE_USER@$DROPLET_IP 'pm2 logs compact-service'"
echo "  - Restart: ssh $SERVICE_USER@$DROPLET_IP 'pm2 restart compact-service'"
echo "  - Stop: ssh $SERVICE_USER@$DROPLET_IP 'pm2 stop compact-service'"
echo "  - Monitor: ssh $SERVICE_USER@$DROPLET_IP 'pm2 monit'"
echo ""
print_status "🔧 Update Web3Fast with: COMPACT_SERVICE_URL=http://$DROPLET_IP:3002" 
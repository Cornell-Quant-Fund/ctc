#!/bin/bash

# Remote Deployment Script for Cornell Trading Competition
# Deploys to root@5.161.90.182

set -e

SERVER="root@5.161.90.182"
REPO_URL="https://github.com/jbolt01/ctc.git"
APP_DIR="/opt/ctc"

echo "🚀 Deploying Cornell Trading Competition to $SERVER"
echo "=================================================="

# Function to run commands on remote server
run_remote() {
    ssh -o StrictHostKeyChecking=no "$SERVER" "$1"
}

# Function to copy files to remote server
copy_to_remote() {
    scp -o StrictHostKeyChecking=no "$1" "$SERVER:$2"
}

echo "📋 Checking server prerequisites..."

# Check if Docker is installed
if ! run_remote "command -v docker >/dev/null 2>&1"; then
    echo "🐳 Installing Docker..."
    run_remote "curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh && rm get-docker.sh"
    run_remote "systemctl start docker && systemctl enable docker"
else
    echo "✅ Docker is already installed"
fi

# Check if Docker Compose is installed
if ! run_remote "command -v docker-compose >/dev/null 2>&1"; then
    echo "🐙 Installing Docker Compose..."
    run_remote "curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose"
else
    echo "✅ Docker Compose is already installed"
fi

echo "📁 Setting up application directory..."
run_remote "mkdir -p $APP_DIR"

echo "📦 Copying deployment files..."
copy_to_remote "docker-compose.prod.yml" "$APP_DIR/docker-compose.prod.yml"
copy_to_remote "nginx.conf" "$APP_DIR/nginx.conf"
copy_to_remote "deploy.sh" "$APP_DIR/deploy.sh"

echo "⚙️ Creating production environment file..."
ssh -o StrictHostKeyChecking=no "$SERVER" "cat > $APP_DIR/.env.prod << 'EOF'
# Production Environment Variables for 5.161.90.182

# GitHub Container Registry
GITHUB_REPOSITORY=jbolt01/ctc

# Database Configuration
POSTGRES_DB=trading_competition
POSTGRES_USER=trading_user
POSTGRES_PASSWORD=TradingComp2024!SecurePass

# Application Settings
ALLOW_ANY_API_KEY=false

# Frontend URLs (using IP address)
NEXT_PUBLIC_API_URL=http://5.161.90.182/api/v1
NEXT_PUBLIC_WS_URL=/ws/v1/market-data

# Nginx Ports
HTTP_PORT=80
HTTPS_PORT=443
EOF"

echo "🔐 Logging into GitHub Container Registry..."
run_remote "cd $APP_DIR && echo 'Pulling images without authentication (public repo)...'"

echo "📦 Pulling latest Docker images..."
run_remote "cd $APP_DIR && docker pull ghcr.io/jbolt01/ctc/backend:latest"
run_remote "cd $APP_DIR && docker pull ghcr.io/jbolt01/ctc/frontend:latest"

echo "🛑 Stopping existing services (if any)..."
run_remote "cd $APP_DIR && docker-compose -f docker-compose.prod.yml --env-file .env.prod down || true"

echo "🧹 Cleaning up old containers and images..."
run_remote "docker container prune -f && docker image prune -f"

echo "🚀 Starting production services..."
run_remote "cd $APP_DIR && chmod +x deploy.sh"
run_remote "cd $APP_DIR && docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d"

echo "⏳ Waiting for services to start..."
sleep 15

echo "🔍 Checking service status..."
run_remote "cd $APP_DIR && docker-compose -f docker-compose.prod.yml --env-file .env.prod ps"

echo "📋 Checking service logs..."
run_remote "cd $APP_DIR && docker-compose -f docker-compose.prod.yml --env-file .env.prod logs --tail=10"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "🌐 Your application is now available at:"
echo "   http://5.161.90.182"
echo ""
echo "🔧 To manage the deployment on the server:"
echo "   ssh root@5.161.90.182"
echo "   cd $APP_DIR"
echo "   docker-compose -f docker-compose.prod.yml --env-file .env.prod logs -f"
echo ""
echo "🛑 To stop services:"
echo "   docker-compose -f docker-compose.prod.yml --env-file .env.prod down"

#!/bin/bash
set -e

# --------------------------------------------------
# Colors
# --------------------------------------------------
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()    { echo -e "\n${GREEN}==>${NC} $1"; }

export DEBIAN_FRONTEND=noninteractive

# --------------------------------------------------
# Base packages
# --------------------------------------------------
log_step "Installing base packages..."
apt update -y
apt install -y curl git build-essential ca-certificates sudo

# --------------------------------------------------
# Create dedicated non-root user: openclaw
# --------------------------------------------------
log_step "Creating user 'openclaw'..."

if ! id openclaw >/dev/null 2>&1; then
    useradd -m -s /bin/bash openclaw
    log_success "User 'openclaw' created"
else
    log_info "User already exists"
fi

# Safe sudo config
echo "openclaw ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/openclaw
chmod 0440 /etc/sudoers.d/openclaw
log_success "Passwordless sudo configured"

# --------------------------------------------------
# Switch to openclaw
# --------------------------------------------------
log_step "Configuring openclaw environment..."

su - openclaw << 'USER_SCRIPT'
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# -------------------- NVM --------------------
if [ ! -d "$HOME/.nvm" ]; then
    log_info "Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# -------------------- Node.js 22 --------------------
log_info "Installing Node.js 22..."
nvm install 22
nvm use 22
nvm alias default 22
log_success "Node $(node --version) installed"

# -------------------- Android networking shim --------------------
log_info "Applying Android networking workaround..."

cat > "$HOME/openclaw-shim.cjs" << 'EOF'
const os = require('os');
os.networkInterfaces = () => ({
  lo: [{
    address: '127.0.0.1',
    netmask: '255.0.0.0',
    family: 'IPv4',
    internal: true,
    cidr: '127.0.0.1/8'
  }]
});
EOF

# -------------------- OpenClaw --------------------
log_info "Installing OpenClaw..."
npm install -g openclaw@latest

if ! command -v openclaw >/dev/null 2>&1; then
    log_error "OpenClaw install failed"
    exit 1
fi

log_success "OpenClaw $(openclaw --version) installed"

# -------------------- Bashrc persistence --------------------
cat >> "$HOME/.bashrc" << 'BASHRC'

# Android networking fix
export NODE_OPTIONS="--require /home/openclaw/openclaw-shim.cjs"

# OpenClaw aliases
alias start-claw='openclaw gateway --bind loopback'
alias update-openclaw='npm update -g openclaw'
alias claw-status='ps aux | grep openclaw'
alias claw-logs='tail -f ~/.openclaw/logs/*.log'
BASHRC

log_success "Aliases and environment persisted"
USER_SCRIPT

log_success "openclaw setup complete"

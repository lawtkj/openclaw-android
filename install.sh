#!/data/data/com.termux/files/usr/bin/bash
################################################################################
# OpenClaw Android Installer
# Version: 2026.2.11
# Description: Automated installer for OpenClaw on Android via Termux
# Repository: https://github.com/lawtkj/openclaw-android
################################################################################

set -e  # Exit on error

# Script Configuration
SCRIPT_VERSION="2026.2.11"
SCRIPT_URL="https://raw.githubusercontent.com/lawtkj/openclaw-android/main/install.sh"
VERSION_URL="https://raw.githubusercontent.com/lawtkj/openclaw-android/main/VERSION"
REPO_URL="https://github.com/lawtkj/openclaw-android"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${MAGENTA}==>${NC} ${CYAN}$1${NC}\n"
}

# Banner
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════╗
    ║                                               ║
    ║           🦞 OpenClaw for Android 🦞           ║
    ║                                               ║
    ║      Automated Installation & Setup Tool      ║
    ║                                               ║
    ╚═══════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "  Version: ${GREEN}${SCRIPT_VERSION}${NC}"
    echo -e "  Repository: ${BLUE}${REPO_URL}${NC}"
    echo -e ""
    echo -e "${YELLOW}  ⚠️  DISCLAIMER:${NC} This is a community-created installer."
    echo -e "      OpenClaw framework © its original creators"
    echo -e ""
}

# Check for updates
check_for_updates() {
    log_step "Checking for installer updates..."
    
    if command -v curl &> /dev/null; then
        # Get latest version, trim whitespace, and only use first line
        LATEST_VERSION=$(curl -s "$VERSION_URL" 2>/dev/null | head -1 | tr -d '[:space:]')
        
        # Validate version format (should be like 2026.2.9)
        if ! [[ "$LATEST_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            log_warn "Unable to check for updates (invalid version format received)"
            LATEST_VERSION="$SCRIPT_VERSION"
        fi
        
        # If curl failed or returned empty, use current version
        if [ -z "$LATEST_VERSION" ]; then
            LATEST_VERSION="$SCRIPT_VERSION"
        fi
        
        if [ "$LATEST_VERSION" != "$SCRIPT_VERSION" ]; then
            log_warn "New installer version available: $LATEST_VERSION (current: $SCRIPT_VERSION)"
            echo -e "\n${YELLOW}Would you like to update the installer? (y/n)${NC}"
            # Read from /dev/tty to ensure interactive input works in Termux
            read -r response < /dev/tty
            
            if [[ "$response" =~ ^[Yy]$ ]]; then
                log_info "Downloading latest installer..."
                # Use $HOME instead of /tmp to avoid permission issues
                curl -fsSL "$SCRIPT_URL" -o "$HOME/install_new.sh"
                chmod +x "$HOME/install_new.sh"
                log_success "Installer updated! Restarting with new version..."
                exec "$HOME/install_new.sh" "$@"
            else
                log_info "Continuing with current version..."
            fi
        else
            log_success "Installer is up to date!"
        fi
    else
        log_warn "Unable to check for updates (curl not available)"
    fi
}

# Check if running in Termux
check_termux() {
    if [ ! -d "/data/data/com.termux" ]; then
        log_error "This script must be run in Termux!"
        log_info "Please install Termux from F-Droid: https://f-droid.org/en/packages/com.termux/"
        exit 1
    fi
    log_success "Termux environment detected"
}

# Check Android version
check_android_version() {
    log_step "Checking Android version..."
    
    ANDROID_VERSION=$(getprop ro.build.version.release)
    log_info "Android version: $ANDROID_VERSION"
    
    if [ "${ANDROID_VERSION%%.*}" -lt 12 ]; then
        log_warn "Android 12+ is recommended for best compatibility"
        echo -e "${YELLOW}Continue anyway? (y/n)${NC}"
        read -r response < /dev/tty
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            exit 0
        fi
    else
        log_success "Android version compatible"
    fi
}

# Check available storage
check_storage() {
    log_step "Checking available storage..."
    
    # Use df -k (more compatible) and convert to MB
    AVAILABLE_KB=$(df -k "$HOME" 2>/dev/null | tail -1 | awk '{print $4}')
    
    # Check if we got a valid number
    if [ -z "$AVAILABLE_KB" ] || ! [[ "$AVAILABLE_KB" =~ ^[0-9]+$ ]]; then
        log_warn "Unable to check available storage automatically"
        log_info "Please ensure you have at least 2GB free space"
        echo -e "${YELLOW}Continue anyway? (y/n)${NC}"
        read -r response < /dev/tty
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            exit 0
        fi
        return 0
    fi
    
    # Convert KB to MB
    AVAILABLE_MB=$((AVAILABLE_KB / 1024))
    log_info "Available storage: ${AVAILABLE_MB}MB"
    
    if [ "$AVAILABLE_MB" -lt 2048 ]; then
        log_error "Insufficient storage! At least 2GB required, ${AVAILABLE_MB}MB available"
        log_info "Please free up some space and try again"
        exit 1
    fi
    log_success "Storage check passed"
}

# Install Termux packages
install_termux_packages() {
    log_step "Installing Termux packages..."
    
    log_info "Updating package lists..."
    pkg update -y
    
    log_info "Upgrading existing packages..."
    # Set environment to avoid interactive prompts
    export DEBIAN_FRONTEND=noninteractive
    # Use apt options to automatically handle config file changes
    apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
    
    log_info "Installing proot-distro..."
    pkg install proot-distro -y
    
    log_success "Termux packages installed"
}
# Install Ubuntu distribution
install_ubuntu() {
    log_step "Installing Ubuntu distribution..."

    if proot-distro list | grep -q "ubuntu.*installed"; then
        log_warn "Ubuntu already installed"

        if [ "$REINSTALL" = "true" ]; then
            log_info "Reinstalling Ubuntu..."
            proot-distro remove ubuntu -y 2>/dev/null || true
            proot-distro install ubuntu
        else
            echo -e "${YELLOW}Ubuntu is already installed. Reinstall? (y/n)${NC}"
            read -r response < /dev/tty
            if [[ "$response" =~ ^[Yy]$ ]]; then
                proot-distro remove ubuntu -y
                proot-distro install ubuntu
            else
                log_info "Using existing Ubuntu installation"
            fi
        fi
    else
        proot-distro install ubuntu
    fi

    log_success "Ubuntu distribution ready"
}

# Create setup script for Ubuntu environment (with Bun)
create_ubuntu_setup() {
    log_step "Creating Ubuntu setup script..."

    cat > "$HOME/ubuntu_setup.sh" <<'UBUNTU_SCRIPT'
#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "\n${GREEN}==> Setting up Ubuntu environment...${NC}\n"

# Update Ubuntu packages
log_info "Updating Ubuntu packages..."
apt update && apt upgrade -y

# Install dependencies (include unzip + wget for Bun + DWAgent download)
log_info "Installing build dependencies..."
apt install -y curl git build-essential ca-certificates unzip wget

# Install Bun (official installer)
log_info "Installing Bun..."
curl -fsSL https://bun.com/install | bash

# Add Bun to PATH for future shells
if ! grep -q 'BUN_INSTALL' ~/.bashrc 2>/dev/null; then
  echo 'export BUN_INSTALL="$HOME/.bun"' >> ~/.bashrc
  echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> ~/.bashrc
fi
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Verify Bun
bun --version >/dev/null
log_success "Bun installed"

# Install NVM (Node Version Manager) – still needed to install OpenClaw via npm
if [ ! -d "$HOME/.nvm" ]; then
    log_info "Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi

# Load NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

if ! command -v nvm >/dev/null 2>&1; then
    log_error "NVM failed to load"
    exit 1
fi

# Install Node.js 22 (OpenClaw requires Node 22+)
log_info "Installing Node.js v22..."
nvm install 22
nvm use 22
nvm alias default 22
log_success "Node $(node --version) installed"

# Android networking shim (avoids os.networkInterfaces() crashes)
log_info "Creating Android networking fix..."
cat > /root/openclaw-shim.cjs <<'EOF'
const os = require('os');
os.networkInterfaces = () => ({
  lo: [{
    address: '127.0.0.1',
    netmask: '255.0.0.0',
    family: 'IPv4',
    mac: '00:00:00:00:00:00',
    internal: true,
    cidr: '127.0.0.1/8'
  }]
});
EOF
log_success "Networking shim created"

# Install OpenClaw (via npm)
log_info "Installing OpenClaw (npm)..."
npm install -g openclaw@latest

# Create a Bun wrapper for faster CLI usage
log_info "Creating openclaw-bun wrapper..."
cat > /usr/local/bin/openclaw-bun <<'SH'
#!/bin/sh
OPENCLAW_BIN="$(command -v openclaw)"
exec bun "$OPENCLAW_BIN" "$@"
SH
chmod +x /usr/local/bin/openclaw-bun
log_success "openclaw-bun ready"

# DWService agent bootstrap (download + chmod only)
log_info "Downloading DWService agent installer..."
cd /root
wget -N https://www.dwservice.net/download/dwagent.sh
chmod +x dwagent.sh
log_success "DWAgent installer downloaded to /root/dwagent.sh"

# Convenience aliases (Bun CLI + Node gateway)
log_info "Setting up aliases..."
cat >> ~/.bashrc <<'EOF'

# OpenClaw (Bun-wrapped CLI for speed)
alias oc='NODE_OPTIONS="--require /root/openclaw-shim.cjs" openclaw-bun'
alias oc-onboard='NODE_OPTIONS="--require /root/openclaw-shim.cjs" openclaw-bun onboard'
alias oc-tui='NODE_OPTIONS="--require /root/openclaw-shim.cjs" openclaw-bun tui'

# Gateway (recommended to keep Node for stability)
alias start-claw='NODE_OPTIONS="--require /root/openclaw-shim.cjs" openclaw gateway --bind loopback --port 18789 --verbose'
alias update-openclaw='npm update -g openclaw'
EOF

source ~/.bashrc

log_success "Ubuntu environment setup complete!"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         ✅ Installation Complete! ✅           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1) Open a NEW Termux session (swipe left)"
echo "2) Run: proot-distro login ubuntu"
echo "3) Start Gateway: start-claw"
echo "4) Fast CLI via Bun: oc-onboard / oc-tui"
echo ""
UBUNTU_SCRIPT

    chmod +x "$HOME/ubuntu_setup.sh"
    log_success "Setup script created"
}

# Execute Ubuntu setup
execute_ubuntu_setup() {
    log_step "Executing Ubuntu environment setup..."

    log_info "This will take 5-10 minutes depending on your device..."
    log_info "Please be patient and do not close Termux"

    if proot-distro login ubuntu -- /bin/bash -c "bash $HOME/ubuntu_setup.sh"; then
        log_success "Ubuntu setup completed successfully"
        rm -f "$HOME/ubuntu_setup.sh"
    else
        log_error "Ubuntu setup failed"
        log_info "Setup script saved at: $HOME/ubuntu_setup.sh"
        log_info "You can try running it manually:"
        log_info "  proot-distro login ubuntu"
        log_info "  bash ~/ubuntu_setup.sh"
        exit 1
    fi
}

# Create helper scripts
create_helper_scripts() {
    log_step "Creating helper scripts..."
    
    # Create launcher script
    cat > "$HOME/start-openclaw.sh" << 'LAUNCHER'
#!/data/data/com.termux/files/usr/bin/bash
echo "Starting OpenClaw..."
echo ""
echo "Opening Debian environment..."
proot-distro login debian
LAUNCHER
    chmod +x "$HOME/start-openclaw.sh"
    
    log_success "Helper scripts created in: $HOME"
}

# Show completion message
show_completion() {
    log_step "Installation Summary"
    
    echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                   ║${NC}"
    echo -e "${GREEN}║     🎉 OpenClaw Installation Complete! 🎉          ║${NC}"
    echo -e "${GREEN}║                                                   ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Note: This installer is a community tool.${NC}"
    echo -e "   OpenClaw framework © its original creators"
    echo ""
    echo -e "${CYAN}📝 Quick Start Guide:${NC}"
    echo ""
    echo -e "${YELLOW}Step 1:${NC} Start OpenClaw Gateway"
    echo "  $ proot-distro login debian"
    echo "  $ start-claw"
    echo ""
    echo -e "${YELLOW}Step 2:${NC} Open new Termux session (swipe left)"
    echo "  $ proot-distro login ubuntu"
    echo "  $ openclaw oc-tui"
    echo ""
    echo -e "${CYAN}📚 Available Commands:${NC}"
    echo "  start-claw       - Launch Node gateway"
    echo "  openclaw tui     - Open interface"
    echo "  openclaw onboard - Configure API"
    echo "  update-openclaw  - Update OpenClaw"
    echo ""
    echo -e "${CYAN}⚡ Performance Tip:${NC}"
    echo "  Run 'termux-wake-lock' in Termux to prevent throttling"
    echo ""
    echo -e "${CYAN}🐛 Issues?${NC}"
    echo "  Visit: ${BLUE}${REPO_URL}/issues${NC}"
    echo ""
}

# Parse command line arguments
REINSTALL=false
SKIP_UPDATE_CHECK=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --reinstall)
            REINSTALL=true
            shift
            ;;
        --skip-update-check)
            SKIP_UPDATE_CHECK=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --reinstall           Force reinstallation"
            echo "  --skip-update-check   Skip checking for updates"
            echo "  --help                Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Main installation flow
main() {
    show_banner
    
    if [ "$SKIP_UPDATE_CHECK" = "false" ]; then
        check_for_updates
    fi
    
    check_termux
    check_android_version
    check_storage
    
    install_termux_packages
    install_ubuntu
    create_ubuntu_setup
    execute_ubuntu_setup
    create_helper_scripts
    
    show_completion
}

# Run main installation
main "$@"

#!/bin/bash
set -e

echo "=================================================================="
echo "Installing dependencies for Solana development..."
echo "=================================================================="

# Update package lists
sudo apt-get update

# Install basic dependencies
sudo apt-get install -y \
    curl \
    wget \
    git \
    pkg-config \
    build-essential \
    libudev-dev \
    libssl-dev \
    jq \
    bc

# Install Solana CLI tools
echo "Installing Solana CLI tools..."
sh -c "$(curl -sSfL https://release.solana.com/v1.16.0/install)"

# Add Solana to PATH for this script
export PATH="/home/vscode/.local/share/solana/install/active_release/bin:$PATH"

# Add Solana to PATH permanently
echo 'export PATH="/home/vscode/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bashrc

# Configure Solana CLI to use devnet
solana config set --url https://api.devnet.solana.com

# Create a new Solana keypair if it doesn't exist
if [ ! -f ~/.config/solana/id.json ]; then
    echo "Creating a new Solana keypair..."
    mkdir -p ~/.config/solana
    solana-keygen new --no-bip39-passphrase -o ~/.config/solana/id.json
fi

# Install Anchor (Solana framework)
echo "Installing Anchor framework..."
cargo install --git https://github.com/coral-xyz/anchor avm --locked --force
avm install latest
avm use latest

# Install SPL Token CLI
echo "Installing SPL Token CLI..."
cargo install spl-token-cli

# Make all shell scripts executable
chmod +x /workspaces/*/*.sh

# Create keys directory if it doesn't exist
mkdir -p /workspaces/*/keys

# Check if demo keys exist and back them up if they do
echo "Checking for demo keys..."
KEY_DIR="/workspaces/*/keys"
KEY_FILES=("sender_wallet.json" "recipient_wallet.json" "tax_wallet.json" "swap_wallet.json")
BACKUP_NEEDED=false

for key_file in "${KEY_FILES[@]}"; do
    if ls $KEY_DIR/$key_file 1> /dev/null 2>&1; then
        echo "Found existing key: $key_file"
        BACKUP_NEEDED=true
    fi
done

# Create backup of existing keys if needed
if [ "$BACKUP_NEEDED" = true ]; then
    BACKUP_DIR="$KEY_DIR/backup_$(date +%Y%m%d%H%M%S)"
    echo "Creating backup of existing keys in $BACKUP_DIR"
    mkdir -p $BACKUP_DIR
    cp $KEY_DIR/*.json $BACKUP_DIR/ 2>/dev/null || true
    echo "Keys backed up successfully."
fi

echo "=================================================================="
echo "⚠️  SECURITY NOTICE ⚠️"
echo "=================================================================="
echo "The demo keys are publicly visible and should ONLY be used on devnet."
echo "DO NOT fund these wallets with real SOL or tokens on mainnet."
echo "For production use, generate your own keys using:"
echo "  solana-keygen new -o keys/wallet_name.json"
echo "=================================================================="
echo ""
echo "Development environment setup complete!"
echo "Your Solana address is: $(solana address)"
echo "You can request airdrop using: solana airdrop 2"
echo "Run './demo.sh' to start the demo"

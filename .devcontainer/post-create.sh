#!/bin/bash
set -e

echo "Installing dependencies for Solana development..."

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
chmod +x /workspaces/*/tax_token/*.sh

echo "Development environment setup complete!"
echo "Your Solana address is: $(solana address)"
echo "You can request airdrop using: solana airdrop 2"
echo "Run 'cd tax_token && ./demo.sh' to start the demo"

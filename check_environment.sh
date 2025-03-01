#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    local message="$2"
    local color=""
    
    case "$level" in
        "INFO")
            color=$GREEN
            ;;
        "WARN")
            color=$YELLOW
            ;;
        "ERROR")
            color=$RED
            ;;
    esac
    
    echo -e "${color}[${level}] ${message}${NC}"
}

# Header
echo "========================================================"
log "INFO" "TaxAI Token Demo Environment Check"
echo "========================================================"

# Check if Solana CLI is installed
if ! command -v solana &> /dev/null; then
    log "ERROR" "Solana CLI is not installed. Please install it first."
    exit 1
else
    SOLANA_VERSION=$(solana --version | head -n 1)
    log "INFO" "Solana CLI: ${SOLANA_VERSION}"
fi

# Check if SPL Token CLI is installed
if ! command -v spl-token &> /dev/null; then
    log "WARN" "SPL Token CLI is not installed. Some features may not work."
else
    SPL_VERSION=$(spl-token --version)
    log "INFO" "SPL Token CLI: ${SPL_VERSION}"
fi

# Check Solana network
NETWORK=$(solana config get | grep "RPC URL" | awk '{print $3}')
if [[ $NETWORK == *"devnet"* ]]; then
    log "INFO" "Network: Devnet (Correct)"
else
    log "WARN" "Network: $NETWORK (Not using devnet, this may cause issues)"
    log "INFO" "Run 'solana config set --url https://api.devnet.solana.com' to switch to devnet"
fi

# Check if keys exist
echo ""
log "INFO" "Checking wallet keys..."
KEYS_DIR="./keys"
REQUIRED_KEYS=("sender_wallet.json" "recipient_wallet.json" "tax_wallet.json" "swap_wallet.json")
MISSING_KEYS=false

# Ensure keys directory exists
if [[ ! -d "$KEYS_DIR" ]]; then
    log "INFO" "Creating keys directory"
    mkdir -p "$KEYS_DIR"
fi

for key in "${REQUIRED_KEYS[@]}"; do
    if [ -f "$KEYS_DIR/$key" ]; then
        PUBKEY=$(solana-keygen pubkey "$KEYS_DIR/$key" 2>/dev/null || echo "Error reading key")
        log "INFO" "Found $key: $PUBKEY"
    else
        log "WARN" "Missing $key in $KEYS_DIR directory"
        log "INFO" "Creating $key..."
        solana-keygen new --outfile "$KEYS_DIR/$key" --no-passphrase --force
        chmod 600 "$KEYS_DIR/$key"
        PUBKEY=$(solana-keygen pubkey "$KEYS_DIR/$key" 2>/dev/null || echo "Error reading key")
        log "INFO" "Created $key: $PUBKEY"
        # Fund the new wallet with devnet SOL
        log "INFO" "Funding new wallet with devnet SOL..."
        solana airdrop 1 "$PUBKEY" || log "WARN" "Failed to airdrop SOL. You may need to fund this wallet manually."
    fi
done

# Check for token keypair
if [[ ! -f "$KEYS_DIR/token-keypair.json" ]]; then
    log "WARN" "Missing token-keypair.json in $KEYS_DIR directory"
else
    PUBKEY=$(solana-keygen pubkey "$KEYS_DIR/token-keypair.json" 2>/dev/null || echo "Error reading key")
    log "INFO" "Found token-keypair.json: $PUBKEY"
fi

# Check for ETH proxy keypair
if [[ ! -f "$KEYS_DIR/ethp-keypair.json" ]]; then
    log "WARN" "Missing ethp-keypair.json in $KEYS_DIR directory"
else
    PUBKEY=$(solana-keygen pubkey "$KEYS_DIR/ethp-keypair.json" 2>/dev/null || echo "Error reading key")
    log "INFO" "Found ethp-keypair.json: $PUBKEY"
fi

# Check if configuration files exist
echo ""
log "INFO" "Checking configuration files..."
CONFIG_FILES=("token_config.json" "ethp_config.json")
MISSING_CONFIG=false

for config in "${CONFIG_FILES[@]}"; do
    if [ -f "$config" ]; then
        log "INFO" "Found $config"
    else
        log "ERROR" "Missing $config"
        MISSING_CONFIG=true
    fi
done

if [ "$MISSING_CONFIG" = true ]; then
    echo ""
    log "WARN" "Some configuration files are missing. You may need to create them first."
fi

# Check script permissions
echo ""
log "INFO" "Checking script permissions..."
SCRIPTS=(*.sh)
PERMISSION_ISSUES=false

for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ] && [ ! -x "$script" ]; then
        log "ERROR" "$script is not executable"
        PERMISSION_ISSUES=true
    fi
done

if [ "$PERMISSION_ISSUES" = true ]; then
    echo ""
    log "WARN" "Some scripts are not executable. Run 'chmod +x *.sh' to fix this."
else
    log "INFO" "All scripts have correct permissions"
fi

# Security warning
echo ""
echo "========================================================"
log "WARN" "SECURITY NOTICE"
echo "========================================================"
echo -e "${YELLOW}These are publicly visible devnet keys, do not fund them with actual mainnet tokens or SOL. If you use these scripts please provide your own keys with the same names (you'll need to change the keys that have their public key as the name in the scripts). I take no personal responsibility for any lost funds or transaction errors caused by this script. Please use at your own risk.${NC}"
echo ""

# Final summary
echo "========================================================"
if [ "$MISSING_KEYS" = true ] || [ "$MISSING_CONFIG" = true ] || [ "$PERMISSION_ISSUES" = true ]; then
    log "WARN" "Environment check completed with warnings. Please address the issues above."
else
    log "INFO" "Environment check completed successfully. You're ready to run the demo!"
    log "INFO" "Run './demo.sh' to start the demo"
fi
echo "========================================================"

#!/bin/bash
set -euo pipefail

# Default settings
FULL_SPEED=false
TRANSACTION_DELAY=1

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --full-speed)
            FULL_SPEED=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --full-speed    Disable transaction delays"
            echo "  --help          Display this help message"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Helper function to abbreviate addresses for better readability
abbreviate_address() {
    local address="$1"
    if [[ -z "$address" ]]; then
        echo "N/A"
        return
    fi
    
    local length=${#address}
    if [[ $length -le 12 ]]; then
        echo "$address"
    else
        echo "${address:0:6}...${address: -6}"
    fi
}

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color=""
    local output_stream=1
    
    case "$level" in
        "INFO")
            color='\e[32m'  # Green
            ;;
        "WARN")
            color='\e[33m'  # Yellow
            ;;
        "ERROR")
            color='\e[31m'  # Red
            output_stream=2
            ;;
    esac
    
    printf "${color}[%s] %s: %s\e[0m\n" "$level" "$timestamp" "$message" >&$output_stream
}

# Load configurations
load_configs() {
    log "INFO" "Loading token configurations"
    
    if [[ ! -f "token_config.json" ]]; then
        log "ERROR" "token_config.json not found. Please run create_taxai_token.sh first."
        exit 1
    fi
    
    if [[ ! -f "ethp_config.json" ]]; then
        log "ERROR" "ethp_config.json not found. Please run create_eth_proxy.sh first."
        exit 1
    fi
    
    # Load TaxAI token configuration
    TAXAI_TOKEN_ADDRESS=$(grep -o '"token_address": "[^"]*' token_config.json | cut -d'"' -f4)
    TAXAI_KEYPAIR=$(grep -o '"token_keypair": "[^"]*' token_config.json | cut -d'"' -f4)
    # Fix paths to be relative to the current directory
    TAXAI_KEYPAIR="./keys/$(basename "$TAXAI_KEYPAIR")"
    TAX_WALLET=$(grep -o '"tax_wallet": "[^"]*' token_config.json | cut -d'"' -f4)
    TAX_WALLET="./keys/$(basename "$TAX_WALLET")"
    TAX_WALLET_ADDRESS=$(grep -o '"tax_wallet_address": "[^"]*' token_config.json | cut -d'"' -f4)
    TAX_TOKEN_ACCOUNT=$(grep -o '"tax_token_account": "[^"]*' token_config.json | cut -d'"' -f4)
    TAX_PERCENTAGE=$(grep -o '"tax_percentage": [^,]*' token_config.json | cut -d':' -f2 | tr -d ' ')
    
    # Load ETH Proxy token configuration
    ETHP_TOKEN_ADDRESS=$(grep -o '"token_address": "[^"]*' ethp_config.json | cut -d'"' -f4)
    ETHP_KEYPAIR=$(grep -o '"token_keypair": "[^"]*' ethp_config.json | cut -d'"' -f4)
    ETHP_KEYPAIR="./keys/$(basename "$ETHP_KEYPAIR")"
    SWAP_WALLET=$(grep -o '"swap_wallet": "[^"]*' ethp_config.json | cut -d'"' -f4)
    SWAP_WALLET="./keys/$(basename "$SWAP_WALLET")"
    SWAP_WALLET_ADDRESS=$(grep -o '"swap_wallet_address": "[^"]*' ethp_config.json | cut -d'"' -f4)
    SWAP_TOKEN_ACCOUNT=$(grep -o '"swap_token_account": "[^"]*' ethp_config.json | cut -d'"' -f4)
    
    # Set paths for user wallets
    SENDER_WALLET="./keys/sender.json"
    RECIPIENT_WALLET="./keys/recipient.json"
    
    # Get addresses if wallet files exist
    if [[ -f "$SENDER_WALLET" ]]; then
        SENDER_ADDRESS=$(solana-keygen pubkey "$SENDER_WALLET")
    else
        SENDER_ADDRESS="N/A"
    fi
    
    if [[ -f "$RECIPIENT_WALLET" ]]; then
        RECIPIENT_ADDRESS=$(solana-keygen pubkey "$RECIPIENT_WALLET")
    else
        RECIPIENT_ADDRESS="N/A"
    fi
    
    log "INFO" "TaxAI Token Address: $(abbreviate_address "$TAXAI_TOKEN_ADDRESS")"
    log "INFO" "ETH Proxy Token Address: $(abbreviate_address "$ETHP_TOKEN_ADDRESS")"
}

# Function to add delay between transactions
transaction_delay() {
    if [[ "$FULL_SPEED" == "false" ]]; then
        sleep "$TRANSACTION_DELAY"
        log "INFO" "Waiting ${TRANSACTION_DELAY}s between transactions..."
    fi
}

# Reset token balances to initial state
reset_balances() {
    log "INFO" "Resetting token balances to initial state"
    
    # Step 1: Get current balances to determine what needs to be reset
    
    # Tax wallet balances
    solana config set --keypair "$TAX_WALLET" > /dev/null
    local TAX_TAXAI_BALANCE=0
    if spl-token accounts --verbose | grep -q "$TAXAI_TOKEN_ADDRESS"; then
        TAX_TAXAI_BALANCE=$(spl-token balance "$TAXAI_TOKEN_ADDRESS" 2>/dev/null || echo "0")
    fi
    
    local TAX_ETHP_BALANCE=0
    if spl-token accounts --verbose | grep -q "$ETHP_TOKEN_ADDRESS"; then
        TAX_ETHP_BALANCE=$(spl-token balance "$ETHP_TOKEN_ADDRESS" 2>/dev/null || echo "0")
    fi
    
    # Swap wallet balances
    solana config set --keypair "$SWAP_WALLET" > /dev/null
    local SWAP_TAXAI_BALANCE=0
    if spl-token accounts --verbose | grep -q "$TAXAI_TOKEN_ADDRESS"; then
        SWAP_TAXAI_BALANCE=$(spl-token balance "$TAXAI_TOKEN_ADDRESS" 2>/dev/null || echo "0")
    fi
    
    local SWAP_ETHP_BALANCE=0
    if spl-token accounts --verbose | grep -q "$ETHP_TOKEN_ADDRESS"; then
        SWAP_ETHP_BALANCE=$(spl-token balance "$ETHP_TOKEN_ADDRESS" 2>/dev/null || echo "0")
    fi
    
    # Sender wallet balances
    solana config set --keypair "$SENDER_WALLET" > /dev/null
    local SENDER_TAXAI_BALANCE=0
    if spl-token accounts --verbose | grep -q "$TAXAI_TOKEN_ADDRESS"; then
        SENDER_TAXAI_BALANCE=$(spl-token balance "$TAXAI_TOKEN_ADDRESS" 2>/dev/null || echo "0")
    fi
    
    # Recipient wallet balances
    solana config set --keypair "$RECIPIENT_WALLET" > /dev/null
    local RECIPIENT_TAXAI_BALANCE=0
    if spl-token accounts --verbose | grep -q "$TAXAI_TOKEN_ADDRESS"; then
        RECIPIENT_TAXAI_BALANCE=$(spl-token balance "$TAXAI_TOKEN_ADDRESS" 2>/dev/null || echo "0")
    fi
    
    # Step 2: Reset balances to initial state
    
    # Reset TaxAI token balances
    log "INFO" "Resetting TaxAI token balances"
    
    # Reset tax wallet TaxAI balance to 0
    if [[ $TAX_TAXAI_BALANCE -gt 0 ]]; then
        solana config set --keypair "$TAX_WALLET" > /dev/null
        log "INFO" "Transferring $TAX_TAXAI_BALANCE TaxAI tokens from tax wallet to token authority"
        spl-token transfer --allow-unfunded-recipient "$TAXAI_TOKEN_ADDRESS" "$TAX_TAXAI_BALANCE" "$TAXAI_KEYPAIR" --fund-recipient
        transaction_delay
    fi
    
    # Reset swap wallet TaxAI balance to 0
    if [[ $SWAP_TAXAI_BALANCE -gt 0 ]]; then
        solana config set --keypair "$SWAP_WALLET" > /dev/null
        log "INFO" "Transferring $SWAP_TAXAI_BALANCE TaxAI tokens from swap wallet to token authority"
        spl-token transfer --allow-unfunded-recipient "$TAXAI_TOKEN_ADDRESS" "$SWAP_TAXAI_BALANCE" "$TAXAI_KEYPAIR" --fund-recipient
        transaction_delay
    fi
    
    # Reset ETH Proxy token balances
    log "INFO" "Resetting ETH Proxy token balances"
    
    # Reset tax wallet ETH Proxy balance to 0
    if [[ $TAX_ETHP_BALANCE -gt 0 ]]; then
        solana config set --keypair "$TAX_WALLET" > /dev/null
        log "INFO" "Transferring $TAX_ETHP_BALANCE ETH Proxy tokens from tax wallet to token authority"
        spl-token transfer --allow-unfunded-recipient "$ETHP_TOKEN_ADDRESS" "$TAX_ETHP_BALANCE" "$ETHP_KEYPAIR" --fund-recipient
        transaction_delay
    fi
    
    # Reset swap wallet ETH Proxy balance to initial state (100000)
    solana config set --keypair "$ETHP_KEYPAIR" > /dev/null
    local SWAP_ETHP_NEEDED=$((100000 - SWAP_ETHP_BALANCE))
    if [[ $SWAP_ETHP_NEEDED -gt 0 ]]; then
        log "INFO" "Transferring $SWAP_ETHP_NEEDED ETH Proxy tokens to swap wallet"
        spl-token transfer --allow-unfunded-recipient "$ETHP_TOKEN_ADDRESS" "$SWAP_ETHP_NEEDED" "$SWAP_WALLET_ADDRESS" --fund-recipient
        transaction_delay
    elif [[ $SWAP_ETHP_NEEDED -lt 0 ]]; then
        solana config set --keypair "$SWAP_WALLET" > /dev/null
        log "INFO" "Transferring $((-SWAP_ETHP_NEEDED)) ETH Proxy tokens from swap wallet to token authority"
        spl-token transfer --allow-unfunded-recipient "$ETHP_TOKEN_ADDRESS" $((-SWAP_ETHP_NEEDED)) "$ETHP_KEYPAIR" --fund-recipient
        transaction_delay
    fi
    
    # Reset sender and recipient TaxAI balances to initial state (50000 each)
    solana config set --keypair "$TAXAI_KEYPAIR" > /dev/null
    
    # Reset sender TaxAI balance
    local SENDER_TAXAI_NEEDED=$((100000 - SENDER_TAXAI_BALANCE))
    if [[ $SENDER_TAXAI_NEEDED -gt 0 ]]; then
        log "INFO" "Transferring $SENDER_TAXAI_NEEDED TaxAI tokens to sender wallet"
        spl-token transfer --allow-unfunded-recipient "$TAXAI_TOKEN_ADDRESS" "$SENDER_TAXAI_NEEDED" "$SENDER_ADDRESS" --fund-recipient
        transaction_delay
    elif [[ $SENDER_TAXAI_NEEDED -lt 0 ]]; then
        solana config set --keypair "$SENDER_WALLET" > /dev/null
        log "INFO" "Transferring $((-SENDER_TAXAI_NEEDED)) TaxAI tokens from sender wallet to token authority"
        spl-token transfer --allow-unfunded-recipient "$TAXAI_TOKEN_ADDRESS" $((-SENDER_TAXAI_NEEDED)) "$TAXAI_KEYPAIR" --fund-recipient
        transaction_delay
    fi
    
    # Reset recipient TaxAI balance
    solana config set --keypair "$TAXAI_KEYPAIR" > /dev/null
    local RECIPIENT_TAXAI_NEEDED=$((0 - RECIPIENT_TAXAI_BALANCE))
    if [[ $RECIPIENT_TAXAI_NEEDED -gt 0 ]]; then
        log "INFO" "Transferring $RECIPIENT_TAXAI_NEEDED TaxAI tokens to recipient wallet"
        spl-token transfer --allow-unfunded-recipient "$TAXAI_TOKEN_ADDRESS" "$RECIPIENT_TAXAI_NEEDED" "$RECIPIENT_ADDRESS" --fund-recipient
        transaction_delay
    elif [[ $RECIPIENT_TAXAI_NEEDED -lt 0 ]]; then
        solana config set --keypair "$RECIPIENT_WALLET" > /dev/null
        log "INFO" "Transferring $((-RECIPIENT_TAXAI_NEEDED)) TaxAI tokens from recipient wallet to token authority"
        spl-token transfer --allow-unfunded-recipient "$TAXAI_TOKEN_ADDRESS" $((-RECIPIENT_TAXAI_NEEDED)) "$TAXAI_KEYPAIR" --fund-recipient
        transaction_delay
    fi
    
    log "INFO" "Token balances reset to initial state"
}

# Main function
main() {
    log "INFO" "Starting demo reset"
    
    # Display speed mode
    if [[ "$FULL_SPEED" == "true" ]]; then
        log "INFO" "Running in FULL SPEED mode (no transaction delays)"
    else
        log "INFO" "Running with ${TRANSACTION_DELAY}s delay between transactions (use --full-speed to disable)"
    fi
    
    # Load configurations
    load_configs
    
    # Reset token balances
    reset_balances
    
    # Display final balances
    log "INFO" "Displaying final balances after reset"
    ./display_balances.sh
    
    log "INFO" "Demo reset completed"
}

# Run main function
main

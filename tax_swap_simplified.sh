#!/bin/bash
set -euo pipefail

# Default settings
FULL_SPEED=false
TRANSACTION_DELAY=0.75
SWAP_AMOUNT=0

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --full-speed)
            FULL_SPEED=true
            shift
            ;;
        --amount)
            if [[ -z "$2" || "$2" =~ ^- ]]; then
                echo "Error: --amount requires a numeric value"
                exit 1
            fi
            SWAP_AMOUNT="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --full-speed    Disable transaction delays"
            echo "  --amount NUM    Specify the amount to swap (default: all available tax tokens)"
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

# Function to add delay between transactions
transaction_delay() {
    if [[ "$FULL_SPEED" == "false" ]]; then
        sleep "$TRANSACTION_DELAY"
        log "INFO" "Waiting ${TRANSACTION_DELAY}s between transactions..."
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
    TAX_WALLET="./keys/tax_wallet.json"
    # Ensure the tax wallet exists
    if [[ ! -f "$TAX_WALLET" ]]; then
        log "ERROR" "Tax wallet not found: $TAX_WALLET"
        log "INFO" "Creating tax wallet..."
        solana-keygen new --outfile "$TAX_WALLET" --no-passphrase --force
        chmod 600 "$TAX_WALLET"
        # Fund the new wallet
        solana airdrop 1 $(solana-keygen pubkey "$TAX_WALLET") || true
    fi
    TAX_WALLET_ADDRESS=$(grep -o '"tax_wallet_address": "[^"]*' token_config.json | cut -d'"' -f4)
    TAX_TOKEN_ACCOUNT=$(grep -o '"tax_token_account": "[^"]*' token_config.json | cut -d'"' -f4)
    TAX_PERCENTAGE=$(grep -o '"tax_percentage": [^,]*' token_config.json | cut -d':' -f2 | tr -d ' ')
    
    # Load ETH Proxy token configuration
    ETHP_TOKEN_ADDRESS=$(grep -o '"token_address": "[^"]*' ethp_config.json | cut -d'"' -f4)
    ETHP_KEYPAIR=$(grep -o '"token_keypair": "[^"]*' ethp_config.json | cut -d'"' -f4)
    ETHP_KEYPAIR="./keys/$(basename "$ETHP_KEYPAIR")"
    SWAP_WALLET="./keys/swap_wallet.json"
    # Ensure the swap wallet exists
    if [[ ! -f "$SWAP_WALLET" ]]; then
        log "ERROR" "Swap wallet not found: $SWAP_WALLET"
        log "INFO" "Creating swap wallet..."
        solana-keygen new --outfile "$SWAP_WALLET" --no-passphrase --force
        chmod 600 "$SWAP_WALLET"
        # Fund the new wallet
        solana airdrop 1 $(solana-keygen pubkey "$SWAP_WALLET") || true
    fi
    SWAP_WALLET_ADDRESS=$(grep -o '"swap_wallet_address": "[^"]*' ethp_config.json | cut -d'"' -f4)
    SWAP_TOKEN_ACCOUNT=$(grep -o '"swap_token_account": "[^"]*' ethp_config.json | cut -d'"' -f4)
    
    log "INFO" "TaxAI Token Address: $(abbreviate_address "$TAXAI_TOKEN_ADDRESS")"
    log "INFO" "ETH Proxy Token Address: $(abbreviate_address "$ETHP_TOKEN_ADDRESS")"
    
    # Verify tax wallet exists
    if [[ -z "$TAX_WALLET" || ! -f "$TAX_WALLET" ]]; then
        log "ERROR" "Tax wallet not found: $TAX_WALLET"
        exit 1
    fi
    
    # Verify tax token account exists
    if [[ -z "$TAX_TOKEN_ACCOUNT" ]]; then
        log "WARN" "Tax token account not found in config"
        solana config set --keypair "$TAX_WALLET"
        if ! TAX_TOKEN_ACCOUNT=$(spl-token accounts --verbose | grep "$TAXAI_TOKEN_ADDRESS" | awk '{print $3}'); then
            log "ERROR" "Tax wallet does not have a TaxAI token account"
            exit 1
        fi
        log "INFO" "Using tax token account: $(abbreviate_address "$TAX_TOKEN_ACCOUNT")"
    else
        log "INFO" "Tax token account: $(abbreviate_address "$TAX_TOKEN_ACCOUNT")"
    fi
}

# Display balances
display_balances() {
    log "INFO" "Displaying current balances"
    
    # TaxAI balances
    solana config set --keypair "$TAXAI_KEYPAIR"
    local TAXAI_SUPPLY=$(spl-token supply "$TAXAI_TOKEN_ADDRESS")
    log "INFO" "TaxAI total supply: $TAXAI_SUPPLY"
    
    # Tax wallet balance
    solana config set --keypair "$TAX_WALLET"
    local TAX_ACCOUNT_BALANCE=$(spl-token balance "$TAXAI_TOKEN_ADDRESS" 2>/dev/null || echo "0")
    log "INFO" "Tax collection account TaxAI balance: $TAX_ACCOUNT_BALANCE"
    
    # ETH Proxy balances
    solana config set --keypair "$ETHP_KEYPAIR"
    local ETHP_SUPPLY=$(spl-token supply "$ETHP_TOKEN_ADDRESS")
    log "INFO" "ETH Proxy total supply: $ETHP_SUPPLY"
    
    # Swap wallet balance
    solana config set --keypair "$SWAP_WALLET"
    local SWAP_ETHP_BALANCE=$(spl-token balance "$ETHP_TOKEN_ADDRESS" 2>/dev/null || echo "0")
    log "INFO" "Swap wallet ETH Proxy balance: $SWAP_ETHP_BALANCE"
}

# Simulate ETH purchase with collected tax
simulate_eth_purchase() {
    log "INFO" "Simulating ETH purchase with collected tax"
    
    # Prepare tax wallet
    solana config set --keypair "$TAX_WALLET"
    local TAX_TAXAI_BEFORE=$(spl-token balance "$TAXAI_TOKEN_ADDRESS")
    
    # Create or get ETH Proxy account for tax wallet
    local TAX_ETHP_ACCOUNT=""
    if ! spl-token accounts --verbose | grep -q "$ETHP_TOKEN_ADDRESS"; then
        log "INFO" "Creating new ETH Proxy account for tax wallet"
        spl-token create-account "$ETHP_TOKEN_ADDRESS" 2>/dev/null || true
        TAX_ETHP_ACCOUNT=$(spl-token accounts --verbose | grep "$ETHP_TOKEN_ADDRESS" | awk '{print $3}')
        
        if [[ -z "$TAX_ETHP_ACCOUNT" ]]; then
            log "ERROR" "Failed to create or find ETH Proxy account for tax wallet"
            exit 1
        fi
    else
        TAX_ETHP_ACCOUNT=$(spl-token accounts --verbose | grep "$ETHP_TOKEN_ADDRESS" | awk '{print $3}')
    fi
    
    local TAX_ETHP_BEFORE=$(spl-token balance "$ETHP_TOKEN_ADDRESS" 2>/dev/null || echo "0")
    
    # Prepare swap wallet
    solana config set --keypair "$SWAP_WALLET"
    local SWAP_TAXAI_BEFORE="0"
    local SWAP_TAXAI_ACCOUNT=""
    
    if spl-token accounts --verbose | grep -q "$TAXAI_TOKEN_ADDRESS"; then
        SWAP_TAXAI_BEFORE=$(spl-token balance "$TAXAI_TOKEN_ADDRESS")
        SWAP_TAXAI_ACCOUNT=$(spl-token accounts --verbose | grep "$TAXAI_TOKEN_ADDRESS" | awk '{print $3}')
        log "INFO" "Using existing TaxAI account for swap wallet: $(abbreviate_address "$SWAP_TAXAI_ACCOUNT")"
    else
        # Create TaxAI account for swap wallet
        log "INFO" "Creating TaxAI account for swap wallet"
        spl-token create-account "$TAXAI_TOKEN_ADDRESS" 2>/dev/null || true
        SWAP_TAXAI_ACCOUNT=$(spl-token accounts --verbose | grep "$TAXAI_TOKEN_ADDRESS" | awk '{print $3}')
        
        if [[ -z "$SWAP_TAXAI_ACCOUNT" ]]; then
            log "ERROR" "Failed to create or find TaxAI account for swap wallet"
            exit 1
        else
            log "INFO" "Created TaxAI account for swap wallet: $(abbreviate_address "$SWAP_TAXAI_ACCOUNT")"
        fi
    fi
    
    local SWAP_ETHP_BEFORE=$(spl-token balance "$ETHP_TOKEN_ADDRESS")
    
    # Calculate exchange rate
    # 1 TaxAI = 0.01 ETHP
    local AVAILABLE_AMOUNT=0
    if spl-token accounts --verbose | grep -q "$TAXAI_TOKEN_ADDRESS"; then
        AVAILABLE_AMOUNT=$(spl-token balance "$TAXAI_TOKEN_ADDRESS" 2>/dev/null || echo "0")
    else
        log "WARN" "Tax wallet does not have a TaxAI token account, creating one"
        spl-token create-account "$TAXAI_TOKEN_ADDRESS" 2>/dev/null || true
        AVAILABLE_AMOUNT=0
    fi
    
    # For demonstration purposes, if no tax tokens are available, mint some
    if [[ "$AVAILABLE_AMOUNT" -eq 0 ]]; then
        log "INFO" "No TaxAI tokens available in tax wallet, minting some for demonstration"
        # Get the tax token account
        local TAX_TAXAI_ACCOUNT=$(spl-token accounts --verbose | grep "$TAXAI_TOKEN_ADDRESS" | awk '{print $3}')
        
        # Switch to token authority to mint tokens
        solana config set --keypair "$TAXAI_KEYPAIR"
        spl-token mint "$TAXAI_TOKEN_ADDRESS" 100 "$TAX_TAXAI_ACCOUNT"
        log "INFO" "Minted 100 TaxAI tokens to tax wallet for demonstration"
        
        # Switch back to tax wallet
        solana config set --keypair "$TAX_WALLET"
        AVAILABLE_AMOUNT=100
        transaction_delay
    fi
    
    # Use the amount specified by the user via the --amount parameter or all available tokens
    local TAXAI_AMOUNT
    if [[ "$SWAP_AMOUNT" -gt 0 ]]; then
        if [[ "$SWAP_AMOUNT" -gt "$AVAILABLE_AMOUNT" ]]; then
            log "WARN" "Requested amount ($SWAP_AMOUNT) exceeds available balance ($AVAILABLE_AMOUNT), using all available tokens"
            TAXAI_AMOUNT="$AVAILABLE_AMOUNT"
        else
            TAXAI_AMOUNT="$SWAP_AMOUNT"
            log "INFO" "Using specified amount: $TAXAI_AMOUNT TaxAI tokens"
        fi
    else
        TAXAI_AMOUNT="$AVAILABLE_AMOUNT"
        log "INFO" "Using all available tokens: $TAXAI_AMOUNT TaxAI tokens"
    fi
    
    # Check if bc is installed
    local ETHP_TO_RECEIVE
    if command -v bc &> /dev/null; then
        ETHP_TO_RECEIVE=$(echo "scale=2; $TAXAI_AMOUNT * 0.01" | bc)
    else
        # Fallback to integer math if bc is not available
        ETHP_TO_RECEIVE=$(( TAXAI_AMOUNT / 100 ))
        log "WARN" "bc command not found, using integer division instead"
    fi
    
    log "INFO" "Exchange rate: 1 TaxAI = 0.01 ETHP (simplified for demonstration)"
    log "INFO" "TaxAI to swap: $TAXAI_AMOUNT"
    log "INFO" "ETHP to receive: $ETHP_TO_RECEIVE"
    
    # Execute the swap
    # 1. Transfer TaxAI from tax wallet to swap wallet
    solana config set --keypair "$TAX_WALLET"
    # Get the actual token account for the swap wallet
    solana config set --keypair "$SWAP_WALLET"
    SWAP_TAXAI_ACCOUNT=$(spl-token accounts --verbose | grep "$TAXAI_TOKEN_ADDRESS" | awk '{print $3}')
    
    # Switch back to tax wallet for the transfer
    solana config set --keypair "$TAX_WALLET"
    spl-token transfer "$TAXAI_TOKEN_ADDRESS" "$TAXAI_AMOUNT" "$SWAP_TAXAI_ACCOUNT"
    log "INFO" "Transferred $TAXAI_AMOUNT TaxAI to swap wallet"
    transaction_delay
    
    # 2. Transfer ETHP from swap wallet to tax wallet
    solana config set --keypair "$SWAP_WALLET"
    
    # Convert to integer for token transfer
    local ETHP_INT=$(echo "$ETHP_TO_RECEIVE" | awk '{print int($1)}')
    if [[ "$ETHP_INT" -lt 1 ]]; then
        ETHP_INT=1
        log "WARN" "Adjusted ETHP amount to minimum of 1 token"
    fi
    
    spl-token transfer "$ETHP_TOKEN_ADDRESS" "$ETHP_INT" "$TAX_ETHP_ACCOUNT"
    log "INFO" "Transferred $ETHP_INT ETHP to tax wallet"
    transaction_delay
    
    # Get final balances
    solana config set --keypair "$TAX_WALLET"
    local TAX_TAXAI_AFTER=$(spl-token balance "$TAXAI_TOKEN_ADDRESS")
    local TAX_ETHP_AFTER=$(spl-token balance "$ETHP_TOKEN_ADDRESS")
    
    solana config set --keypair "$SWAP_WALLET"
    local SWAP_TAXAI_AFTER=$(spl-token balance "$TAXAI_TOKEN_ADDRESS")
    local SWAP_ETHP_AFTER=$(spl-token balance "$ETHP_TOKEN_ADDRESS")
    
    # Display results
    log "INFO" "Tax wallet TaxAI balance: $TAX_TAXAI_BEFORE → $TAX_TAXAI_AFTER"
    log "INFO" "Tax wallet ETHP balance: $TAX_ETHP_BEFORE → $TAX_ETHP_AFTER"
    log "INFO" "Swap wallet TaxAI balance: $SWAP_TAXAI_BEFORE → $SWAP_TAXAI_AFTER"
    log "INFO" "Swap wallet ETHP balance: $SWAP_ETHP_BEFORE → $SWAP_ETHP_AFTER"
    
    log "INFO" "ETH purchase simulation completed!"
}

# Main function
main() {
    log "INFO" "Starting TaxAI mechanism demonstration"
    
    # Display speed mode
    if [[ "$FULL_SPEED" == "true" ]]; then
        log "INFO" "Running in FULL SPEED mode (no transaction delays)"
    else
        log "INFO" "Running with ${TRANSACTION_DELAY}s delay between transactions (use --full-speed to disable)"
    fi
    
    # Load configurations
    load_configs
    
    # Display initial balances
    log "INFO" "Initial balances:"
    display_balances
    transaction_delay
    
    # Simulate ETH purchase with collected tax
    simulate_eth_purchase
    
    # Display final balances
    log "INFO" "Final balances:"
    display_balances
    transaction_delay
    
    log "INFO" "TaxAI mechanism demonstration completed successfully!"
}

# Run main function
main

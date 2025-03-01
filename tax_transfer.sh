#!/bin/bash
set -euo pipefail

# Default settings
FULL_SPEED=false
TRANSACTION_DELAY=0.75

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
    
    log "INFO" "TaxAI Token Address: $(abbreviate_address "$TAXAI_TOKEN_ADDRESS")"
    log "INFO" "Tax Percentage: $TAX_PERCENTAGE%"
    
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

# Create user wallets for demonstration
create_user_wallets() {
    log "INFO" "Creating user wallets for demonstration"
    
    # Create sender wallet
    SENDER_WALLET="./keys/sender.json"
    if [[ ! -f "$SENDER_WALLET" ]]; then
        solana-keygen new --outfile "$SENDER_WALLET" --no-passphrase --force
        chmod 600 "$SENDER_WALLET"
    fi
    SENDER_ADDRESS=$(solana-keygen pubkey "$SENDER_WALLET")
    log "INFO" "Sender wallet: $(abbreviate_address "$SENDER_ADDRESS")"
    
    # Create recipient wallet
    RECIPIENT_WALLET="./keys/recipient.json"
    if [[ ! -f "$RECIPIENT_WALLET" ]]; then
        solana-keygen new --outfile "$RECIPIENT_WALLET" --no-passphrase --force
        chmod 600 "$RECIPIENT_WALLET"
    fi
    RECIPIENT_ADDRESS=$(solana-keygen pubkey "$RECIPIENT_WALLET")
    log "INFO" "Recipient wallet: $(abbreviate_address "$RECIPIENT_ADDRESS")"
    
    # Fund sender wallet
    solana config set --keypair "$TAXAI_KEYPAIR"
    solana transfer --allow-unfunded-recipient "$SENDER_ADDRESS" 0.1
    
    # Fund recipient wallet
    solana transfer --allow-unfunded-recipient "$RECIPIENT_ADDRESS" 0.1
    
    # Create or get token accounts for sender
    solana config set --keypair "$SENDER_WALLET"
    # Check if sender already has a TaxAI account
    SENDER_TAXAI_ACCOUNT=""
    if spl-token accounts --verbose | grep -q "$TAXAI_TOKEN_ADDRESS"; then
        # Get the token account address using verbose output
        SENDER_TAXAI_ACCOUNT=$(spl-token accounts --verbose | grep "$TAXAI_TOKEN_ADDRESS" | awk '{print $3}')
        log "INFO" "Using existing sender TaxAI account: $(abbreviate_address "$SENDER_TAXAI_ACCOUNT")"
    else
        # Create a new token account
        log "INFO" "Creating new TaxAI account for sender"
        SENDER_TAXAI_ACCOUNT=$(spl-token create-account "$TAXAI_TOKEN_ADDRESS" 2>/dev/null | grep "Creating account" | awk '{print $3}')
        if [[ -z "$SENDER_TAXAI_ACCOUNT" ]]; then
            # If we couldn't parse the output, try to get it from the accounts list
            spl-token create-account "$TAXAI_TOKEN_ADDRESS" 2>/dev/null || true
            SENDER_TAXAI_ACCOUNT=$(spl-token accounts --verbose | grep "$TAXAI_TOKEN_ADDRESS" | awk '{print $3}')
        fi
        log "INFO" "Created sender TaxAI account: $(abbreviate_address "$SENDER_TAXAI_ACCOUNT")"
    fi
    
    # Verify we got a valid account
    if [[ -z "$SENDER_TAXAI_ACCOUNT" ]]; then
        log "ERROR" "Failed to get a valid token account for sender"
        exit 1
    fi
    
    # Create or get token accounts for recipient
    solana config set --keypair "$RECIPIENT_WALLET"
    # Check if recipient already has a TaxAI account
    RECIPIENT_TAXAI_ACCOUNT=""
    if spl-token accounts --verbose | grep -q "$TAXAI_TOKEN_ADDRESS"; then
        # Get the token account address using verbose output
        RECIPIENT_TAXAI_ACCOUNT=$(spl-token accounts --verbose | grep "$TAXAI_TOKEN_ADDRESS" | awk '{print $3}')
        log "INFO" "Using existing recipient TaxAI account: $(abbreviate_address "$RECIPIENT_TAXAI_ACCOUNT")"
    else
        # Create a new token account
        log "INFO" "Creating new TaxAI account for recipient"
        RECIPIENT_TAXAI_ACCOUNT=$(spl-token create-account "$TAXAI_TOKEN_ADDRESS" 2>/dev/null | grep "Creating account" | awk '{print $3}')
        if [[ -z "$RECIPIENT_TAXAI_ACCOUNT" ]]; then
            # If we couldn't parse the output, try to get it from the accounts list
            spl-token create-account "$TAXAI_TOKEN_ADDRESS" 2>/dev/null || true
            RECIPIENT_TAXAI_ACCOUNT=$(spl-token accounts --verbose | grep "$TAXAI_TOKEN_ADDRESS" | awk '{print $3}')
        fi
        log "INFO" "Created recipient TaxAI account: $(abbreviate_address "$RECIPIENT_TAXAI_ACCOUNT")"
    fi
    
    # Verify we got a valid account
    if [[ -z "$RECIPIENT_TAXAI_ACCOUNT" ]]; then
        log "ERROR" "Failed to get a valid token account for recipient"
        exit 1
    fi
    
    # Transfer initial TaxAI tokens to sender if needed
    solana config set --keypair "$SENDER_WALLET"
    SENDER_CURRENT_BALANCE=$(spl-token balance "$TAXAI_TOKEN_ADDRESS" 2>/dev/null || echo "0")
    
    if [[ "$SENDER_CURRENT_BALANCE" == "0" ]]; then
        solana config set --keypair "$TAXAI_KEYPAIR"
        spl-token transfer "$TAXAI_TOKEN_ADDRESS" 100000 "$SENDER_TAXAI_ACCOUNT" --allow-unfunded-recipient
        log "INFO" "Transferred 100,000 TaxAI tokens to sender"
        transaction_delay
    else
        log "INFO" "Sender already has $SENDER_CURRENT_BALANCE TaxAI tokens, skipping transfer"
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
    
    # Sender balance
    solana config set --keypair "$SENDER_WALLET"
    local SENDER_BALANCE=$(spl-token balance "$TAXAI_TOKEN_ADDRESS" 2>/dev/null || echo "0")
    log "INFO" "Sender TaxAI balance: $SENDER_BALANCE"
    
    # Recipient balance
    solana config set --keypair "$RECIPIENT_WALLET"
    local RECIPIENT_BALANCE=$(spl-token balance "$TAXAI_TOKEN_ADDRESS" 2>/dev/null || echo "0")
    log "INFO" "Recipient TaxAI balance: $RECIPIENT_BALANCE"
}

# Simulate a transfer with tax
simulate_transfer() {
    log "INFO" "Simulating a transfer with tax"
    
    # Get sender and recipient token accounts
    solana config set --keypair "$SENDER_WALLET"
    if ! SENDER_TAXAI_ACCOUNT=$(spl-token accounts --verbose | grep "$TAXAI_TOKEN_ADDRESS" | awk '{print $3}'); then
        log "ERROR" "Sender does not have a TaxAI token account"
        exit 1
    fi
    
    solana config set --keypair "$RECIPIENT_WALLET"
    if ! RECIPIENT_TAXAI_ACCOUNT=$(spl-token accounts --verbose | grep "$TAXAI_TOKEN_ADDRESS" | awk '{print $3}'); then
        log "WARN" "Recipient does not have a TaxAI token account, creating one"
        spl-token create-account "$TAXAI_TOKEN_ADDRESS" 2>/dev/null || true
        RECIPIENT_TAXAI_ACCOUNT=$(spl-token accounts --verbose | grep "$TAXAI_TOKEN_ADDRESS" | awk '{print $3}')
    fi
    
    # Get initial balances
    solana config set --keypair "$SENDER_WALLET"
    local SENDER_BALANCE_BEFORE=$(spl-token balance "$TAXAI_TOKEN_ADDRESS")
    
    solana config set --keypair "$RECIPIENT_WALLET"
    local RECIPIENT_BALANCE_BEFORE=$(spl-token balance "$TAXAI_TOKEN_ADDRESS" 2>/dev/null || echo "0")
    
    solana config set --keypair "$TAX_WALLET"
    local TAX_BALANCE_BEFORE=$(spl-token balance "$TAXAI_TOKEN_ADDRESS" 2>/dev/null || echo "0")
    
    # Calculate transfer amount and tax
    local TRANSFER_AMOUNT=10000
    # Use bc for floating point arithmetic
    if command -v bc &> /dev/null; then
        local TAX_AMOUNT=$(echo "scale=0; $TRANSFER_AMOUNT * $TAX_PERCENTAGE / 100" | bc)
    else
        # Fallback to integer math if bc is not available
        # Convert percentage to integer by multiplying by 10
        local TAX_PERCENTAGE_INT=$(echo "$TAX_PERCENTAGE" | awk '{printf "%d", $1*10}')
        local TAX_AMOUNT=$(( TRANSFER_AMOUNT * TAX_PERCENTAGE_INT / 1000 ))
    fi
    local RECIPIENT_AMOUNT=$(( TRANSFER_AMOUNT - TAX_AMOUNT ))
    
    log "INFO" "Transfer amount: $TRANSFER_AMOUNT TaxAI"
    log "INFO" "Tax amount (${TAX_PERCENTAGE}%): $TAX_AMOUNT TaxAI"
    log "INFO" "Recipient amount: $RECIPIENT_AMOUNT TaxAI"
    
    # Execute transfer
    solana config set --keypair "$SENDER_WALLET"
    
    # First transfer to recipient
    spl-token transfer "$TAXAI_TOKEN_ADDRESS" "$RECIPIENT_AMOUNT" "$RECIPIENT_TAXAI_ACCOUNT"
    log "INFO" "Transferred $RECIPIENT_AMOUNT TaxAI to recipient"
    transaction_delay
    
    # Then transfer tax
    spl-token transfer "$TAXAI_TOKEN_ADDRESS" "$TAX_AMOUNT" "$TAX_TOKEN_ACCOUNT"
    log "INFO" "Transferred $TAX_AMOUNT TaxAI to tax collection account"
    transaction_delay
    
    # Get final balances
    solana config set --keypair "$SENDER_WALLET"
    local SENDER_BALANCE_AFTER=$(spl-token balance "$TAXAI_TOKEN_ADDRESS")
    
    solana config set --keypair "$RECIPIENT_WALLET"
    local RECIPIENT_BALANCE_AFTER=$(spl-token balance "$TAXAI_TOKEN_ADDRESS")
    
    solana config set --keypair "$TAX_WALLET"
    local TAX_BALANCE_AFTER=$(spl-token balance "$TAXAI_TOKEN_ADDRESS")
    
    # Display results
    log "INFO" "Sender balance: $SENDER_BALANCE_BEFORE → $SENDER_BALANCE_AFTER"
    log "INFO" "Recipient balance: $RECIPIENT_BALANCE_BEFORE → $RECIPIENT_BALANCE_AFTER"
    log "INFO" "Tax collection balance: $TAX_BALANCE_BEFORE → $TAX_BALANCE_AFTER"
    
    log "INFO" "Transfer simulation completed!"
}

# Main function
main() {
    log "INFO" "Starting TaxAI transfer demonstration"
    
    # Display speed mode
    if [[ "$FULL_SPEED" == "true" ]]; then
        log "INFO" "Running in FULL SPEED mode (no transaction delays)"
    else
        log "INFO" "Running with ${TRANSACTION_DELAY}s delay between transactions (use --full-speed to disable)"
    fi
    
    # Load configurations
    load_configs
    
    # Create user wallets
    create_user_wallets
    
    # Display initial balances
    log "INFO" "Initial balances:"
    display_balances
    
    # Simulate a transfer with tax
    simulate_transfer
    
    # Display balances after transfer
    log "INFO" "Balances after transfer:"
    display_balances
    
    log "INFO" "TaxAI transfer demonstration completed successfully!"
}

# Run main function
main

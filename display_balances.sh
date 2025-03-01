#!/bin/bash
set -euo pipefail

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
    
    if [[ ! -f "../token_config.json" ]]; then
        log "ERROR" "token_config.json not found. Please run create_taxai_token.sh first."
        exit 1
    fi
    
    if [[ ! -f "../ethp_config.json" ]]; then
        log "ERROR" "ethp_config.json not found. Please run create_eth_proxy.sh first."
        exit 1
    fi
    
    # Load TaxAI token configuration
    TAXAI_TOKEN_ADDRESS=$(grep -o '"token_address": "[^"]*' ../token_config.json | cut -d'"' -f4)
    TAXAI_KEYPAIR=$(grep -o '"token_keypair": "[^"]*' ../token_config.json | cut -d'"' -f4)
    TAXAI_KEYPAIR="../${TAXAI_KEYPAIR}"
    TAX_WALLET=$(grep -o '"tax_wallet": "[^"]*' ../token_config.json | cut -d'"' -f4)
    # Fix paths to be relative to the current directory
    TAX_WALLET="../${TAX_WALLET}"
    TAX_WALLET_ADDRESS=$(grep -o '"tax_wallet_address": "[^"]*' ../token_config.json | cut -d'"' -f4)
    TAX_TOKEN_ACCOUNT=$(grep -o '"tax_token_account": "[^"]*' ../token_config.json | cut -d'"' -f4)
    TAX_PERCENTAGE=$(grep -o '"tax_percentage": [^,]*' ../token_config.json | cut -d':' -f2 | tr -d ' ')
    
    # Load ETH Proxy token configuration
    ETHP_TOKEN_ADDRESS=$(grep -o '"token_address": "[^"]*' ../ethp_config.json | cut -d'"' -f4)
    ETHP_KEYPAIR=$(grep -o '"token_keypair": "[^"]*' ../ethp_config.json | cut -d'"' -f4)
    ETHP_KEYPAIR="../${ETHP_KEYPAIR}"
    SWAP_WALLET=$(grep -o '"swap_wallet": "[^"]*' ../ethp_config.json | cut -d'"' -f4)
    SWAP_WALLET="../${SWAP_WALLET}"
    SWAP_WALLET_ADDRESS=$(grep -o '"swap_wallet_address": "[^"]*' ../ethp_config.json | cut -d'"' -f4)
    SWAP_TOKEN_ACCOUNT=$(grep -o '"swap_token_account": "[^"]*' ../ethp_config.json | cut -d'"' -f4)
    
    # Set paths for user wallets
    SENDER_WALLET="../keys/sender.json"
    RECIPIENT_WALLET="../keys/recipient.json"
    
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
}

# Display comprehensive balances for all accounts
display_all_balances() {
    log "INFO" "===================== BALANCE REPORT ====================="
    log "INFO" "TaxAI Token Address: $(abbreviate_address "$TAXAI_TOKEN_ADDRESS")"
    log "INFO" "ETH Proxy Token Address: $(abbreviate_address "$ETHP_TOKEN_ADDRESS")"
    log "INFO" "Tax Percentage: $TAX_PERCENTAGE%"
    log "INFO" "--------------------------------------------------------"
    
    # TaxAI token supply
    solana config set --keypair "$TAXAI_KEYPAIR" > /dev/null
    local TAXAI_SUPPLY=$(spl-token supply "$TAXAI_TOKEN_ADDRESS")
    log "INFO" "TaxAI Total Supply: $TAXAI_SUPPLY"
    
    # ETH Proxy token supply
    solana config set --keypair "$ETHP_KEYPAIR" > /dev/null
    local ETHP_SUPPLY=$(spl-token supply "$ETHP_TOKEN_ADDRESS")
    log "INFO" "ETH Proxy Total Supply: $ETHP_SUPPLY"
    log "INFO" "--------------------------------------------------------"
    
    # Tax wallet balances
    log "INFO" "Tax Wallet: $(abbreviate_address "$TAX_WALLET_ADDRESS")"
    solana config set --keypair "$TAX_WALLET" > /dev/null
    local TAX_SOL_BALANCE=$(solana balance | awk '{print $1}')
    local TAX_TAXAI_BALANCE=$(spl-token balance "$TAXAI_TOKEN_ADDRESS" 2>/dev/null || echo "0")
    
    # Check if tax wallet has ETH Proxy account
    local TAX_ETHP_BALANCE="0"
    if spl-token accounts --verbose | grep -q "$ETHP_TOKEN_ADDRESS"; then
        TAX_ETHP_BALANCE=$(spl-token balance "$ETHP_TOKEN_ADDRESS" 2>/dev/null || echo "0")
    fi
    
    log "INFO" "Tax Wallet SOL Balance: $TAX_SOL_BALANCE"
    log "INFO" "Tax Wallet TaxAI Balance: $TAX_TAXAI_BALANCE"
    log "INFO" "Tax Wallet ETH Proxy Balance: $TAX_ETHP_BALANCE"
    log "INFO" "--------------------------------------------------------"
    
    # Swap wallet balances
    log "INFO" "Swap Wallet: $(abbreviate_address "$SWAP_WALLET_ADDRESS")"
    solana config set --keypair "$SWAP_WALLET" > /dev/null
    local SWAP_SOL_BALANCE=$(solana balance | awk '{print $1}')
    
    # Check if swap wallet has TaxAI account
    local SWAP_TAXAI_BALANCE="0"
    if spl-token accounts --verbose | grep -q "$TAXAI_TOKEN_ADDRESS"; then
        SWAP_TAXAI_BALANCE=$(spl-token balance "$TAXAI_TOKEN_ADDRESS" 2>/dev/null || echo "0")
    fi
    
    local SWAP_ETHP_BALANCE=$(spl-token balance "$ETHP_TOKEN_ADDRESS" 2>/dev/null || echo "0")
    
    log "INFO" "Swap Wallet SOL Balance: $SWAP_SOL_BALANCE"
    log "INFO" "Swap Wallet TaxAI Balance: $SWAP_TAXAI_BALANCE"
    log "INFO" "Swap Wallet ETH Proxy Balance: $SWAP_ETHP_BALANCE"
    log "INFO" "--------------------------------------------------------"
    
    # Sender wallet balances (if exists)
    if [[ -f "$SENDER_WALLET" ]]; then
        log "INFO" "Sender Wallet: $(abbreviate_address "$SENDER_ADDRESS")"
        solana config set --keypair "$SENDER_WALLET" > /dev/null
        local SENDER_SOL_BALANCE=$(solana balance | awk '{print $1}')
        
        # Check if sender wallet has TaxAI account
        local SENDER_TAXAI_BALANCE="0"
        if spl-token accounts --verbose | grep -q "$TAXAI_TOKEN_ADDRESS"; then
            SENDER_TAXAI_BALANCE=$(spl-token balance "$TAXAI_TOKEN_ADDRESS" 2>/dev/null || echo "0")
        fi
        
        log "INFO" "Sender Wallet SOL Balance: $SENDER_SOL_BALANCE"
        log "INFO" "Sender Wallet TaxAI Balance: $SENDER_TAXAI_BALANCE"
        log "INFO" "--------------------------------------------------------"
    else
        log "WARN" "Sender wallet not found"
    fi
    
    # Recipient wallet balances (if exists)
    if [[ -f "$RECIPIENT_WALLET" ]]; then
        log "INFO" "Recipient Wallet: $(abbreviate_address "$RECIPIENT_ADDRESS")"
        solana config set --keypair "$RECIPIENT_WALLET" > /dev/null
        local RECIPIENT_SOL_BALANCE=$(solana balance | awk '{print $1}')
        
        # Check if recipient wallet has TaxAI account
        local RECIPIENT_TAXAI_BALANCE="0"
        if spl-token accounts --verbose | grep -q "$TAXAI_TOKEN_ADDRESS"; then
            RECIPIENT_TAXAI_BALANCE=$(spl-token balance "$TAXAI_TOKEN_ADDRESS" 2>/dev/null || echo "0")
        fi
        
        log "INFO" "Recipient Wallet SOL Balance: $RECIPIENT_SOL_BALANCE"
        log "INFO" "Recipient Wallet TaxAI Balance: $RECIPIENT_TAXAI_BALANCE"
        log "INFO" "--------------------------------------------------------"
    else
        log "WARN" "Recipient wallet not found"
    fi
    
    log "INFO" "===================== END REPORT ====================="
}

# Main function
main() {
    log "INFO" "Starting balance display"
    
    # Load configurations
    load_configs
    
    # Display all balances
    display_all_balances
    
    log "INFO" "Balance display completed"
}

# Run main function
main

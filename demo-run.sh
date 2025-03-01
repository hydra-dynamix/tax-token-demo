#!/bin/bash
set -euo pipefail

# Default settings
FULL_SPEED=false
TRANSACTION_DELAY=1
TRANSFER_AMOUNT=1000
SWAP_AMOUNT=0

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --full-speed)
            FULL_SPEED=true
            shift
            ;;
        --transfer-amount)
            if [[ -z "$2" || "$2" =~ ^- ]]; then
                echo "Error: --transfer-amount requires a numeric value"
                exit 1
            fi
            TRANSFER_AMOUNT="$2"
            shift 2
            ;;
        --swap-amount)
            if [[ -z "$2" || "$2" =~ ^- ]]; then
                echo "Error: --swap-amount requires a numeric value"
                exit 1
            fi
            SWAP_AMOUNT="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --full-speed         Disable transaction delays"
            echo "  --transfer-amount NUM  Specify the amount to transfer (default: 1000)"
            echo "  --swap-amount NUM      Specify the amount to swap (default: all available)"
            echo "  --help               Display this help message"
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

# Function to add delay between transactions
transaction_delay() {
    if [[ "$FULL_SPEED" == "false" ]]; then
        sleep "$TRANSACTION_DELAY"
        log "INFO" "Waiting ${TRANSACTION_DELAY}s between transactions..."
    fi
}

# Main function
main() {
    log "INFO" "========================================================"
    log "INFO" "Starting TaxAI Token Demo"
    log "INFO" "========================================================"
    
    # Display speed mode
    if [[ "$FULL_SPEED" == "true" ]]; then
        log "INFO" "Running in FULL SPEED mode (no transaction delays)"
    else
        log "INFO" "Running with ${TRANSACTION_DELAY}s delay between transactions (use --full-speed to disable)"
    fi
    
    # Step 1: Display initial balances
    log "INFO" "Step 1: Displaying initial balances"
    ./display_balances.sh
    transaction_delay
    transaction_delay
    
    # Step 2: Perform token transfer with tax
    log "INFO" ""
    log "INFO" "========================================================"
    log "INFO" "Step 2: Performing token transfer with tax"
    log "INFO" "========================================================"
    
    # Build the command with all parameters
    TRANSFER_CMD="./tax_transfer.sh"
    
    if [[ "$FULL_SPEED" == "true" ]]; then
        TRANSFER_CMD="$TRANSFER_CMD --full-speed"
    fi
    
    if [[ "$TRANSFER_AMOUNT" != "1000" ]]; then
        TRANSFER_CMD="$TRANSFER_CMD --amount $TRANSFER_AMOUNT"
    fi
    
    # Execute the command
    $TRANSFER_CMD
    transaction_delay
    
    # Step 3: Display balances after transfer
    log "INFO" ""
    log "INFO" "========================================================"
    log "INFO" "Step 3: Displaying balances after transfer"
    log "INFO" "========================================================"
    ./display_balances.sh
    transaction_delay
    
    # Step 4: Perform tax swap for ETH proxy tokens
    log "INFO" ""
    log "INFO" "========================================================"
    log "INFO" "Step 4: Performing tax swap for ETH proxy tokens"
    log "INFO" "========================================================"
    
    # Build the command with all parameters
    SWAP_CMD="./tax_swap_simplified.sh"
    
    if [[ "$FULL_SPEED" == "true" ]]; then
        SWAP_CMD="$SWAP_CMD --full-speed"
    fi
    
    if [[ "$SWAP_AMOUNT" != "0" ]]; then
        SWAP_CMD="$SWAP_CMD --amount $SWAP_AMOUNT"
    fi
    
    # Execute the command
    $SWAP_CMD
    transaction_delay
    
    # Step 5: Display final balances
    log "INFO" ""
    log "INFO" "========================================================"
    log "INFO" "Step 5: Displaying final balances"
    log "INFO" "========================================================"
    ./display_balances.sh
    transaction_delay
    
    log "INFO" ""
    log "INFO" "========================================================"
    log "INFO" "TaxAI Token Demo Completed"
    log "INFO" "========================================================"
    
    # Prompt user about resetting the demo
    log "INFO" ""
    log "INFO" "To reset the demo and run it again, use: ./demo.sh reset"
}

# Run main function
main

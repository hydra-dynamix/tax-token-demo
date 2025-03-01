#!/bin/bash
set -euo pipefail

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

# Display usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -r, --reset     Reset the demo before running"
    echo "  -f, --full-speed  Run without transaction delays"
    echo "  -t, --transfer-amount NUM  Specify the amount to transfer (default: 1000)"
    echo "  -s, --swap-amount NUM      Specify the amount to swap (default: all available)"
    echo "  -h, --help      Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0              Run the demo"
    echo "  $0 --reset      Reset and run the demo"
    echo "  $0 --full-speed Run the demo at full speed (no delays)"
    echo "  $0 -r -f        Reset and run the demo at full speed"
    echo "  $0 -t 500       Run the demo with a 500 token transfer"
    echo "  $0 -s 10        Run the demo and swap only 10 tokens"
    echo ""
}

# Parse command line arguments
RESET=false
FULL_SPEED=false
TRANSFER_AMOUNT=1000
SWAP_AMOUNT=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--reset)
            RESET=true
            shift
            ;;
        -f|--full-speed)
            FULL_SPEED=true
            shift
            ;;
        -t|--transfer-amount)
            if [[ -z "$2" || "$2" =~ ^- ]]; then
                log "ERROR" "--transfer-amount requires a numeric value"
                exit 1
            fi
            TRANSFER_AMOUNT="$2"
            shift 2
            ;;
        -s|--swap-amount)
            if [[ -z "$2" || "$2" =~ ^- ]]; then
                log "ERROR" "--swap-amount requires a numeric value"
                exit 1
            fi
            SWAP_AMOUNT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check environment function
check_environment() {
    if [ -f "./check_environment.sh" ]; then
        log "INFO" "Checking environment..."
        ./check_environment.sh
        
        # Ask if user wants to continue if the script didn't exit
        if [ $? -eq 0 ]; then
            echo ""
            read -p "Do you want to continue with the demo? (y/n): " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "INFO" "Demo aborted by user."
                exit 0
            fi
        fi
    else
        log "WARN" "Environment check script not found. Proceeding without checks."
    fi
}

# Main function
main() {
    # Check environment first
    check_environment
    # Reset the demo if requested
    if [[ "$RESET" == true ]]; then
        log "INFO" "========================================================"
        log "INFO" "Resetting TaxAI Token Demo"
        log "INFO" "========================================================"
        if [[ "$FULL_SPEED" == true ]]; then
            ./demo-reset.sh --full-speed
        else
            ./demo-reset.sh
        fi
        log "INFO" ""
    fi
    
    # Run the demo
    log "INFO" "========================================================"
    log "INFO" "Running TaxAI Token Demo"
    log "INFO" "========================================================"
    
    # Build the command with all parameters
    DEMO_CMD="./demo-run.sh"
    
    if [[ "$FULL_SPEED" == true ]]; then
        DEMO_CMD="$DEMO_CMD --full-speed"
    fi
    
    if [[ "$TRANSFER_AMOUNT" != "1000" ]]; then
        DEMO_CMD="$DEMO_CMD --transfer-amount $TRANSFER_AMOUNT"
    fi
    
    if [[ "$SWAP_AMOUNT" != "0" ]]; then
        DEMO_CMD="$DEMO_CMD --swap-amount $SWAP_AMOUNT"
    fi
    
    # Execute the command
    $DEMO_CMD
}

# Run main function
main

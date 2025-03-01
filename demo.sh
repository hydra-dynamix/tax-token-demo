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
    echo "  -h, --help      Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0              Run the demo"
    echo "  $0 --reset      Reset and run the demo"
    echo "  $0 --full-speed Run the demo at full speed (no delays)"
    echo "  $0 -r -f        Reset and run the demo at full speed"
    echo ""
}

# Parse command line arguments
RESET=false
FULL_SPEED=false

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

# Main function
main() {
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
    if [[ "$FULL_SPEED" == true ]]; then
        ./demo-run.sh --full-speed
    else
        ./demo-run.sh
    fi
}

# Run main function
main

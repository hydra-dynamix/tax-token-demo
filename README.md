# TaxAI Token Demo

This directory contains a complete demonstration of the TaxAI token system with tax collection and ETH proxy token swapping capabilities. The demo showcases a token with an automatic tax mechanism and demonstrates how collected taxes can be swapped for another token.

## Overview

The TaxAI token implements a 2.5% tax on all transfers. The collected taxes are sent to a dedicated tax wallet, which can then swap these tokens for ETH proxy tokens through a swap mechanism.

## Files

- `demo.sh`: Master script to run or reset the demo with various options
- `demo-run.sh`: Complete end-to-end demonstration script
- `demo-reset.sh`: Script to reset token balances to initial state
- `tax_transfer.sh`: Demonstrates token transfers with automatic tax collection
- `tax_swap_simplified.sh`: Demonstrates swapping collected tax tokens for ETH proxy tokens
- `display_balances.sh`: Utility script to display balances of all wallets
- `token_config.json`: Configuration for the TaxAI token (contains tax percentage setting)
- `ethp_config.json`: Configuration for the ETH proxy token
- `keys/`: Directory containing all wallet keypairs

## Running the Demo

### Prerequisites

Before running the demo, ensure:

1. You have Solana CLI tools installed and configured
2. You have created the TaxAI and ETH Proxy tokens using the provided scripts
3. All scripts have executable permissions (`chmod +x *.sh`)

### Using the Master Demo Script

The `demo.sh` script provides a convenient way to run the entire demonstration with various options:

```bash
# Display help and available options
./demo.sh --help

# Run the demo with default settings (with transaction delays)
./demo.sh

# Reset token balances and then run the demo
./demo.sh --reset
# or
./demo.sh -r

# Run the demo at full speed (no transaction delays)
./demo.sh --full-speed
# or
./demo.sh -f

# Reset and run the demo at full speed
./demo.sh --reset --full-speed
# or
./demo.sh -r -f
```

### Demo Execution Flow

When you run the demo, it will:

1. Display initial balances of all wallets
2. Perform a token transfer with automatic 2.5% tax collection
   - Sender transfers 10,000 TaxAI tokens
   - 9,750 tokens go to the recipient (97.5%)
   - 250 tokens go to the tax wallet (2.5%)
3. Display updated balances after the transfer
4. Swap collected taxes for ETH proxy tokens
   - Tax wallet sends collected TaxAI tokens to the swap wallet
   - Swap wallet sends ETH proxy tokens to the tax wallet (at 1:0.01 rate)
5. Display final balances after the swap

### Transaction Delays

By default, the demo includes a 0.75 second delay between transactions to make it easier to follow the process. Use the `--full-speed` flag to disable these delays for faster execution.

### Resetting the Demo

To reset token balances to their initial state so you can run the demo multiple times:

```bash
# Reset with default settings (with transaction delays)
./demo-reset.sh

# Reset at full speed (no transaction delays)
./demo-reset.sh --full-speed
```

The reset process will:

1. Return all TaxAI tokens from the tax wallet to the token authority
2. Return all ETH Proxy tokens from the tax wallet to the token authority
3. Reset the swap wallet's ETH Proxy balance to 100,000
4. Reset the sender wallet's TaxAI balance to 100,000
5. Reset the recipient wallet's TaxAI balance to 0
6. Display the final balances after reset

## Individual Scripts

You can also run each script individually for more granular control:

```bash
# Display current balances
./display_balances.sh

# Perform token transfer with tax collection
./tax_transfer.sh [--full-speed]

# Swap collected taxes for ETH proxy tokens
./tax_swap_simplified.sh [--full-speed]

# Run the complete demo sequence
./demo-run.sh [--full-speed]

# Reset token balances to initial state
./demo-reset.sh [--full-speed]
```

All scripts that perform transactions support the `--full-speed` flag to disable the 0.75s delay between transactions.

## Key Components

1. **Tax Collection Mechanism**: 
   - 2.5% of each transfer is automatically sent to the tax wallet
   - The remaining 97.5% is sent to the intended recipient
   - The tax percentage is configurable in `token_config.json`

2. **Swap Mechanism**:
   - The tax wallet can swap collected TaxAI tokens for ETH proxy tokens
   - Exchange rate: 1 TaxAI = 0.01 ETH Proxy tokens
   - This demonstrates how collected taxes can be used for treasury operations

3. **Token Accounts**:
   - Each wallet has its own token accounts for TaxAI and ETH proxy tokens
   - The demo creates these accounts automatically if they don't exist

4. **Transaction Delays**:
   - Default 0.75s delay between transactions for better visualization
   - Can be disabled with the `--full-speed` flag for faster execution

## Wallet Structure

- **Sender Wallet**: Regular user sending TaxAI tokens (initial balance: 100,000 TaxAI)
- **Recipient Wallet**: Regular user receiving TaxAI tokens (initial balance: 0 TaxAI)
- **Tax Wallet**: Collects the 2.5% tax from each transfer (initial balance: 0 TaxAI, 0 ETH Proxy)
- **Swap Wallet**: Provides ETH proxy tokens in exchange for TaxAI tokens (initial balance: 0 TaxAI, 100,000 ETH Proxy)
- **Token Authority**: Mint authority for both tokens (used for resetting the demo)

## Customizing the Demo

### Modifying Tax Percentage

To change the tax percentage, edit the `token_config.json` file and modify the `tax_percentage` value. The demo will automatically use the new percentage for tax calculations.

```json
{
  "token_address": "...",
  "tax_percentage": 2.5,
  ...
}
```

### Modifying Exchange Rate

The exchange rate for swapping TaxAI tokens to ETH Proxy tokens is defined in `tax_swap_simplified.sh`. To modify it, edit the script and change the calculation in the `simulate_eth_purchase` function:

```bash
# Current rate: 1 TaxAI = 0.01 ETHP
ETHP_TO_RECEIVE=$(echo "scale=2; $TAXAI_AMOUNT * 0.01" | bc)
```

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure all scripts have executable permissions:
   ```bash
   chmod +x *.sh
   ```

2. **Missing Configuration Files**: If `token_config.json` or `ethp_config.json` are missing, run the token creation scripts first.

3. **Insufficient Balance**: If a wallet has insufficient balance, reset the demo using:
   ```bash
   ./demo.sh --reset
   ```

4. **Transaction Errors**: If you encounter Solana transaction errors, try increasing the transaction delay or check your Solana configuration.

## Explorer links
[Eth Token Proxy / ethyUia...1QrA](https://explorer.solana.com/address/ethyUiaWJQUbbct51haurMrY2wKYfHZL2W34FxD1QrA?cluster=devnet)
[Tax Token Mint / mntgLj...hf4N](https://explorer.solana.com/address/mntgLjzvuB8wYjPXtFLCZ7D9NviJq4EP6WFdz8phf4N?cluster=devnet)
[Swap Wallet](https://explorer.solana.com/address/815LJzAe2M3W6iMyjo1wKecFwAoGHxtm2eDaTGZaedNT?cluster=devnet)
[Tax Wellet](https://explorer.solana.com/address/HekUf6CEYcQRAAMPhwAdjAqfUoWD2SbbUTfRZZN2Aqfe?cluster=devnet)
[Recipient Wallet](https://explorer.solana.com/address/8SgyUKVE9tTPh43zbAJprf4X9MybkJhE6YdXJbxdgtyP?cluster=devnet)
[Sender Wallet](https://explorer.solana.com/address/5ivfTtM3g4AwVw5XkfqLDK949qn9qP4JSfxyFGZhNgne?cluster=devnet)
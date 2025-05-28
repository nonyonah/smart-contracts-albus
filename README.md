# Albus Smart Contracts

This repository contains the smart contracts for the Albus payment and invoice management system, built with Hardhat.

## Available Scripts

```shell
# Compilation and verification
npm run compile        # Compile all contracts
npm run size          # Show contract sizes
npm run verify        # Verify contracts on explorer

# Testing
npm run test          # Run all tests
npm run test:coverage # Run tests with coverage
npm run test:gas      # Run tests with gas reporting

# Deployment
npm run node              # Start local Hardhat node
npm run deploy:local      # Deploy to local node
npm run deploy:baseSepolia # Deploy to Base Sepolia testnet
```

## Contract Architecture

- `InvoiceManager.sol`: Handles invoice creation and management
- `PaymentTracker.sol`: Tracks payments and transactions
- `TokenSwapManager.sol`: Manages token swaps and conversions for multi-currency support

# Flindex - Decentralized Crypto Index Fund Platform

## Overview

Flindex is a decentralized on-chain crypto index fund platform fully developed using Cadence smart contracts on the Flow blockchain. The platform allows creators to launch and manage index funds comprising exactly two tokens: TRUMP and USDF, each equally weighted at 50%. Users invest using Flow tokens, which are swapped into TRUMP and USDF tokens via DeFiActions connectors and securely held in a vault. Each index is tracked using a unique index ID, which records user holdings directly. When users redeem, the vault swaps the underlying tokens back to Flow and returns it to the user.

## Features

- **Fully Cadence-based smart contract architecture** on Flow blockchain
- **Creator-driven index fund** with fixed 50-50 composition of TRUMP and USDF tokens
- **DeFiActions connector integration** to convert Flow tokens into index components and vice versa
- **Secure token vaults** while mapped against a unique index ID for each user's share
- **Seamless buy/sell operations** using Flow tokens

## Token Information

Based on Flow EVM mainnet data:
- **TRUMP Token**: `0xd3378b419feae4e3a4bb4f3349dba43a1b511760` (18 decimals)
- **USDF Token**: `0x2aabea2058b5ac2d339b163c6ab6f2b6d53aabed` (6 decimals)

## Project Structure

```
flindex/
├── cadence/
│   ├── contracts/
│   │   └── Flindex.cdc          # Main contract
│   ├── transactions/
│   │   ├── CreateIndex.cdc      # Create new index
│   │   ├── BuyIndexShares.cdc   # Buy index shares
│   │   └── SellIndexShares.cdc  # Sell index shares
│   ├── scripts/
│   │   ├── GetIndexInfo.cdc     # Get index information
│   │   ├── GetUserPositions.cdc # Get user positions
│   │   └── GetAllIndices.cdc    # Get all indices
│   └── tests/
│       └── Flindex_test.cdc     # Test suite
├── flow.json                    # Flow configuration
└── README.md                    # This file
```

## Core Components

### 1. Admin Resource
- Creates new indices and tracks global counter of `IndexID`
- Maintains a registry of active indices

### 2. Index Resource
- Holds vaults for TRUMP and USDF tokens
- Tracks `totalShares` and per-user `holdings` (address → shares)
- Provides functions for calculating NAV and price per share (`pps`)

### 3. UserPositions Resource
- User-owned resource storing their positions across multiple indices
- Mapping of `IndexID → shares`

## Key Functions

### Main Contract Functions
- `createIndex(creator)`: Launches a new index with fixed composition of TRUMP and USDF
- `buyIndex(user, flowAmount)`: Accepts Flow tokens, swaps into TRUMP/USDF, issues shares
- `sellIndex(user, indexId, shareAmount)`: Redeems shares, swaps back to Flow, transfers to user

### Events
- `IndexCreated(id, creator)`
- `IndexBought(id, user, flowIn, sharesOut)`
- `IndexSold(id, user, sharesIn, flowOut)`

## Usage

### 1. Create an Index
```bash
flow transactions send cadence/transactions/CreateIndex.cdc --signer emulator-account
```

### 2. Buy Index Shares
```bash
flow transactions send cadence/transactions/BuyIndexShares.cdc \
  --args-json '[
    {"type": "UInt64", "value": "1"},
    {"type": "UFix64", "value": "10.0"}
  ]' \
  --signer emulator-account
```

### 3. Sell Index Shares
```bash
flow transactions send cadence/transactions/SellIndexShares.cdc \
  --args-json '[
    {"type": "UInt64", "value": "1"},
    {"type": "UFix64", "value": "5.0"}
  ]' \
  --signer emulator-account
```

### 4. Query Index Information
```bash
flow scripts execute cadence/scripts/GetIndexInfo.cdc \
  --args-json '[{"type": "UInt64", "value": "1"}]'
```

## Dependencies

The project uses the following Flow ecosystem contracts:
- **FungibleToken**: Standard token interface
- **FlowToken**: Native Flow token
- **DeFiActions**: DeFi composition framework
- **SwapConnectors**: Token swapping connectors
- **IncrementFiSwapConnectors**: IncrementFi-specific swap connectors

## Development

### Prerequisites
- Flow CLI installed
- Flow emulator running

### Setup
1. Clone the repository
2. Install dependencies: `flow dependencies install`
3. Start emulator: `flow emulator`
4. Deploy contracts: `flow project deploy`

### Testing
```bash
flow test
```

## Architecture

The platform follows a modular architecture with clear separation of concerns:

1. **Contract Layer**: Core business logic in Cadence
2. **Transaction Layer**: User interactions
3. **Script Layer**: Query operations
4. **Integration Layer**: DeFiActions connectors for token swapping

## Security Considerations

- All operations are validated with pre/post conditions
- User positions are tracked securely
- Token vaults are protected with proper access controls
- Share calculations are transparent and auditable

## Future Enhancements

- Dynamic rebalancing of index composition
- Multiple token support beyond TRUMP/USDF
- Advanced portfolio management features
- Integration with more DeFi protocols

## License

This project is open source and available under the MIT License.
# Flindex - Decentralized Crypto Index Fund Platform

## Overview

Flindex is a decentralized on-chain crypto index fund platform built using Cadence smart contracts on the Flow blockchain. The platform enables creators to launch and manage diversified index tokens composed of multiple crypto assets, while users can invest in them using Flow tokens.

## Architecture

### Core Contracts

1. **FlindexCore.cdc** - Main contract managing index token operations
   - Index creation and metadata management
   - Token minting and burning
   - Buy/sell operations with fee calculation
   - Mock Pyth oracle integration for asset pricing

2. **FlindexCreator.cdc** - Creator management and permissions
   - Creator registration with project token staking
   - Index creation permissions
   - Rebalancing operations
   - Project token payment system

3. **FlindexTreasury.cdc** - Fee collection and distribution
   - Platform fee management (0.1% default)
   - Treasury and creator reward distribution
   - Fee statistics and tracking

### Key Features

- **Index Creation**: Creators can create diversified crypto indices
- **Real-time Valuation**: Mock Pyth oracle integration for asset pricing
- **Fee Distribution**: 50/50 split between treasury and creators
- **Token Standards**: Full FungibleToken and MetadataViews compliance
- **Rebalancing**: Creators can update index compositions

## Getting Started

### Prerequisites

- Flow CLI installed
- Flow emulator running

### Setup

1. Install dependencies:
```bash
flow dependencies install
```

2. Start the Flow emulator:
```bash
flow emulator
```

3. Deploy contracts:
```bash
flow project deploy
```

### Usage Examples

#### 1. Register as Creator

```bash
flow transactions send ./transactions/RegisterCreator.cdc 1000.0 --signer emulator-account
```

#### 2. Create an Index

```bash
flow transactions send ./transactions/CreateIndex.cdc \
  "DeFi Index" \
  "A diversified DeFi index fund" \
  0.4 0.3 0.2 0.1 \
  --signer emulator-account
```

#### 3. Setup User Account

```bash
flow transactions send ./transactions/SetupAccount.cdc --signer emulator-account
```

#### 4. Buy Index Tokens

```bash
flow transactions send ./transactions/BuyIndex.cdc 1 100.0 --signer emulator-account
```

#### 5. Query Index Data

```bash
# Get index metadata
flow scripts execute ./scripts/GetIndexMetadata.cdc 1

# Get account balance
flow scripts execute ./scripts/GetAccountIndexBalance.cdc 0xf8d6e0586b0a20c7 1

# Get index valuation
flow scripts execute ./scripts/GetIndexValuation.cdc 1
```

## Testing

Run the comprehensive test suite:

```bash
flow test ./tests/Flindex_test.cdc
```

## Contract Addresses

### Emulator
- FlindexCore: `0xf8d6e0586b0a20c7`
- FlindexCreator: `0xf8d6e0586b0a20c7`
- FlindexTreasury: `0xf8d6e0586b0a20c7`

## API Reference

### FlindexCore

#### Functions
- `createIndex(name, description, creator, composition)` - Create new index
- `buyIndex(buyer, indexId, flowAmount)` - Purchase index tokens
- `sellIndex(seller, tokens)` - Sell index tokens
- `getIndexMetadata(indexId)` - Get index information
- `getIndexValuation(indexId)` - Get current index value

#### Events
- `IndexCreated` - New index created
- `IndexTokensPurchased` - Tokens purchased
- `IndexTokensSold` - Tokens sold
- `IndexValuationUpdated` - Valuation updated

### FlindexCreator

#### Functions
- `registerCreator(creator, initialStake)` - Register as creator
- `createIndexAsCreator(creatorRef, name, description, composition)` - Create index
- `rebalanceIndexAsCreator(creatorRef, indexId, newComposition)` - Rebalance index

#### Events
- `CreatorRegistered` - Creator registered
- `ProjectTokensPaidForCreation` - Tokens paid for creation
- `ProjectTokensPaidForRebalancing` - Tokens paid for rebalancing

### FlindexTreasury

#### Functions
- `collectIndexFees(fees, source, creator)` - Collect platform fees
- `distributeRewardsToCreator(creator)` - Distribute creator rewards
- `getTreasuryStats()` - Get treasury statistics

#### Events
- `FeesCollected` - Fees collected from operations
- `CreatorRewardDistribution` - Rewards distributed to creator

## Future Enhancements

- Integration with real Pyth Network oracles
- Advanced rebalancing strategies
- DAO governance for platform management
- Yield farming integration
- Cross-chain asset support

## License

This project is licensed under the MIT License.

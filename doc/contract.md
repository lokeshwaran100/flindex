# Flindex

## 1. Project Overview

**Description:**  
Flindex is a decentralized on-chain crypto index fund platform fully built using Cadence smart contracts on the Flow blockchain. The platform enables creators to launch and manage diversified index tokens composed of multiple crypto assets and users to invest in them using Flow tokens. Real-time pricing for index valuation, buying, selling, and rebalancing is powered by Pyth network oracles for secure and accurate asset pricing. Passive income is generated to index creators from platform fees, maintaining ecosystem value.

**Main Features:**  
- Full Cadence smart contract architecture on Flow blockchain  
- Index creation and rebalancing by creators via project token payments  
- Secure, real-time valuation and swaps via Pyth oracle integration  
- Users buy/sell index tokens with Flow, paying 0.1% fees shared between treasury and creators  

**Future Scope:**  
- Weekly leaderboard rewards for top-performing creators  
- On-chain randomness with Pyth Entropy for user engagement rewards  
- DAO governance to manage scam index voting and closure  
- Privacy-preserving creator doxxing with self-sovereign identity protocols

---

## 3. High-Level Technical Description

### Contracts

- **FlindexCore.cdc:** Core contract managing index token minting, burning, valuation, and user buy/sell transactions. Integrates with Pyth oracles for accurate pricing.  
- **FlindexCreator.cdc:** Manages permissions for creators, index creation, and rebalancing upon project token payment.  
- **FlindexTreasury.cdc:** Handles fee collection and distribution between the platform treasury and creators as passive income.

### Key Types

- **Resource: `IndexToken`**  
  Represents ownership in a diversified crypto index with tracked valuation and metadata.  
- **Struct: `IndexMetadata`**  
  Holds configuration including index composition, creator info, and rebalance history.

### Main Functions

- `createIndex(creator, composition)`: Allows project token-paying creators to launch new indices.  
- `rebalanceIndex(creator, newComposition)`: Creator-triggered index composition update requiring project tokens.  
- `buyIndex(user, flowAmount)`: Lets users purchase index tokens at a current valuation fetched from Pyth oracles; applies buy fees.  
- `sellIndex(user, indexTokenAmount)`: User sells index tokens, with Flow returned calculated via Pyth oracle prices minus fees.

---

## 4. Standards Implemented

- FungibleToken (for index tokens and project tokens)  
- MetadataViews (providing standardized metadata interfaces for tokens)  
- Pyth Network Integration (secure asset pricing and randomness)
  
---

## 6. Contract, Transaction, and Script Descriptions

- **FlindexCore.cdc**  
  Handles all core index-related operations including minting/burning tokens, fee application, and integration with Pyth oracles for real-time valuation.  

- **FlindexCreator.cdc**  
  Manages index creation and rebalancing permissions, enforcing project token fee payment.  

- **FlindexTreasury.cdc**  
  Maintains fee collection and distribution logic to the treasury and creators.

---

## 7. Testing

### Unit Tests

- Full coverage for index creation, buy/sell logic, rebalancing, and fee handling.  
- Resource lifecycle tests for `IndexToken` minting and burning.  
- Verification of event emission and access control enforcement.

---
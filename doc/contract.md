# Flindex

## 1. Project Overview

**Description:**
Flindex is a decentralized on-chain crypto index fund platform fully developed using Cadence smart contracts on the Flow blockchain. The platform allows creators to launch and manage an index fund comprising exactly two tokens: TRUMP and USDF, each equally weighted at 50%. Users invest using Flow tokens, which are swapped into TRUMP and USDF tokens via a Swapper action and securely held in a vault. Each index is tracked using a unique index ID, which records user holdings directly. When users redeem, the vault swaps the underlying tokens back to Flow and returns it to the user.

**Main Features:**

* Fully Cadence-based smart contract architecture on Flow blockchain
* Creator-driven index fund with fixed 50-50 composition of TRUMP and USDF tokens
* Swapper action integration to convert Flow tokens into index components and vice versa
* Tokens securely held in vault while mapped against a unique index ID for each user’s share
* Users buy and sell index shares seamlessly using Flow

---

## 2. Data Structures & Storage Model

### Types & Identifiers

* `IndexID = UInt64` – unique identifier for each index instance
* Shares are numerical units tracked per user under each index ID

### Core Components

* **Admin Resource**

  * Creates new indices and tracks global counter of `IndexID`
  * Maintains a registry of active indices

* **Index Resource**

  * Holds vaults for TRUMP and USDF
  * Tracks `totalShares` and per-user `holdings` (address → shares)
  * Provides functions for calculating NAV and price per share (`pps`)

* **UserPositions Resource** (optional helper)

  * User-owned resource storing their positions across multiple indices
  * Mapping of `IndexID → shares`

### Events

* `IndexCreated(id, creator)`
* `IndexBought(id, user, flowIn, sharesOut)`
* `IndexSold(id, user, sharesIn, flowOut)`

### Invariants

* `totalShares == sum(holdings[*].shares)`
* Portfolio is always maintained 50/50 TRUMP–USDF at transaction boundaries

---

## 3. High-Level Technical Description

### Main Functions

* `createIndex(creator)`:
  Launches a new index with fixed composition of TRUMP and USDF. Generates a unique `IndexID` and initializes vaults.

* `buyIndex(user, flowAmount)`:
  Accepts Flow tokens from the user, swaps equally by value into TRUMP and USDF via the Swapper action, deposits tokens into index vaults, computes shares from NAV/pps, and records them under the user’s holdings for that index.

* `sellIndex(user, indexId, shareAmount)`:
  Validates the user’s shares for the given index, calculates redemption value using NAV/pps, redeems proportional TRUMP and USDF, swaps them back to Flow, transfers Flow to the user, and updates holdings.

*Note:* All conversions rely exclusively on the Swapper action for secure and efficient swaps.
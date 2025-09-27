# Flindex

## 1. Project Overview

**Description:**
Flindex is a decentralized on-chain crypto index fund platform fully developed using Cadence smart contracts on the Flow blockchain. The platform allows creators to launch and manage an index fund comprising exactly two tokens: TRUMP and USDF, each equally weighted at 50%. Users invest using Flow tokens, which are swapped into TRUMP and USDF tokens via a Swapper action and securely held in a vault. Each index is tracked using a unique index ID rather than minting and burning index tokens. When users redeem, the vault swaps the underlying tokens back to Flow and returns it to the user.

**Main Features:**

* Fully Cadence-based smart contract architecture on Flow blockchain
* Creator-driven index fund with fixed 50-50 composition of TRUMP and USDF tokens
* Swapper action integration to convert Flow tokens into index components and vice versa
* Tokens securely held in vault while mapped against a unique index ID for each user’s share
* Users buy and sell index shares seamlessly using Flow without any platform fees

---

## 3. High-Level Technical Description

### Main Functions

* `createIndex(creator)`: Allows a creator to launch the fixed-composition index fund composed only of TRUMP and USDF tokens. A unique index ID is generated for tracking.
* `buyIndex(user, flowAmount)`: Accepts Flow tokens from users, swaps them equally into TRUMP and USDF tokens using the Swapper action, and records these token amounts in the vault under the user’s index ID.
* `sellIndex(user, indexId, shareAmount)`: Looks up the user’s recorded holdings for the given index ID, calculates the TRUMP and USDF token amounts equivalent to the share being sold, swaps them back into Flow tokens via the Swapper action, and transfers Flow tokens to the user.

*Note:* All token swaps must utilize the Swapper action for secure and efficient conversions.
# Flindex

Flindex is an on-chain crypto index fund implemented with Cadence smart contracts on Flow. Each index is constrained to an equal-weight TRUMP/USDF portfolio. Investors deposit Flow, the contract routes swaps through composable DeFiActions and SwapConnectors swappers, and the portfolio remains a simple 50/50 split derived from each buy flow.

## Architecture

- Contract: cadence/contracts/Flindex.cdc
  - Resource Admin mints new indices and stores metadata.
  - Resource Index holds TRUMP and USDF vaults, tracks totalShares, and orchestrates buy/sell flows via DeFiActions swappers.
  - UserPositions resource lets accounts persist per-index share balances for off-chain apps.
- Transactions
  - cadence/transactions/CreateIndex.cdc – admin seeds a 50/50 index with empty TRUMP/USDF vaults and metadata.
  - cadence/transactions/BuyIndexShares.cdc – withdraws Flow, performs Flow->TRUMP/USDF swaps, mints shares, and updates positions.
  - cadence/transactions/SellIndexShares.cdc – burns shares, swaps TRUMP/USDF back to Flow, and deposits the Flow proceeds.
  - cadence/transactions/SetupUserPositions.cdc – installs the optional UserPositions resource plus capability in the caller's account.
- Scripts
  - cadence/scripts/ListIndexIDs.cdc – enumerates active index ids.
  - cadence/scripts/GetIndexInfo.cdc – returns metadata, share supply, and raw vault balances for an index.
  - cadence/scripts/GetUserPositions.cdc – fetches an account's stored share balances if the helper resource is present.

## Connector Requirements

BuyIndexShares.cdc and SellIndexShares.cdc expect capabilities to swappers that satisfy these routes:

| Capability | Direction | Purpose |
|------------|-----------|---------|
| Flow->TRUMP | Flow -> TRUMP vault | Split Flow deposits into TRUMP exposure |
| Flow->USDF  | Flow -> USDF vault  | Split Flow deposits into USDF exposure |
| TRUMP->Flow | TRUMP -> Flow vault | Quote NAV, exit TRUMP when calculating price or redeeming |
| USDF->Flow  | USDF -> Flow vault  | Quote NAV, exit USDF when calculating price or redeeming |

Create these swappers using the mainnet SwapConnectors factory (or any implementation of the DeFiActions.Swapper interface), expose them through capabilities, and pass provider addresses plus capability paths to the transactions.

## Typical Workflow

1. Admin setup: deploy the contract, run SetupUserPositions.cdc (optional) for the admin account, and execute CreateIndex.cdc with empty TRUMP/USDF vaults plus metadata.
2. Investor onboarding: each user runs SetupUserPositions.cdc once to install the helper resource.
3. Buying shares: investors call BuyIndexShares.cdc, supplying Flow amount, Flow vault path, and swapper capabilities. The transaction mints shares and records them in UserPositions if available.
4. Selling shares: investors call SellIndexShares.cdc with the number of shares to redeem and the same connector capability set. The contract returns Flow proportional to their ownership.
5. Monitoring: use ListIndexIDs.cdc, GetIndexInfo.cdc, and GetUserPositions.cdc to inspect live holdings.

## Local Testing

- Discover available tests (none bundled yet): flow test --list
- Deploy to the emulator once connector capabilities are configured: flow project deploy --network=testing

Tests are not bundled because they require mocked swapper connectors. When adding tests, stub DeFiActions.Swapper implementations that return deterministic quotes so the index math can be verified without external dependencies.

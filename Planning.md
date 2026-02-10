## GTACoin Project - Planning & Progress

### 1. Fix Transfer Fee (2% total)
- [x] Override `_update` instead of `_beforeTokenTransfer` (OZ v5 hook)
- [x] Apply 2% fee on regular transfers only (skip mints, burns, and vault transfers)
- [x] Update tests to verify fee deduction

### 2. Fix Vault / Staking Logic
- [x] Make `lastPayoutTime` per-user instead of global
- [x] Add `unstake` function so users can withdraw staked tokens
- [x] Fix reward math to only distribute fee revenue, not staked principal
- [x] Add `updateToken` setter for deployment flow (circular dependency)
- [x] Protect `withdrawFees` from draining staked funds
- [x] Update tests for vault (15 tests covering stake/unstake/claim/fees/owner)

### 3. Add Burn Mechanism (In-Game Item Shop)
- [x] Decide on burn use case — in-game purchases that burn tokens
- [x] Add `itemPrices` mapping + `setItemPrice` (owner only)
- [x] Add `purchaseItem` function that burns the item's price from the buyer
- [x] Emit `ItemPurchased` and `ItemAdded` events for game backend tracking
- [x] Add tests (8 new: set price, owner-only, burn, event, nonexistent item, insufficient balance, remove item, no fee on burn)

### 4. Add Buy/Sell Functionality
- [x] Design: fixed price with sell discount (owner-controlled economy)
- [x] `buyTokens()` — send ETH, receive minted GTA at fixed rate (default 0.001 ETH/GTA)
- [x] `sellTokens(amount)` — burn GTA, receive ETH at 10% discount (90% of buy price)
- [x] Owner controls: `setTokenPrice`, `setSellDiscount`, `withdrawEth`
- [x] Events: `TokensBought`, `TokensSold`
- [x] Add tests (13 new: buy, sell, spread, events, edge cases, owner controls)

### 5. Deployment Script
- [x] Create Foundry deployment script (`script/Deploy.s.sol`)
- [x] Handle circular dependency (deploy vault → deploy coin → link vault to coin)
- [x] Console logs for deployed addresses
- [x] Dry-run verified

### 6. Test Coverage
- [x] Full test suite for GTACoin (25 tests: mint, transfer, fee, burn, buy/sell)
- [x] Full test suite for GTAVault (15 tests: stake, unstake, claim, fees, owner)

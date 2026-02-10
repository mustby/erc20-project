# GTACoin (GTA)

A hypothetical ERC20 token designed as an in-game currency for GTAVI. Built with Solidity, OpenZeppelin v5, and Foundry.

## Contracts

### GTACoin (`src/GTACoin.sol`)

The core ERC20 token. Deploys with an initial supply of **1,000,000 GTA** minted to the contract owner.

**Token Details:**
- Name: `GTACoin`
- Symbol: `GTA`
- Decimals: 18
- Initial Supply: 1,000,000

#### Minting

The owner can mint additional tokens to any address:

```solidity
function mint(address to, uint256 amount) external onlyOwner
```

#### Transfer Fee (2%)

Every standard transfer deducts a **2% fee** and sends it to the GTAVault contract. The fee is skipped for:
- Minting (tokens created from zero address)
- Burning (tokens sent to zero address)
- Transfers to/from the vault itself (prevents infinite recursion)

This is implemented by overriding OpenZeppelin v5's `_update` hook.

#### Buy / Sell

Players can buy GTA with ETH and sell GTA back for ETH. The owner controls pricing and the sell discount.

```solidity
// Player sends ETH, receives freshly minted GTA
function buyTokens() external payable

// Player burns GTA, receives ETH at a discounted rate
function sellTokens(uint256 amount) external
```

**Defaults:**
- Buy price: `0.001 ETH` per GTA (1 ETH = 1,000 GTA)
- Sell discount: `10%` (sell back at 90% of buy price)

**Owner controls:**

```solidity
// Set the buy price (in wei per 1 GTA token)
function setTokenPrice(uint256 newPrice) external onlyOwner

// Set the sell discount (e.g. 10 = players sell at 90% of buy price)
function setSellDiscount(uint256 newDiscount) external onlyOwner

// Withdraw accumulated ETH from the buy/sell spread
function withdrawEth(uint256 amount) external onlyOwner
```

The spread between buy and sell prices stays in the contract as protocol revenue for the owner to withdraw.

#### In-Game Item Shop (Burn Mechanism)

The owner registers in-game items with prices. Players purchase items by **burning** tokens, permanently reducing the total supply.

```solidity
// Owner adds/updates an item (price of 0 removes it)
function setItemPrice(uint256 itemId, uint256 price) external onlyOwner

// Player buys an item — tokens are burned
function purchaseItem(uint256 itemId) external
```

Purchases emit an `ItemPurchased(address buyer, uint256 itemId, uint256 price)` event that a game backend can listen to for granting items.

---

### GTAVault (`src/GTAVault.sol`)

A staking and fee distribution vault. Collects the 2% transfer fees from GTACoin and distributes them as rewards to stakers.

#### Staking

Users approve and stake GTA tokens into the vault. Staked tokens are tracked separately from fee revenue.

```solidity
function stake(uint256 amount) external
function unstake(uint256 amount) external
```

- Partial unstaking is supported
- Fully unstaking resets the user's payout timer

#### Claiming Rewards

Stakers can claim their share of accumulated fees **once per day**. Rewards are proportional to each user's stake relative to the total staked amount.

```solidity
function claimRewards() external
```

- Payout timers are **per-user** (one user claiming does not block others)
- Reward pool = vault token balance minus total staked principal (`availableFees()`)
- If no fees have accumulated, the claim reverts

#### Owner Withdraw

The owner can withdraw excess fees, but **cannot** withdraw staked funds:

```solidity
function withdrawFees(uint256 amount) external onlyOwner
```

---

## Deployment

A Foundry script handles the full deployment flow, including the circular dependency between contracts.

**What the script does:**
1. Deploy `GTAVault` with a placeholder token address (`address(0)`)
2. Deploy `GTACoin` with the vault's address
3. Call `vault.updateToken(address(coin))` to link them

**Commands:**

```bash
# Dry-run (local simulation)
forge script script/Deploy.s.sol

# Deploy to a network (e.g. Sepolia testnet)
forge script script/Deploy.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
```

## Build & Test

```bash
# Build
forge build

# Run all tests (40 tests)
forge test

# Run tests with verbose output
forge test -vvv
```

### Test Coverage

| Contract | Tests | Covers |
|----------|-------|--------|
| GTACoin  | 25    | Minting, transfer fees, in-game purchases/burn, buy/sell, owner controls, events, edge cases |
| GTAVault | 15    | Staking, unstaking, reward claims, fee tracking, per-user timers, owner withdraw protections |

## Tech Stack

- **Solidity** ^0.8.24
- **Foundry** (Forge) for compilation, testing, and deployment
- **OpenZeppelin Contracts** v5.2 (ERC20, Ownable)

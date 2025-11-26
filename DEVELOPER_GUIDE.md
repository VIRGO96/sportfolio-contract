# Sportfolio IPO - Developer Guide

## Quick Summary

**ERC-1155 IPO contract** with sigmoid bonding curve pricing:
- **Base Price**: $30 USD (paid in USDC)
- **Total Supply**: 2,000,000 tokens per team
- **Payment**: USDC (stablecoin)
- **Pricing**: Continuous sigmoid curve (price increases as tokens sell)
- **Final Price**: $330 USD at 2M tokens sold

---

## Contract Overview

### Key Features
- ✅ $30 USD base price (stable, not affected by ETH volatility)
- ✅ USDC payment (6 decimals)
- ✅ Continuous pricing (each token priced individually)
- ✅ 3% platform fee
- ✅ Transfer restrictions during IPO
- ✅ Auto-complete when all tokens sold

### Current Status
- ✅ Single team support (Lakers, token ID = 1)
- ⏳ Multi-team support (30 teams) - Coming next

---

## Deployment

### Using Hardhat

```bash
# Install dependencies
npm install

# Deploy to Sepolia
npx hardhat run scripts/deploy.js --network sepolia
```

**Constructor Parameters:**
1. `uri`: Metadata URI (e.g., `"https://api.sportfolio.com/metadata/{id}.json"`)
2. `platformFeeRecipient`: Address to receive 3% platform fees
3. `paymentToken`: USDC contract address
   - Sepolia: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`
   - Mainnet: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`

### Using Remix IDE

#### Step 1: Deploy MockUSDC (for testing)

1. Go to [Remix IDE](https://remix.ethereum.org/)
2. Create file: `MockUSDC.sol`
3. Copy code from `contracts/MockUSDC.sol`
4. Compile (Solidity 0.8.19)
5. Deploy to Sepolia
6. **Copy the deployed address** - you'll need it

#### Step 2: Deploy SportfolioIPO

1. Create file: `SportfolioIPO.sol`
2. Copy code from `contracts/SportfolioIPO.sol`
3. Compile (Solidity 0.8.19)
4. Deploy with parameters:
   - `_uri`: `"https://api.sportfolio.com/metadata/{id}.json"`
   - `_platformFeeRecipient`: Your wallet address
   - `_paymentToken`: MockUSDC address from Step 1

---

## Testing

### Run Tests (Hardhat)

```bash
# Run all tests
npx hardhat test

# Run USDC pricing tests
npx hardhat test test/SportfolioIPO_USDC.test.js

# Run specific test
npx hardhat test --grep "Base Price"
```

### Manual Testing (Remix)

#### 1. Get USDC in Your Wallet

In MockUSDC contract, call `transfer()`:
- `to`: Your wallet address
- `amount`: `100000000` (100 USDC = 100 * 10^6)

#### 2. Approve USDC Spending

In MockUSDC contract, call `approve()`:
- `spender`: SportfolioIPO contract address
- `amount`: `1000000000` (1B USDC - large amount for testing)

#### 3. Test Functions

**Check Price:**
- Call `getCurrentPrice()` → Returns USDC units (divide by 1,000,000 for USD)

**Calculate Cost:**
- Call `calculatePurchaseCost(100)` → Returns `tokenCost` and `platformFee`

**Buy Tokens:**
- Call `buyTokens(100)` → **Set "Value" to 0** (not ETH!)
- Should succeed ✅

**Verify:**
- Call `getTokensSold()` → Should show tokens bought
- Call `getCurrentPrice()` → Price should increase

---

## Key Functions

### View Functions
- `getCurrentPrice()` → Current token price (USDC units)
- `calculatePurchaseCost(amount)` → Cost to buy tokens
- `getTokensSold()` → Total tokens sold
- `getRemainingTokens()` → Tokens still available
- `getBasePrice()` → Base price ($30 = 30,000,000 USDC)
- `getPaymentToken()` → USDC contract address

### Transaction Functions
- `buyTokens(amount)` → Buy tokens (requires USDC approval first)
- `pauseIPO()` / `resumeIPO()` → Owner only
- `completeIPO()` → Owner only

---

## Important Notes

### USDC Payment Flow
1. User must **approve** USDC before buying
2. User calls `buyTokens(amount)`
3. Contract transfers USDC from user
4. Tokens minted to user

### Price Calculation
- Prices in **USDC units** (6 decimals)
- To convert to USD: `price / 1,000,000`
- Example: `30,000,000 USDC = $30 USD`

### Gas Fees
- Gas fees paid in **ETH** (network native token)
- Token price paid in **USDC**
- Two separate things!

### Pricing Formula
```
Price = $30 + ($30 × Sigmoid_Factor)
Sigmoid_Factor = tokens_sold / (2,000,000 - tokens_sold + 200,000)
```

**Example Prices:**
- 0 tokens: $30.00
- 500K tokens: $38.82
- 1M tokens: $55.00
- 1.5M tokens: $94.29
- 1.8M tokens: $165.00
- 1.95M tokens: $264.00
- 2M tokens: $330.00

---

## Frontend Integration

**⚠️ Important:** Users MUST approve USDC before buying (required on mainnet too, not just testing). See 

```javascript
// 1. Get contracts
const usdc = new ethers.Contract(usdcAddress, usdcABI, signer);
const sportfolio = new ethers.Contract(contractAddress, sportfolioABI, signer);

// 2. Get price
const price = await sportfolio.getCurrentPrice();
const priceUSD = Number(price) / 1_000_000; // Convert to USD

// 3. Calculate cost
const [cost, fee] = await sportfolio.calculatePurchaseCost(100);
const total = cost + fee;

// 4. Check if user has approved USDC
const allowance = await usdc.allowance(userAddress, contractAddress);
if (allowance < total) {
  // User needs to approve first
  // Option 1: Approve exact amount
  await usdc.approve(contractAddress, total);
  
  // Option 2: Approve max (one-time, better UX)
  const maxApproval = "115792089237316195423570985008687907853269984665640564039457";
  await usdc.approve(contractAddress, maxApproval);
}

// 5. Buy tokens
await sportfolio.buyTokens(100);
```

**User Flow:**
1. Check USDC balance
2. Check approval → If not approved, show "Approve USDC" button
3. User approves (one-time, can approve max amount)
4. User buys tokens

---

## Troubleshooting

**"Insufficient USDC allowance"**
→ Approve USDC first: `usdc.approve(contractAddress, amount)`
→ **Note:** Approval is required on mainnet too, not just testing!

**"Insufficient USDC balance"**
→ Get more USDC in wallet

**Price shows large number**
→ Remember: prices in USDC units (6 decimals). Divide by 1,000,000 for USD

**Transaction fails in Remix**
→ Make sure "Value" is set to 0 (not ETH amount)

**"Do users need to approve on mainnet?"**
→ **Yes!** Approval is required on mainnet production.

---

## File Structure

```
contracts/
  ├── SportfolioIPO.sol    # Main contract
  └── MockUSDC.sol         # Mock USDC for testing

test/
  └── SportfolioIPO_USDC.test.js  # USDC pricing tests

scripts/
  ├── deploy.js            # Deployment script
  └── verify-pricing.js   # Pricing verification
```

---

## Next Steps

- ⏳ Multi-team support (30 teams)
- ⏳ Team management functions
- ⏳ Mintable/new team flow

---

## Quick Reference

**USDC Addresses:**
- Sepolia: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`
- Mainnet: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`

**Key Constants:**
- Base Price: 30,000,000 USDC units = $30 USD
- Total Supply: 2,000,000 tokens
- Platform Fee: 3%
- Smoothing Factor: 200,000


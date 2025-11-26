# Sportfolio IPO Contract

ERC-1155 smart contract for IPO stage with sigmoid bonding curve pricing.

## Quick Start

```bash
# Install dependencies
npm install

# Compile contracts
npx hardhat compile

# Run tests
npx hardhat test

# Deploy to Sepolia
npx hardhat run scripts/deploy.js --network sepolia
```

## Documentation

📖 **See [DEVELOPER_GUIDE.md](./DEVELOPER_GUIDE.md) for complete documentation:**
- Contract overview
- Deployment instructions (Hardhat & Remix)
- Testing guide
- Frontend integration
- Troubleshooting

## Contract Details

- **Base Price**: $30 USD (paid in USDC)
- **Total Supply**: 2,000,000 tokens per team
- **Payment Token**: USDC (stablecoin)
- **Platform Fee**: 3%
- **Pricing**: Sigmoid bonding curve

## Key Features

✅ True $30 USD pricing (stable, not affected by ETH volatility)  
✅ Continuous pricing (each token priced individually)  
✅ USDC payment (6 decimals)  
✅ Transfer restrictions during IPO  
✅ Auto-complete when all tokens sold  

## Current Status

- ✅ Single team support (Lakers, token ID = 1)
- ✅ USDC pricing verified

## Project Structure

```
contracts/
  ├── SportfolioIPO.sol    # Main IPO contract
  └── MockUSDC.sol         # Mock USDC for testing

test/
  └── SportfolioIPO_USDC.test.js  # USDC pricing tests

scripts/
  ├── deploy.js            # Deployment script
  └── verify-pricing.js   # Pricing verification
```

## Quick Reference

**USDC Addresses:**
- Sepolia: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`
- Mainnet: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`

**Pricing Examples:**
- 0 tokens: $30.00
- 1M tokens: $55.00
- 1.8M tokens: $165.00
- 2M tokens: $330.00

---

📖 **For detailed instructions, see [DEVELOPER_GUIDE.md](./DEVELOPER_GUIDE.md)**

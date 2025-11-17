# Sportfolio IPO Contract

ERC-1155 smart contract for IPO stage with sigmoid bonding curve pricing.

## Prerequisites

- Node.js (v16 or higher)
- MetaMask browser extension with Sepolia testnet ETH
- MetaMask account private key

## Setup Instructions

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment Variables

1. Copy the example environment file:
   ```bash
   copy .env.example .env
   ```
   (On Windows PowerShell, use: `Copy-Item .env.example .env`)

2. Open `.env` file and add your MetaMask private key:
   ```
   PRIVATE_KEY=your_metamask_private_key_here
   ```

   **How to get your private key from MetaMask:**
   - Open MetaMask extension
   - Click the three dots menu (top right)
   - Go to "Account details"
   - Click "Show private key"
   - Enter your password
   - Copy the private key (without the "0x" prefix if present)

### 3. Verify Your Setup

Check your account balance:
```bash
npx hardhat accounts
```

This should show your MetaMask account address and balance.

### 4. Compile the Contract

```bash
npx hardhat compile
```

### 5. Deploy to Sepolia Testnet

```bash
npx hardhat run scripts/deploy.js --network sepolia
```

The script will:
- Deploy your SportfolioIPO contract
- Display the contract address
- Show a link to view it on Etherscan

## Contract Details

- **Base Price**: 30 ETH
- **Total Supply**: 2,000,000 tokens
- **Platform Fee**: 3%
- **Token ID**: 1 (Lakers example)

## Important Notes

⚠️ **Security Warning**: 
- Never share your private key
- Never commit your `.env` file to git
- The `.env` file is already in `.gitignore`

📝 **Before Deployment**:
- Make sure you have Sepolia ETH in your MetaMask wallet
- Update the `metadataURI` in `scripts/deploy.js` if needed
- Update the `platformFeeRecipient` address in `scripts/deploy.js` if different from deployer

## Useful Commands

```bash
# Compile contracts
npx hardhat compile

# Run tests
npx hardhat test

# Deploy to Sepolia
npx hardhat run scripts/deploy.js --network sepolia

# View accounts
npx hardhat accounts
```

const hre = require("hardhat");

async function main() {
  console.log("Deploying SportfolioIPO contract...");

  // Get the deployer account
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", hre.ethers.formatEther(await deployer.provider.getBalance(deployer.address)), "ETH");

  // Contract constructor parameters
  // You need to provide:
  // 1. URI for ERC1155 metadata (can be a placeholder for now)
  // 2. Platform fee recipient address (where platform fees go)
  // 3. USDC token address (payment token)
  
  const metadataURI = "https://api.sportfolio.com/metadata/{id}.json"; // Update this with your actual metadata URI
  const platformFeeRecipient = deployer.address; // Change this to your platform fee wallet address
  
  // USDC addresses by network:
  // Mainnet: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
  // Sepolia: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
  // You can also set via environment variable: USDC_ADDRESS
  const usdcAddress = process.env.USDC_ADDRESS || "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"; // Sepolia USDC

  console.log("\nDeployment parameters:");
  console.log("  Metadata URI:", metadataURI);
  console.log("  Platform Fee Recipient:", platformFeeRecipient);
  console.log("  USDC Address:", usdcAddress);

  // Deploy the contract
  const SportfolioIPO = await hre.ethers.getContractFactory("SportfolioIPO");
  const sportfolioIPO = await SportfolioIPO.deploy(
    metadataURI,
    platformFeeRecipient,
    usdcAddress
  );

  await sportfolioIPO.waitForDeployment();
  const contractAddress = await sportfolioIPO.getAddress();

  console.log("\n✅ SportfolioIPO deployed successfully!");
  console.log("Contract address:", contractAddress);
  console.log("\nYou can view your contract on Sepolia Etherscan:");
  console.log(`https://sepolia.etherscan.io/address/${contractAddress}`);

  // Verify contract details
  console.log("\nContract details:");
  const basePrice = await sportfolioIPO.getBasePrice();
  console.log("  Base Price:", basePrice.toString(), "USDC units ($30 USD)");
  console.log("  Total Supply:", (await sportfolioIPO.getTotalSupply()).toString());
  console.log("  IPO Active:", await sportfolioIPO.isIPOActive());
  console.log("  Payment Token (USDC):", await sportfolioIPO.getPaymentToken());
  
  console.log("\n📝 Next Steps:");
  console.log("  1. Users need USDC in their wallet to buy tokens");
  console.log("  2. Users must approve USDC spending before buying");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

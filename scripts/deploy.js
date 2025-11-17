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
  const metadataURI = "https://api.sportfolio.com/metadata/{id}.json"; // Update this with your actual metadata URI
  const platformFeeRecipient = deployer.address; // Change this to your platform fee wallet address

  console.log("\nDeployment parameters:");
  console.log("  Metadata URI:", metadataURI);
  console.log("  Platform Fee Recipient:", platformFeeRecipient);

  // Deploy the contract
  const SportfolioIPO = await hre.ethers.getContractFactory("SportfolioIPO");
  const sportfolioIPO = await SportfolioIPO.deploy(
    metadataURI,
    platformFeeRecipient
  );

  await sportfolioIPO.waitForDeployment();
  const contractAddress = await sportfolioIPO.getAddress();

  console.log("\n✅ SportfolioIPO deployed successfully!");
  console.log("Contract address:", contractAddress);
  console.log("\nYou can view your contract on Sepolia Etherscan:");
  console.log(`https://sepolia.etherscan.io/address/${contractAddress}`);

  // Verify contract details
  console.log("\nContract details:");
  console.log("  Base Price:", hre.ethers.formatEther(await sportfolioIPO.getBasePrice()), "ETH");
  console.log("  Total Supply:", (await sportfolioIPO.getTotalSupply()).toString());
  console.log("  IPO Active:", await sportfolioIPO.isIPOActive());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

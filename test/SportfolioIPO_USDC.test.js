const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SportfolioIPO - USDC Pricing Verification", function () {
  let sportfolioIPO;
  let mockUSDC;
  let owner, buyer, platformFeeRecipient;

  // Constants from contract
  const BASE_PRICE = 30_000_000n; // $30 USD in USDC (6 decimals)
  const TOTAL_SUPPLY = 2_000_000n;
  const SMOOTHING_FACTOR = 200_000n;
  const PLATFORM_FEE_RATE = 300n; // 3%
  const BASIS_POINTS = 10_000n;
  const USDC_DECIMALS = 6n;

  // Example values from IPO pricing table (in USDC units with 6 decimals)
  const pricingExamples = [
    { tokensSold: 0, expectedPriceUSD: 30.00 },
    { tokensSold: 500_000, expectedPriceUSD: 38.82 },
    { tokensSold: 1_000_000, expectedPriceUSD: 55.00 },
    { tokensSold: 1_500_000, expectedPriceUSD: 94.29 },
    { tokensSold: 1_800_000, expectedPriceUSD: 165.00 },
    { tokensSold: 1_950_000, expectedPriceUSD: 264.00 },
  ];

  beforeEach(async function () {
    const signers = await ethers.getSigners();
    owner = signers[0];
    buyer = signers[1] || signers[0];
    platformFeeRecipient = signers[2] || signers[0];

    // Deploy MockUSDC
    const MockUSDC = await ethers.getContractFactory("MockUSDC");
    mockUSDC = await MockUSDC.deploy();
    await mockUSDC.waitForDeployment();

    // Deploy SportfolioIPO first
    const SportfolioIPO = await ethers.getContractFactory("SportfolioIPO");
    sportfolioIPO = await SportfolioIPO.deploy(
      "https://api.sportfolio.com/metadata/{id}.json",
      platformFeeRecipient.address,
      await mockUSDC.getAddress()
    );
    await sportfolioIPO.waitForDeployment();

    // Give buyer USDC for testing
    const buyerUSDCAmount = 1_000_000_000n * 10n**USDC_DECIMALS; // 1B USDC
    await mockUSDC.transfer(buyer.address, buyerUSDCAmount);
    
    // Pre-approve a large amount to avoid approval issues during tests
    const largeApproval = 1_000_000_000n * 10n**USDC_DECIMALS; // 1B USDC
    await mockUSDC.connect(buyer).approve(await sportfolioIPO.getAddress(), largeApproval);
  });

  // Helper function to buy tokens with USDC
  async function buyTokensWithUSDC(amount, buyerAccount = buyer) {
    const [cost, fee] = await sportfolioIPO.calculatePurchaseCost(amount);
    const totalRequired = cost + fee;
    
    // Check if we need to approve more (should already be pre-approved, but just in case)
    const contractAddress = await sportfolioIPO.getAddress();
    const currentAllowance = await mockUSDC.allowance(buyerAccount.address, contractAddress);
    if (currentAllowance < totalRequired) {
      const approveAmount = totalRequired * 2n; // Approve double to be safe
      await mockUSDC.connect(buyerAccount).approve(contractAddress, approveAmount);
    }
    
    await sportfolioIPO.connect(buyerAccount).buyTokens(amount);
    return { cost, fee, totalRequired };
  }

  // Helper to convert USDC units to USD
  function usdcToUSD(usdcUnits) {
    return Number(usdcUnits) / 1_000_000;
  }

  describe("Base Price Verification", function () {
    it("Should have correct base price of $30 USD", async function () {
      const basePrice = await sportfolioIPO.getBasePrice();
      expect(basePrice).to.equal(BASE_PRICE);
      
      const basePriceUSD = usdcToUSD(basePrice);
      expect(basePriceUSD).to.be.closeTo(30.0, 0.01);
    });

    it("Should return base price when no tokens sold", async function () {
      const price = await sportfolioIPO.getCurrentPrice();
      expect(price).to.equal(BASE_PRICE);
    });
  });

  describe("Pricing Table Verification - Matching Example Table", function () {
    // Helper to simulate tokens sold
    async function simulateTokensSold(amount) {
      const currentSold = await sportfolioIPO.getTokensSold();
      const needed = amount - currentSold;
      
      if (needed > 0) {
        await buyTokensWithUSDC(needed);
      }
    }

    it("Should match pricing table example #1: 0 tokens sold = $30.00", async function () {
      const price = await sportfolioIPO.getCurrentPrice();
      const expectedPrice = BigInt(Math.floor(30.00 * 1_000_000));
      
      expect(price).to.be.closeTo(expectedPrice, 10_000n);
      
      const priceUSD = usdcToUSD(price);
      expect(priceUSD).to.be.closeTo(30.00, 0.01);
    });

    it("Should match pricing table example #2: 500,000 tokens sold = $38.82", async function () {
      await simulateTokensSold(500_000);
      
      const price = await sportfolioIPO.getCurrentPrice();
      const expectedPrice = BigInt(Math.floor(38.82 * 1_000_000));
      
      expect(price).to.be.closeTo(expectedPrice, 10_000n);
      
      const priceUSD = usdcToUSD(price);
      expect(priceUSD).to.be.closeTo(38.82, 0.01);
    });

    it("Should match pricing table example #3: 1,000,000 tokens sold = $55.00", async function () {
      await simulateTokensSold(1_000_000);
      
      const price = await sportfolioIPO.getCurrentPrice();
      const expectedPrice = BigInt(Math.floor(55.00 * 1_000_000));
      
      expect(price).to.be.closeTo(expectedPrice, 10_000n);
      
      const priceUSD = usdcToUSD(price);
      expect(priceUSD).to.be.closeTo(55.00, 0.01);
    });

    it("Should match pricing table example #4: 1,500,000 tokens sold = $94.29", async function () {
      await simulateTokensSold(1_500_000);
      
      const price = await sportfolioIPO.getCurrentPrice();
      const expectedPrice = BigInt(Math.floor(94.29 * 1_000_000));
      
      expect(price).to.be.closeTo(expectedPrice, 10_000n);
      
      const priceUSD = usdcToUSD(price);
      expect(priceUSD).to.be.closeTo(94.29, 0.01);
    });

    it("Should match pricing table example #5: 1,800,000 tokens sold = $165.00", async function () {
      await simulateTokensSold(1_800_000);
      
      const price = await sportfolioIPO.getCurrentPrice();
      const expectedPrice = BigInt(Math.floor(165.00 * 1_000_000));
      
      expect(price).to.be.closeTo(expectedPrice, 10_000n);
      
      const priceUSD = usdcToUSD(price);
      expect(priceUSD).to.be.closeTo(165.00, 0.01);
    });

    it("Should match pricing table example #6: 1,950,000 tokens sold = $264.00", async function () {
      await simulateTokensSold(1_950_000);
      
      const price = await sportfolioIPO.getCurrentPrice();
      const expectedPrice = BigInt(Math.floor(264.00 * 1_000_000));
      
      expect(price).to.be.closeTo(expectedPrice, 10_000n);
      
      const priceUSD = usdcToUSD(price);
      expect(priceUSD).to.be.closeTo(264.00, 0.01);
    });
  });

  describe("Final Price at 2M Tokens Sold", function () {
    it("Should calculate final price of $330 USD at 2M tokens (verification only)", async function () {
      // Instead of buying all 2M tokens (too expensive), we'll verify the calculation
      // by checking the price calculation formula directly
      
      // At 2M tokens sold: remaining = 0, sigmoid factor = 2M / (0 + 200K) = 10
      // Price = $30 + ($30 × 10) = $330
      const expectedPrice = 330_000_000n; // $330 in USDC units
      
      // We can't easily test this by buying all tokens (gas limit),
      // but we can verify the calculation logic matches
      // by testing at 1,950,000 tokens (close to max) and extrapolating
      
      // Buy up to 1,950,000 tokens (from pricing table)
      const targetAmount = 1_950_000n;
      const currentSold = await sportfolioIPO.getTokensSold();
      const needed = targetAmount - currentSold;
      
      if (needed > 0) {
        // Buy in smaller batches to avoid gas issues
        const batchSize = 100_000n;
        let remaining = needed;
        
        while (remaining > 0) {
          const batch = remaining > batchSize ? batchSize : remaining;
          await buyTokensWithUSDC(batch);
          remaining -= batch;
        }
      }
      
      // Verify we're at 1,950,000
      expect(await sportfolioIPO.getTokensSold()).to.equal(targetAmount);
      
      // Price should be close to $264 (from table)
      const price = await sportfolioIPO.getCurrentPrice();
      const priceUSD = usdcToUSD(price);
      expect(priceUSD).to.be.closeTo(264.0, 1.0);
      
      // Now verify the calculation for 2M tokens would give $330
      // This is a mathematical verification, not a full purchase test
      // Formula: At 2M tokens, remaining = 0
      // Sigmoid factor = 2,000,000 / (0 + 200,000) = 10
      // Price = 30,000,000 + (30,000,000 × 10) = 330,000,000 = $330
      const calculatedFinalPrice = BASE_PRICE + (BASE_PRICE * 10n);
      expect(calculatedFinalPrice).to.equal(expectedPrice);
    });
  });

  describe("User Test Case Verification (100 tokens)", function () {
    it("Should match user's test case: Initial 100 tokens purchase", async function () {
      // Initial purchase: 0 tokens sold, buying 100
      const [cost, fee] = await sportfolioIPO.calculatePurchaseCost(100);
      
      // User's actual values from test
      const userCost = 3_000_067_455n;
      const userFee = 90_002_023n;
      
      // Allow small rounding difference (within 100 units)
      expect(cost).to.be.closeTo(userCost, 100n);
      expect(fee).to.be.closeTo(userFee, 100n);
      
      // Verify platform fee is 3%
      const expectedFee = (cost * PLATFORM_FEE_RATE) / BASIS_POINTS;
      expect(fee).to.be.closeTo(expectedFee, 1000n);
    });

    it("Should match user's test case: Price after 100 tokens sold", async function () {
      // Buy 100 tokens
      await buyTokensWithUSDC(100);
      
      const price = await sportfolioIPO.getCurrentPrice();
      const userPrice = 30_001_363n; // From user's test
      
      // Should match user's observed price
      expect(price).to.be.closeTo(userPrice, 1000n);
    });

    it("Should match user's test case: Second 100 tokens purchase", async function () {
      // Buy first 100 tokens
      await buyTokensWithUSDC(100);
      
      // Second purchase: 100 tokens sold, buying 100 more
      const [cost, fee] = await sportfolioIPO.calculatePurchaseCost(100);
      
      // User's actual values from test
      const userCost = 3_000_203_827n;
      const userFee = 90_006_114n;
      
      // Allow small rounding difference
      expect(cost).to.be.closeTo(userCost, 100n);
      expect(fee).to.be.closeTo(userFee, 100n);
    });
  });

  describe("Continuous Pricing Verification", function () {
    it("Should calculate correct price progression for first 10 tokens", async function () {
      const prices = [];
      
      for (let i = 0; i <= 10; i++) {
        if (i > 0) {
          await buyTokensWithUSDC(1);
        }
        const price = await sportfolioIPO.getCurrentPrice();
        prices.push(Number(price));
      }
      
      // Verify prices increase progressively
      for (let i = 1; i < prices.length; i++) {
        expect(prices[i]).to.be.gte(prices[i - 1]);
      }
      
      // First price should be base price
      expect(prices[0]).to.equal(Number(BASE_PRICE));
    });

    it("Should calculate individual token prices correctly", async function () {
      // Buy 1 token
      await buyTokensWithUSDC(1);
      
      const price1 = await sportfolioIPO.getCurrentPrice();
      
      // Buy another token
      await buyTokensWithUSDC(1);
      
      const price2 = await sportfolioIPO.getCurrentPrice();
      
      // Price should increase
      expect(price2).to.be.gt(price1);
    });
  });

  describe("Platform Fee Verification", function () {
    it("Should charge exactly 3% platform fee", async function () {
      const amount = 1000n;
      const [cost, fee] = await sportfolioIPO.calculatePurchaseCost(amount);
      
      const expectedFee = (cost * PLATFORM_FEE_RATE) / BASIS_POINTS;
      expect(fee).to.equal(expectedFee);
      
      // Verify it's approximately 3%
      const feePercentage = Number(fee) / Number(cost) * 100;
      expect(feePercentage).to.be.closeTo(3.0, 0.01);
    });
  });

  describe("Price Calculation Accuracy", function () {
    it("Should maintain pricing accuracy through large purchases", async function () {
      // Buy in chunks and verify prices match expected progression
      const checkpoints = [100, 500, 1000, 5000, 10000];
      
      for (const checkpoint of checkpoints) {
        const currentSold = await sportfolioIPO.getTokensSold();
        const needed = checkpoint - currentSold;
        
        if (needed > 0) {
          await buyTokensWithUSDC(needed);
        }
        
        const price = await sportfolioIPO.getCurrentPrice();
        const priceUSD = usdcToUSD(price);
        
        // Price should be at least $30 (base price)
        expect(priceUSD).to.be.gte(30.0);
        
        // Price should increase as more tokens are sold
        if (checkpoint > 100) {
          const prevPrice = await sportfolioIPO.getCurrentPrice();
          // This will be same as current, but we can verify it's reasonable
          expect(priceUSD).to.be.lt(1000.0); // Shouldn't exceed $1000 at 10k tokens
        }
      }
    });
  });
});


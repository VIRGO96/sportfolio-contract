/**
 * Pricing Verification Script
 * Verifies that pricing calculations match expected values
 */

// Constants from contract
const BASE_PRICE = 30_000_000; // $30 USD in USDC (6 decimals)
const TOTAL_SUPPLY = 2_000_000;
const SMOOTHING_FACTOR = 200_000;

// Calculate price at specific supply level
function getPriceAtSupply(soldAmount) {
    if (soldAmount === 0) return BASE_PRICE;
    
    const remaining = TOTAL_SUPPLY - soldAmount;
    const sigmoidFactor = (soldAmount * 1e18) / (remaining + SMOOTHING_FACTOR);
    
    return BASE_PRICE + (BASE_PRICE * sigmoidFactor / 1e18);
}

// Calculate total cost for purchasing tokens
function calculatePurchaseCost(tokensSold, purchaseAmount) {
    let totalCost = 0;
    for (let i = 0; i < purchaseAmount; i++) {
        const tokenPrice = getPriceAtSupply(tokensSold + i);
        totalCost += tokenPrice;
    }
    
    const platformFee = (totalCost * 300) / 10000; // 3%
    return { tokenCost: totalCost, platformFee: platformFee };
}

// Test cases from example table
const testCases = [
    { tokensSold: 0, expectedPriceUSD: 30.00 },
    { tokensSold: 500_000, expectedPriceUSD: 38.82 },
    { tokensSold: 1_000_000, expectedPriceUSD: 55.00 },
    { tokensSold: 1_500_000, expectedPriceUSD: 94.29 },
    { tokensSold: 1_800_000, expectedPriceUSD: 165.00 },
    { tokensSold: 1_950_000, expectedPriceUSD: 264.00 },
];

console.log("=".repeat(80));
console.log("Pricing Verification - USDC Implementation");
console.log("=".repeat(80));
console.log();

// Verify example table prices
console.log("1. Verifying Example Table Prices:");
console.log("-".repeat(80));
testCases.forEach((test, index) => {
    const calculatedPrice = getPriceAtSupply(test.tokensSold);
    const expectedPrice = Math.floor(test.expectedPriceUSD * 1_000_000);
    const diff = Math.abs(calculatedPrice - expectedPrice);
    const match = diff < 10_000; // Allow $0.01 tolerance
    
    console.log(`\nTest ${index + 1}: ${test.tokensSold.toLocaleString()} tokens sold`);
    console.log(`  Expected: ${expectedPrice.toLocaleString()} USDC units ($${test.expectedPriceUSD})`);
    console.log(`  Calculated: ${calculatedPrice.toLocaleString()} USDC units`);
    console.log(`  Difference: ${diff.toLocaleString()} units ${match ? '✅' : '❌'}`);
    
    if (!match) {
        console.log(`  ⚠️  MISMATCH!`);
    }
});

// Verify user's test case
console.log("\n\n2. Verifying Your Test Case (100 tokens):");
console.log("-".repeat(80));

// Initial purchase (0 tokens sold, buying 100)
const initialPurchase = calculatePurchaseCost(0, 100);
console.log("\nInitial Purchase (0 tokens sold, buying 100):");
console.log(`  Token Cost: ${initialPurchase.tokenCost.toLocaleString()} USDC units`);
console.log(`  Platform Fee: ${initialPurchase.platformFee.toLocaleString()} USDC units`);
console.log(`  Total: ${(initialPurchase.tokenCost + initialPurchase.platformFee).toLocaleString()} USDC units`);

// After 100 tokens sold, price should be:
const priceAfter100 = getPriceAtSupply(100);
console.log(`\nPrice after 100 tokens sold: ${priceAfter100.toLocaleString()} USDC units`);
console.log(`  Expected: ~30,001,363 USDC units (from your test)`);
console.log(`  Difference: ${Math.abs(priceAfter100 - 30_001_363).toLocaleString()} units`);

// Second purchase (100 tokens sold, buying 100 more)
const secondPurchase = calculatePurchaseCost(100, 100);
console.log("\nSecond Purchase (100 tokens sold, buying 100 more):");
console.log(`  Token Cost: ${secondPurchase.tokenCost.toLocaleString()} USDC units`);
console.log(`  Platform Fee: ${secondPurchase.platformFee.toLocaleString()} USDC units`);
console.log(`  Total: ${(secondPurchase.tokenCost + secondPurchase.platformFee).toLocaleString()} USDC units`);

// Verify your actual values
console.log("\nYour Actual Values:");
console.log(`  Initial: ${3_000_067_455} (cost) + ${90_002_023} (fee) = ${3_090_069_478}`);
console.log(`  Second: ${3_000_203_827} (cost) + ${90_006_114} (fee) = ${3_090_209_941}`);

const initialDiff = Math.abs(initialPurchase.tokenCost - 3_000_067_455);
const secondDiff = Math.abs(secondPurchase.tokenCost - 3_000_203_827);

console.log(`\nVerification:`);
console.log(`  Initial cost difference: ${initialDiff.toLocaleString()} units ${initialDiff < 1000 ? '✅' : '❌'}`);
console.log(`  Second cost difference: ${secondDiff.toLocaleString()} units ${secondDiff < 1000 ? '✅' : '❌'}`);

// Final price at 2M tokens
console.log("\n\n3. Final Price at 2,000,000 Tokens Sold:");
console.log("-".repeat(80));
const finalPrice = getPriceAtSupply(2_000_000);
const finalPriceUSD = finalPrice / 1_000_000;
console.log(`  Price: ${finalPrice.toLocaleString()} USDC units`);
console.log(`  Price: $${finalPriceUSD.toFixed(2)} USD`);
console.log(`  Note: At 2M tokens, remaining = 0, sigmoid factor = 2M / 200K = 10`);
console.log(`  Expected: $30 + ($30 × 10) = $330 USD`);

// Verify continuous pricing progression
console.log("\n\n4. Price Progression (First 10 tokens):");
console.log("-".repeat(80));
for (let i = 0; i <= 10; i++) {
    const price = getPriceAtSupply(i);
    const priceUSD = price / 1_000_000;
    console.log(`  Token ${i}: ${price.toLocaleString()} USDC = $${priceUSD.toFixed(6)} USD`);
}

console.log("\n" + "=".repeat(80));
console.log("✅ Verification Complete!");
console.log("=".repeat(80));


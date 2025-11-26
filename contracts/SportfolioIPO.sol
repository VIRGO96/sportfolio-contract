// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title SportfolioIPO
 * @dev ERC-1155 smart contract for IPO stage with sigmoid bonding curve pricing
 * Only handles IPO phase - secondary market functionality excluded for MVP
 */
contract SportfolioIPO is ERC1155, Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    // Constants
    // BASE_PRICE is in USDC units (6 decimals): $30 USD = 30,000,000 USDC units
    uint256 public constant BASE_PRICE = 30_000_000; // $30 USD in USDC (6 decimals)
    uint256 public constant TOTAL_SUPPLY = 2_000_000; // 2M total tokens
    uint256 public constant SMOOTHING_FACTOR = 200_000; // Prevents extreme price spikes
    uint256 public constant PLATFORM_FEE_RATE = 300; // 3% = 300 basis points
    uint256 public constant BASIS_POINTS = 10_000; // 100% = 10,000 basis points
    
    // Team token ID (Lakers example)
    uint256 public constant LAKERS_TOKEN_ID = 1;
    
    // State variables
    uint256 public tokensSold;
    bool public ipoActive = true;
    address public platformFeeRecipient;
    IERC20 public paymentToken; // USDC token address
    
    // Events
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 totalCost, uint256 platformFee);
    event IPOCompleted(uint256 finalPrice, uint256 timestamp);
    event IPOPaused();
    event IPOResumed();
    
    // Modifiers
    modifier onlyDuringIPO() {
        require(ipoActive, "IPO has ended");
        require(tokensSold < TOTAL_SUPPLY, "All tokens sold");
        _;
    }
    
    constructor(
        string memory uri,
        address _platformFeeRecipient,
        address _paymentToken
    ) ERC1155(uri) Ownable() {
        require(_platformFeeRecipient != address(0), "Invalid fee recipient");
        require(_paymentToken != address(0), "Invalid payment token");
        platformFeeRecipient = _platformFeeRecipient;
        paymentToken = IERC20(_paymentToken);
    }
    
    /**
     * @dev Returns current token price based on sigmoid curve
     * Formula: Price = $30 + ($30 × Sigmoid_Factor)
     * Where: Sigmoid_Factor = tokens_sold / (total_supply - tokens_sold + smoothing_factor)
     */
    function getCurrentPrice() public view returns (uint256) {
        if (tokensSold == 0) return BASE_PRICE;
        
        uint256 remaining = TOTAL_SUPPLY - tokensSold;
        uint256 sigmoidFactor = (tokensSold * 1e18) / (remaining + SMOOTHING_FACTOR);
        
        return BASE_PRICE + (BASE_PRICE * sigmoidFactor / 1e18);
    }
    
    /**
     * @dev Calculates total cost for purchasing specific token amount
     * Uses continuous pricing - each token priced individually based on exact supply position
     * Formula: Sum of prices for token #1, #2, #3... #N where each token has its exact calculated price
     */
    function calculatePurchaseCost(uint256 tokenAmount) public view returns (uint256 tokenCost, uint256 platformFee) {
        require(tokenAmount > 0, "Must buy at least 1 token");
        require(tokensSold + tokenAmount <= TOTAL_SUPPLY, "Exceeds total supply");
        
        uint256 totalCost = 0;
        uint256 currentSold = tokensSold;
        
        // Continuous pricing: Calculate individual price for each token
        // Token #1 priced at supply level (tokensSold + 0)
        // Token #2 priced at supply level (tokensSold + 1)
        // Token #3 priced at supply level (tokensSold + 2)
        // ... and so on
        for (uint256 i = 0; i < tokenAmount; i++) {
            uint256 tokenPrice = getPriceAtSupply(currentSold + i);
            totalCost += tokenPrice;
        }
        
        tokenCost = totalCost;
        platformFee = (totalCost * PLATFORM_FEE_RATE) / BASIS_POINTS;
    }
    
    /**
     * @dev Internal function to get price at specific supply level
     */
    function getPriceAtSupply(uint256 soldAmount) internal pure returns (uint256) {
        if (soldAmount == 0) return BASE_PRICE;
        
        uint256 remaining = TOTAL_SUPPLY - soldAmount;
        uint256 sigmoidFactor = (soldAmount * 1e18) / (remaining + SMOOTHING_FACTOR);
        
        return BASE_PRICE + (BASE_PRICE * sigmoidFactor / 1e18);
    }
    
    /**
     * @dev Purchase tokens during IPO phase using USDC
     * Implements continuous pricing with batched execution
     * 
     * IMPORTANT: Users must approve USDC spending before calling this function
     * Frontend should: 1) Approve USDC, 2) Call buyTokens()
     * 
     * @param amount Number of tokens to purchase
     */
    function buyTokens(uint256 amount) external nonReentrant onlyDuringIPO whenNotPaused {
        require(amount > 0, "Must buy at least 1 token");
        require(tokensSold + amount <= TOTAL_SUPPLY, "Exceeds total supply");
        
        (uint256 tokenCost, uint256 platformFee) = calculatePurchaseCost(amount);
        uint256 totalRequired = tokenCost + platformFee;
        
        // Check user has approved enough USDC
        uint256 allowance = paymentToken.allowance(msg.sender, address(this));
        require(allowance >= totalRequired, "Insufficient USDC allowance. Please approve first.");
        
        // Check user has enough USDC balance
        uint256 balance = paymentToken.balanceOf(msg.sender);
        require(balance >= totalRequired, "Insufficient USDC balance");
        
        // Transfer USDC from buyer to contract
        paymentToken.safeTransferFrom(msg.sender, address(this), totalRequired);
        
        // Mint tokens to buyer
        _mint(msg.sender, LAKERS_TOKEN_ID, amount, "");
        
        // Update tokens sold
        tokensSold += amount;
        
        // Transfer platform fee to recipient
        if (platformFee > 0) {
            paymentToken.safeTransfer(platformFeeRecipient, platformFee);
        }
        
        emit TokensPurchased(msg.sender, amount, tokenCost, platformFee);
        
        // Check if IPO is complete
        if (tokensSold == TOTAL_SUPPLY) {
            ipoActive = false;
            emit IPOCompleted(getCurrentPrice(), block.timestamp);
        }
    }
    
    /**
     * @dev Returns total tokens sold so far
     */
    function getTokensSold() external view returns (uint256) {
        return tokensSold;
    }
    
    /**
     * @dev Returns tokens still available for purchase
     */
    function getRemainingTokens() external view returns (uint256) {
        return TOTAL_SUPPLY - tokensSold;
    }
    
    /**
     * @dev Returns maximum tokens that can be bought (prevents overselling)
     */
    function getMaxPurchaseAmount() external view returns (uint256) {
        return TOTAL_SUPPLY - tokensSold;
    }
    
    /**
     * @dev Returns current sigmoid factor for price calculation
     */
    function getSigmoidFactor() external view returns (uint256) {
        if (tokensSold == 0) return 0;
        
        uint256 remaining = TOTAL_SUPPLY - tokensSold;
        return (tokensSold * 1e18) / (remaining + SMOOTHING_FACTOR);
    }
    
    /**
     * @dev Returns the smoothing factor parameter
     */
    function getSmoothingFactor() external pure returns (uint256) {
        return SMOOTHING_FACTOR;
    }
    
    /**
     * @dev Returns the total token supply
     */
    function getTotalSupply() external pure returns (uint256) {
        return TOTAL_SUPPLY;
    }
    
    /**
     * @dev Returns the base starting price
     */
    function getBasePrice() external pure returns (uint256) {
        return BASE_PRICE;
    }
    
    /**
     * @dev Returns IPO status
     */
    function isIPOActive() external view returns (bool) {
        return ipoActive && tokensSold < TOTAL_SUPPLY;
    }
    
    /**
     * @dev Emergency pause IPO (owner only)
     */
    function pauseIPO() external onlyOwner {
        _pause();
        emit IPOPaused();
    }
    
    /**
     * @dev Resume IPO (owner only)
     */
    function resumeIPO() external onlyOwner {
        _unpause();
        emit IPOResumed();
    }
    
    /**
     * @dev Manually complete IPO (owner only)
     * For emergency situations or strategic decisions
     */
    function completeIPO() external onlyOwner {
        require(ipoActive, "IPO already completed");
        
        uint256 finalPrice = getCurrentPrice();
        ipoActive = false;
        
        emit IPOCompleted(finalPrice, block.timestamp);
    }
    
    /**
     * @dev Update platform fee recipient (owner only)
     */
    function setPlatformFeeRecipient(address _newRecipient) external onlyOwner {
        require(_newRecipient != address(0), "Invalid recipient");
        platformFeeRecipient = _newRecipient;
    }
    
    /**
     * @dev Withdraw USDC balance (owner only)
     * For any remaining USDC after IPO completion
     */
    function withdraw() external onlyOwner {
        require(!ipoActive, "IPO still active");
        
        uint256 balance = paymentToken.balanceOf(address(this));
        require(balance > 0, "No balance to withdraw");
        
        paymentToken.safeTransfer(owner(), balance);
    }
    
    /**
     * @dev Get payment token address (USDC)
     * Useful for frontend to know which token to approve
     */
    function getPaymentToken() external view returns (address) {
        return address(paymentToken);
    }
    
    /**
     * @dev Override to prevent transfers during IPO phase
     * Tokens should not be transferable until secondary market opens
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(!ipoActive, "Transfers not allowed during IPO");
        super.safeTransferFrom(from, to, id, amount, data);
    }
    
    /**
     * @dev Override to prevent batch transfers during IPO phase
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(!ipoActive, "Transfers not allowed during IPO");
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }
}
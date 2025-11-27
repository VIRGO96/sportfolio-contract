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
    uint256 public constant TOTAL_SUPPLY = 2_000_000; // 2M total tokens per team
    uint256 public constant SMOOTHING_FACTOR = 200_000; // Prevents extreme price spikes
    uint256 public constant PLATFORM_FEE_RATE = 300; // 3% = 300 basis points
    uint256 public constant BASIS_POINTS = 10_000; // 100% = 10,000 basis points
    
    // Team IPO data structure
    struct TeamIPO {
        uint256 tokenId;           // ERC1155 token ID (1, 2, 3...)
        string teamName;           // Team name stored on-chain for quick access
        uint256 tokensSold;        // Tokens sold for this team
        bool ipoActive;            // Is IPO active for this team
        uint256 ipoStartTime;      // When IPO started
        uint256 ipoEndTime;        // When IPO ended (0 if still active)
    }
    
    // State variables
    mapping(uint256 => TeamIPO) public teams;  // tokenId => TeamIPO
    uint256[] public teamIds;                  // List of all team token IDs
    address public platformFeeRecipient;
    IERC20 public paymentToken; // USDC token address
    
    // Events
    event TeamAdded(uint256 indexed tokenId, string teamName, uint256 timestamp);
    event TokensPurchased(address indexed buyer, uint256 indexed tokenId, uint256 amount, uint256 totalCost, uint256 platformFee);
    event IPOCompleted(uint256 indexed tokenId, uint256 finalPrice, uint256 timestamp);
    event IPOPaused(uint256 indexed tokenId);
    event IPOResumed(uint256 indexed tokenId);
    
    // Modifiers
    modifier onlyDuringIPO(uint256 tokenId) {
        require(teams[tokenId].ipoActive, "Team IPO has ended");
        require(teams[tokenId].tokensSold < TOTAL_SUPPLY, "All tokens sold");
        _;
    }
    
    modifier teamExists(uint256 tokenId) {
        require(teams[tokenId].tokenId != 0, "Team does not exist");
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
     * @dev Returns current token price for a specific team based on sigmoid curve
     * Formula: Price = $30 + ($30 × Sigmoid_Factor)
     * Where: Sigmoid_Factor = tokens_sold / (total_supply - tokens_sold + smoothing_factor)
     * @param tokenId Team token ID
     */
    function getCurrentPrice(uint256 tokenId) public view teamExists(tokenId) returns (uint256) {
        TeamIPO memory team = teams[tokenId];
        if (team.tokensSold == 0) return BASE_PRICE;
        
        uint256 remaining = TOTAL_SUPPLY - team.tokensSold;
        uint256 sigmoidFactor = (team.tokensSold * 1e18) / (remaining + SMOOTHING_FACTOR);
        
        return BASE_PRICE + (BASE_PRICE * sigmoidFactor / 1e18);
    }
    
    /**
     * @dev Calculates total cost for purchasing specific token amount for a team
     * Uses continuous pricing - each token priced individually based on exact supply position
     * Formula: Sum of prices for token #1, #2, #3... #N where each token has its exact calculated price
     * @param tokenId Team token ID
     * @param tokenAmount Number of tokens to purchase
     */
    function calculatePurchaseCost(uint256 tokenId, uint256 tokenAmount) public view teamExists(tokenId) returns (uint256 tokenCost, uint256 platformFee) {
        require(tokenAmount > 0, "Must buy at least 1 token");
        TeamIPO memory team = teams[tokenId];
        require(team.tokensSold + tokenAmount <= TOTAL_SUPPLY, "Exceeds total supply");
        
        uint256 totalCost = 0;
        uint256 currentSold = team.tokensSold;
        
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
     * @dev Purchase tokens for a specific team during IPO phase using USDC
     * Implements continuous pricing with batched execution
     * 
     * IMPORTANT: Users must approve USDC spending before calling this function
     * Frontend should: 1) Approve USDC, 2) Call buyTokens()
     * 
     * @param tokenId Team token ID
     * @param amount Number of tokens to purchase
     */
    function buyTokens(uint256 tokenId, uint256 amount) external nonReentrant onlyDuringIPO(tokenId) whenNotPaused {
        require(amount > 0, "Must buy at least 1 token");
        TeamIPO storage team = teams[tokenId];
        require(team.tokensSold + amount <= TOTAL_SUPPLY, "Exceeds total supply");
        
        (uint256 tokenCost, uint256 platformFee) = calculatePurchaseCost(tokenId, amount);
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
        _mint(msg.sender, tokenId, amount, "");
        
        // Update this team's tokens sold
        team.tokensSold += amount;
        
        // Transfer platform fee to recipient
        if (platformFee > 0) {
            paymentToken.safeTransfer(platformFeeRecipient, platformFee);
        }
        
        emit TokensPurchased(msg.sender, tokenId, amount, tokenCost, platformFee);
        
        // Check if this team's IPO is complete
        if (team.tokensSold == TOTAL_SUPPLY) {
            team.ipoActive = false;
            team.ipoEndTime = block.timestamp;
            emit IPOCompleted(tokenId, getCurrentPrice(tokenId), block.timestamp);
        }
    }
    
    /**
     * @dev Add a new team IPO (owner only)
     * @param tokenId Team token ID (should be sequential: 1, 2, 3...)
     * @param teamName Team name (stored on-chain for quick access)
     */
    function addTeam(uint256 tokenId, string memory teamName) external onlyOwner {
        require(tokenId > 0, "Token ID must be greater than 0");
        require(teams[tokenId].tokenId == 0, "Team already exists");
        require(bytes(teamName).length > 0, "Team name cannot be empty");
        
        teams[tokenId] = TeamIPO({
            tokenId: tokenId,
            teamName: teamName,
            tokensSold: 0,
            ipoActive: true,
            ipoStartTime: block.timestamp,
            ipoEndTime: 0
        });
        
        teamIds.push(tokenId);
        
        emit TeamAdded(tokenId, teamName, block.timestamp);
    }
    
    /**
     * @dev Get team information
     * @param tokenId Team token ID
     */
    function getTeamInfo(uint256 tokenId) external view returns (TeamIPO memory) {
        require(teams[tokenId].tokenId != 0, "Team does not exist");
        return teams[tokenId];
    }
    
    /**
     * @dev Get all team token IDs
     */
    function getAllTeams() external view returns (uint256[] memory) {
        return teamIds;
    }
    
    /**
     * @dev Get total number of teams
     */
    function getTeamCount() external view returns (uint256) {
        return teamIds.length;
    }
    
    /**
     * @dev Returns total tokens sold for a specific team
     * @param tokenId Team token ID
     */
    function getTokensSold(uint256 tokenId) external view teamExists(tokenId) returns (uint256) {
        return teams[tokenId].tokensSold;
    }
    
    /**
     * @dev Returns tokens still available for purchase for a specific team
     * @param tokenId Team token ID
     */
    function getRemainingTokens(uint256 tokenId) external view teamExists(tokenId) returns (uint256) {
        return TOTAL_SUPPLY - teams[tokenId].tokensSold;
    }
    
    /**
     * @dev Returns maximum tokens that can be bought for a specific team (prevents overselling)
     * @param tokenId Team token ID
     */
    function getMaxPurchaseAmount(uint256 tokenId) external view teamExists(tokenId) returns (uint256) {
        return TOTAL_SUPPLY - teams[tokenId].tokensSold;
    }
    
    /**
     * @dev Returns current sigmoid factor for price calculation for a specific team
     * @param tokenId Team token ID
     */
    function getSigmoidFactor(uint256 tokenId) external view teamExists(tokenId) returns (uint256) {
        TeamIPO memory team = teams[tokenId];
        if (team.tokensSold == 0) return 0;
        
        uint256 remaining = TOTAL_SUPPLY - team.tokensSold;
        return (team.tokensSold * 1e18) / (remaining + SMOOTHING_FACTOR);
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
     * @dev Returns IPO status for a specific team
     * @param tokenId Team token ID
     */
    function isIPOActive(uint256 tokenId) external view teamExists(tokenId) returns (bool) {
        TeamIPO memory team = teams[tokenId];
        return team.ipoActive && team.tokensSold < TOTAL_SUPPLY;
    }
    
    /**
     * @dev Emergency pause IPO for a specific team (owner only)
     * @param tokenId Team token ID
     */
    function pauseIPO(uint256 tokenId) external onlyOwner teamExists(tokenId) {
        require(teams[tokenId].ipoActive, "IPO already paused or completed");
        teams[tokenId].ipoActive = false;
        emit IPOPaused(tokenId);
    }
    
    /**
     * @dev Resume IPO for a specific team (owner only)
     * @param tokenId Team token ID
     */
    function resumeIPO(uint256 tokenId) external onlyOwner teamExists(tokenId) {
        require(!teams[tokenId].ipoActive, "IPO already active");
        require(teams[tokenId].tokensSold < TOTAL_SUPPLY, "All tokens sold");
        teams[tokenId].ipoActive = true;
        emit IPOResumed(tokenId);
    }
    
    /**
     * @dev Manually complete IPO for a specific team (owner only)
     * For emergency situations or strategic decisions
     * @param tokenId Team token ID
     */
    function completeIPO(uint256 tokenId) external onlyOwner teamExists(tokenId) {
        TeamIPO storage team = teams[tokenId];
        require(team.ipoActive, "IPO already completed");
        
        uint256 finalPrice = getCurrentPrice(tokenId);
        team.ipoActive = false;
        team.ipoEndTime = block.timestamp;
        
        emit IPOCompleted(tokenId, finalPrice, block.timestamp);
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
     * Can withdraw even if some teams' IPOs are still active
     * @param amount Amount to withdraw (0 = withdraw all)
     */
    function withdraw(uint256 amount) external onlyOwner {
        uint256 balance = paymentToken.balanceOf(address(this));
        require(balance > 0, "No balance to withdraw");
        
        uint256 withdrawAmount = amount == 0 ? balance : amount;
        require(withdrawAmount <= balance, "Insufficient balance");
        
        paymentToken.safeTransfer(owner(), withdrawAmount);
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
     * Checks if the specific team's IPO is active
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(teams[id].tokenId == 0 || !teams[id].ipoActive, "Transfers not allowed during IPO");
        super.safeTransferFrom(from, to, id, amount, data);
    }
    
    /**
     * @dev Override to prevent batch transfers during IPO phase
     * Checks each token ID's IPO status
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        for (uint256 i = 0; i < ids.length; i++) {
            require(teams[ids[i]].tokenId == 0 || !teams[ids[i]].ipoActive, "Transfers not allowed during IPO");
        }
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }
}
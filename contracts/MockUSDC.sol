// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDC
 * @dev Mock USDC token for testing purposes
 * USDC uses 6 decimals (not 18 like ETH)
 */
contract MockUSDC is ERC20 {
    uint8 private constant _decimals = 6;
    
    constructor() ERC20("Mock USD Coin", "mUSDC") {
        // Mint 1 billion USDC to deployer for testing
        _mint(msg.sender, 1_000_000_000 * 10**6);
    }
    
    function decimals() public pure override returns (uint8) {
        return _decimals;
    }
    
    /**
     * @dev Mint tokens to an address (for testing)
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}


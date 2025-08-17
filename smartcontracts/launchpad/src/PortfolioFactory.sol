// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Interfaces.sol";
import "./UserPortfolio.sol";

/**
 * Factory contract - deploys individual user contracts
 */
contract PortfolioFactory {
    IERC20 public immutable USDC;
    address public immutable usdcPriceFeed;
    address public owner;
    mapping(address => address) public userContracts;
    
    event UserPortfolioCreated(address indexed user, address contractAddress);
    
    modifier onlyOwner() { require(msg.sender == owner, "ONLY_OWNER"); _; }
    
    constructor(address _usdc, address _usdcPriceFeed) {
        require(_usdc != address(0), "BAD_USDC");
        USDC = IERC20(_usdc);
        usdcPriceFeed = _usdcPriceFeed;
        owner = msg.sender;
    }
    
    /// Create a new portfolio for the calling user
    function createUserPortfolio() external {
        require(userContracts[msg.sender] == address(0), "EXISTS");

        UserPortfolio userPortfolio = new UserPortfolio(
            address(USDC),
            msg.sender
        );
        userContracts[msg.sender] = address(userPortfolio);
        
        emit UserPortfolioCreated(msg.sender, address(userPortfolio));
    }

    /// Get user's portfolio address
    function getUserPortfolio(address user) external view returns (address) {
        return userContracts[user];
    }
}

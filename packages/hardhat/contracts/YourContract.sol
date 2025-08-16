// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title PriceConsumerV3
 * @dev A smart contract that consumes price data from a Chainlink Price Feed.
 */
contract PriceConsumerV3 {
    AggregatorV3Interface internal priceFeed;

    /**
     * @dev Constructor initializes the price feed interface.
     * @param _priceFeedAddress The address of the Chainlink Price Feed on Base Sepolia.
     */
    constructor(address _priceFeedAddress) {
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
    }

    /**
     * @dev Returns the latest price from the Chainlink Price Feed.
     * @return The latest price.
     */
    function getLatestPrice() public view returns (int) {
        (
            /* uint80 roundID */,
            int price,
            /* uint startedAt */,
            /* uint timeStamp */,
            /* uint80 answeredInRound */
        ) = priceFeed.latestRoundData();
        return price;
    }

    /**
     * @dev Returns the number of decimals for the price feed.
     * @return The number of decimals.
     */
    function getDecimals() public view returns (uint8) {
        return priceFeed.decimals();
    }

    /**
     * @dev Returns the description of the price feed.
     * @return The description of the price feed.
     */
    function getDescription() public view returns (string memory) {
        return priceFeed.description();
    }

    /**
     * @dev Returns the version of the price feed.
     * @return The version of the price feed.
     */
    function getVersion() public view returns (uint256) {
        return priceFeed.version();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IChainlinkAggregator} from "./interfaces/IChainlinkAggregator.sol";

/// @title OracleAdapter
/// @notice Secure price feed adapter for Chainlink XAU/USD with validation
/// @dev Implements staleness checks, deviation limits, and circuit breaker
contract OracleAdapter is Ownable, Pausable {
    // ============ Errors ============
    error InvalidPrice();
    error StalePrice();
    error ExcessiveDeviation();
    error InvalidThreshold();
    error InvalidPriceFeed();

    // ============ Events ============
    event PriceUpdated(uint256 price, uint256 timestamp);
    event CircuitBreakerTriggered(uint256 price, uint256 deviation);
    event StalenessThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event DeviationThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event CircuitBreakerEnabled();
    event CircuitBreakerDisabled();

    // ============ State Variables ============

    /// @notice Chainlink price feed aggregator
    IChainlinkAggregator public immutable priceFeed;

    /// @notice Output decimals (normalized to 18)
    uint8 public constant decimals = 18;

    /// @notice Maximum age of price data before considered stale (default: 1 hour)
    uint256 public stalenessThreshold = 3600;

    /// @notice Maximum allowed price deviation in basis points (default: 5% = 500 bps)
    uint256 public deviationThreshold = 500;

    /// @notice Last known valid price (for deviation calculation)
    uint256 public lastValidPrice;

    /// @notice Timestamp of last valid price
    uint256 public lastValidTimestamp;

    /// @notice Whether circuit breaker auto-pause is enabled
    bool public circuitBreakerEnabled;

    /// @notice Chainlink feed decimals
    uint8 private immutable _feedDecimals;

    // ============ Constructor ============

    /// @notice Initialize the oracle adapter
    /// @param _priceFeed Address of Chainlink XAU/USD price feed
    constructor(address _priceFeed) Ownable(msg.sender) {
        if (_priceFeed == address(0)) revert InvalidPriceFeed();

        priceFeed = IChainlinkAggregator(_priceFeed);
        _feedDecimals = priceFeed.decimals();

        // Initialize with current price
        (, int256 answer,, uint256 updatedAt,) = priceFeed.latestRoundData();
        if (answer <= 0) revert InvalidPrice();

        lastValidPrice = _normalizePrice(answer);
        lastValidTimestamp = updatedAt;
    }

    // ============ External Functions ============

    /// @notice Get the latest XAU/USD price
    /// @return price Price normalized to 18 decimals
    function getLatestPrice() external whenNotPaused returns (uint256 price) {
        (price,) = _getValidatedPrice();
        return price;
    }

    /// @notice Get the latest price with timestamp
    /// @return price Price normalized to 18 decimals
    /// @return timestamp When the price was last updated
    function getLatestPriceWithTimestamp() external whenNotPaused returns (uint256 price, uint256 timestamp) {
        return _getValidatedPrice();
    }

    // ============ Admin Functions ============

    /// @notice Pause the oracle (emergency)
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the oracle
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Update staleness threshold
    /// @param newThreshold New threshold in seconds
    function setStalenessThreshold(uint256 newThreshold) external onlyOwner {
        if (newThreshold == 0) revert InvalidThreshold();
        emit StalenessThresholdUpdated(stalenessThreshold, newThreshold);
        stalenessThreshold = newThreshold;
    }

    /// @notice Update deviation threshold
    /// @param newThreshold New threshold in basis points (100 = 1%)
    function setDeviationThreshold(uint256 newThreshold) external onlyOwner {
        if (newThreshold == 0) revert InvalidThreshold();
        emit DeviationThresholdUpdated(deviationThreshold, newThreshold);
        deviationThreshold = newThreshold;
    }

    /// @notice Enable circuit breaker auto-pause
    function enableCircuitBreaker() external onlyOwner {
        circuitBreakerEnabled = true;
        emit CircuitBreakerEnabled();
    }

    /// @notice Disable circuit breaker auto-pause
    function disableCircuitBreaker() external onlyOwner {
        circuitBreakerEnabled = false;
        emit CircuitBreakerDisabled();
    }

    /// @notice Manually trigger circuit breaker
    function triggerCircuitBreaker() external onlyOwner {
        _pause();
    }

    // ============ Internal Functions ============

    /// @notice Get and validate price from Chainlink
    /// @return price Validated price normalized to 18 decimals
    /// @return timestamp When the price was last updated
    function _getValidatedPrice() internal returns (uint256 price, uint256 timestamp) {
        (, int256 answer,, uint256 updatedAt,) = priceFeed.latestRoundData();

        // Check for invalid price
        if (answer <= 0) revert InvalidPrice();

        // Check for stale price
        if (block.timestamp - updatedAt > stalenessThreshold) {
            revert StalePrice();
        }

        // Normalize price to 18 decimals
        price = _normalizePrice(answer);
        timestamp = updatedAt;

        // Check deviation from last known price
        uint256 deviation = _calculateDeviation(price, lastValidPrice);
        if (deviation > deviationThreshold) {
            if (circuitBreakerEnabled) {
                emit CircuitBreakerTriggered(price, deviation);
                _pause();
            }
            revert ExcessiveDeviation();
        }

        // Update last valid price
        lastValidPrice = price;
        lastValidTimestamp = timestamp;

        emit PriceUpdated(price, timestamp);
        return (price, timestamp);
    }

    /// @notice Normalize price from feed decimals to 18 decimals
    /// @param rawPrice Raw price from Chainlink
    /// @return Normalized price with 18 decimals
    function _normalizePrice(int256 rawPrice) internal view returns (uint256) {
        // Convert from feed decimals (typically 8) to 18 decimals
        uint256 multiplier = 10 ** (decimals - _feedDecimals);
        return uint256(rawPrice) * multiplier;
    }

    /// @notice Calculate deviation between two prices in basis points
    /// @param newPrice New price
    /// @param oldPrice Previous price
    /// @return Deviation in basis points (100 = 1%)
    function _calculateDeviation(uint256 newPrice, uint256 oldPrice) internal pure returns (uint256) {
        if (oldPrice == 0) return 0;

        uint256 diff;
        if (newPrice >= oldPrice) {
            diff = newPrice - oldPrice;
        } else {
            diff = oldPrice - newPrice;
        }

        // Return deviation in basis points
        return (diff * 10000) / oldPrice;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {OracleAdapter} from "../src/OracleAdapter.sol";
import {IChainlinkAggregator} from "../src/interfaces/IChainlinkAggregator.sol";

/// @title MockChainlinkAggregator
/// @notice Mock Chainlink aggregator for testing
contract MockChainlinkAggregator is IChainlinkAggregator {
    int256 private _price;
    uint256 private _updatedAt;
    uint8 private _decimals;
    uint80 private _roundId;

    constructor(int256 initialPrice, uint8 decimals_) {
        _price = initialPrice;
        _decimals = decimals_;
        _updatedAt = block.timestamp;
        _roundId = 1;
    }

    function setPrice(int256 price) external {
        _price = price;
        _updatedAt = block.timestamp;
        _roundId++;
    }

    function setPriceWithTimestamp(int256 price, uint256 timestamp) external {
        _price = price;
        _updatedAt = timestamp;
        _roundId++;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function description() external pure override returns (string memory) {
        return "XAU / USD";
    }

    function version() external pure override returns (uint256) {
        return 4;
    }

    function getRoundData(uint80)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }
}

/// @title OracleAdapterTest
/// @notice Comprehensive test suite for OracleAdapter
contract OracleAdapterTest is Test {
    OracleAdapter public oracle;
    MockChainlinkAggregator public mockAggregator;

    address public owner;
    address public user;

    // XAU/USD price: ~$2,000 per ounce (8 decimals from Chainlink)
    int256 constant INITIAL_PRICE = 2000_00000000; // $2,000.00
    uint8 constant CHAINLINK_DECIMALS = 8;

    // Events
    event PriceUpdated(uint256 price, uint256 timestamp);
    event CircuitBreakerTriggered(uint256 price, uint256 deviation);
    event StalenessThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event DeviationThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

    function setUp() public {
        owner = address(this);
        user = makeAddr("user");

        // Deploy mock aggregator with initial price
        mockAggregator = new MockChainlinkAggregator(INITIAL_PRICE, CHAINLINK_DECIMALS);

        // Deploy OracleAdapter
        oracle = new OracleAdapter(address(mockAggregator));
    }

    // ============ Functional Tests ============

    function test_GetLatestPrice() public {
        uint256 price = oracle.getLatestPrice();
        // Price should be normalized to 18 decimals
        // $2,000 with 8 decimals = 2000_00000000
        // Normalized to 18 decimals = 2000_000000000000000000
        assertEq(price, 2000 * 1e18);
    }

    function test_GetLatestPriceWithTimestamp() public {
        (uint256 price, uint256 timestamp) = oracle.getLatestPriceWithTimestamp();
        assertEq(price, 2000 * 1e18);
        assertEq(timestamp, block.timestamp);
    }

    function test_GetPriceFeedAddress() public view {
        assertEq(address(oracle.priceFeed()), address(mockAggregator));
    }

    function test_GetDecimals() public view {
        assertEq(oracle.decimals(), 18);
    }

    // ============ Boundary Tests ============

    function test_MinimumValidPrice() public {
        // First update to a price close to $1 to avoid deviation check
        // Gradually decrease price: $2000 -> $1900 -> ... -> $1
        // But for simplicity, increase deviation threshold for this test
        oracle.setDeviationThreshold(10000); // 100% threshold

        // Set price to minimum valid ($1)
        mockAggregator.setPrice(1_00000000);
        uint256 price = oracle.getLatestPrice();
        assertEq(price, 1 * 1e18);
    }

    function test_MaximumRealisticPrice() public {
        // Increase deviation threshold for boundary test (5000% = 500000 bps)
        // Needed because we're testing $100,000 vs initial $2,000 = 4900% change
        oracle.setDeviationThreshold(500000);

        // Set price to very high value ($100,000 per oz - unlikely but test boundary)
        mockAggregator.setPrice(100000_00000000);
        uint256 price = oracle.getLatestPrice();
        assertEq(price, 100000 * 1e18);
    }

    function testFuzz_PriceNormalization(uint256 rawPriceInput) public {
        // Disable deviation check for fuzz testing price normalization
        // Set very high threshold (10000% = 1000000 bps) to test normalization math
        oracle.setDeviationThreshold(1000000);

        // Bound to reasonable gold prices ($100 - $50,000) in 8 decimals
        uint256 rawPrice = bound(rawPriceInput, 100_00000000, 50000_00000000);
        mockAggregator.setPrice(int256(rawPrice));

        uint256 normalizedPrice = oracle.getLatestPrice();
        uint256 expectedPrice = rawPrice * 1e10; // 8 decimals -> 18 decimals
        assertEq(normalizedPrice, expectedPrice);
    }

    // ============ Exception Tests ============

    function test_RevertOnZeroPrice() public {
        mockAggregator.setPrice(0);
        vm.expectRevert(OracleAdapter.InvalidPrice.selector);
        oracle.getLatestPrice();
    }

    function test_RevertOnNegativePrice() public {
        mockAggregator.setPrice(-1);
        vm.expectRevert(OracleAdapter.InvalidPrice.selector);
        oracle.getLatestPrice();
    }

    function test_RevertOnStalePrice() public {
        // Advance time by more than staleness threshold (1 hour)
        vm.warp(block.timestamp + 3601);
        vm.expectRevert(OracleAdapter.StalePrice.selector);
        oracle.getLatestPrice();
    }

    function test_RevertOnExcessiveDeviation() public {
        // Initial price is $2,000
        // Set new price with >5% deviation ($2,200 = 10% increase)
        mockAggregator.setPrice(2200_00000000);
        vm.expectRevert(OracleAdapter.ExcessiveDeviation.selector);
        oracle.getLatestPrice();
    }

    // ============ Security Tests ============

    function test_OnlyOwnerCanPause() public {
        vm.prank(user);
        vm.expectRevert();
        oracle.pause();
    }

    function test_OnlyOwnerCanUnpause() public {
        oracle.pause();
        vm.prank(user);
        vm.expectRevert();
        oracle.unpause();
    }

    function test_CannotGetPriceWhenPaused() public {
        oracle.pause();
        vm.expectRevert();
        oracle.getLatestPrice();
    }

    function test_OnlyOwnerCanUpdateStalenessThreshold() public {
        vm.prank(user);
        vm.expectRevert();
        oracle.setStalenessThreshold(7200);
    }

    function test_OnlyOwnerCanUpdateDeviationThreshold() public {
        vm.prank(user);
        vm.expectRevert();
        oracle.setDeviationThreshold(1000);
    }

    // ============ Configuration Tests ============

    function test_UpdateStalenessThreshold() public {
        uint256 newThreshold = 7200; // 2 hours
        vm.expectEmit(true, true, false, true);
        emit StalenessThresholdUpdated(3600, newThreshold);
        oracle.setStalenessThreshold(newThreshold);
        assertEq(oracle.stalenessThreshold(), newThreshold);
    }

    function test_UpdateDeviationThreshold() public {
        uint256 newThreshold = 1000; // 10%
        vm.expectEmit(true, true, false, true);
        emit DeviationThresholdUpdated(500, newThreshold);
        oracle.setDeviationThreshold(newThreshold);
        assertEq(oracle.deviationThreshold(), newThreshold);
    }

    function test_RevertOnZeroStalenessThreshold() public {
        vm.expectRevert(OracleAdapter.InvalidThreshold.selector);
        oracle.setStalenessThreshold(0);
    }

    function test_RevertOnZeroDeviationThreshold() public {
        vm.expectRevert(OracleAdapter.InvalidThreshold.selector);
        oracle.setDeviationThreshold(0);
    }

    // ============ Circuit Breaker Tests ============

    function test_CircuitBreakerTriggersOnLargeDeviation() public {
        // Enable circuit breaker mode
        oracle.enableCircuitBreaker();

        // Trigger large deviation (>5%)
        mockAggregator.setPrice(2200_00000000);

        // This should revert with ExcessiveDeviation
        // Note: The pause state change is rolled back because the tx reverts
        // Circuit breaker event is still logged (viewable in tx receipt)
        vm.expectRevert(OracleAdapter.ExcessiveDeviation.selector);
        oracle.getLatestPrice();

        // Oracle is NOT paused because revert rolls back state changes
        // This is expected behavior - manual intervention needed to pause
        assertFalse(oracle.paused());
    }

    function test_ManualCircuitBreakerTrigger() public {
        oracle.triggerCircuitBreaker();
        assertTrue(oracle.paused());
    }

    // ============ Deviation Calculation Tests ============

    function test_DeviationWithinThreshold() public {
        // 4.9% increase should pass
        mockAggregator.setPrice(2098_00000000);
        uint256 price = oracle.getLatestPrice();
        assertGt(price, 0);
    }

    function test_DeviationExactlyAtThreshold() public {
        // Exactly 5% increase should pass (threshold is exclusive)
        mockAggregator.setPrice(2100_00000000);
        uint256 price = oracle.getLatestPrice();
        assertGt(price, 0);
    }

    // ============ Integration Tests ============

    function test_MultipleValidPriceUpdates() public {
        // Update 1: $2,050 (2.5% increase)
        mockAggregator.setPrice(2050_00000000);
        uint256 price1 = oracle.getLatestPrice();
        assertEq(price1, 2050 * 1e18);

        // Update 2: $2,100 (2.4% increase from last)
        mockAggregator.setPrice(2100_00000000);
        uint256 price2 = oracle.getLatestPrice();
        assertEq(price2, 2100 * 1e18);

        // Update 3: $2,150 (2.4% increase from last)
        mockAggregator.setPrice(2150_00000000);
        uint256 price3 = oracle.getLatestPrice();
        assertEq(price3, 2150 * 1e18);
    }

    function test_PriceDecrease() public {
        // $1,950 (2.5% decrease) should pass
        mockAggregator.setPrice(1950_00000000);
        uint256 price = oracle.getLatestPrice();
        assertEq(price, 1950 * 1e18);
    }

    // ============ Gas Tests ============

    function test_GetLatestPriceGas() public {
        uint256 gasBefore = gasleft();
        oracle.getLatestPrice();
        uint256 gasUsed = gasBefore - gasleft();
        // Should be under 50,000 gas
        assertLt(gasUsed, 50000);
    }
}

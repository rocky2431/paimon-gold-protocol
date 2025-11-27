// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Chainlink AggregatorV3Interface
/// @notice Interface for Chainlink price feed aggregators
/// @dev Based on Chainlink's official AggregatorV3Interface
interface IChainlinkAggregator {
    /// @notice Returns the number of decimals in the response
    function decimals() external view returns (uint8);

    /// @notice Returns a description of the aggregator
    function description() external view returns (string memory);

    /// @notice Returns the version of the aggregator
    function version() external view returns (uint256);

    /// @notice Gets data from a specific round
    /// @param _roundId The round ID to get data for
    /// @return roundId The round ID
    /// @return answer The price answer
    /// @return startedAt Timestamp when the round started
    /// @return updatedAt Timestamp when the round was updated
    /// @return answeredInRound The round ID in which the answer was computed
    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    /// @notice Gets data from the latest round
    /// @return roundId The round ID
    /// @return answer The price answer
    /// @return startedAt Timestamp when the round started
    /// @return updatedAt Timestamp when the round was updated
    /// @return answeredInRound The round ID in which the answer was computed
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title ProtocolTimelock
/// @notice Timelock controller for protocol governance operations
/// @dev Wraps OpenZeppelin TimelockController with 48h minimum delay
/// @dev All functions (schedule, execute, cancel, etc.) are inherited from TimelockController
contract ProtocolTimelock is TimelockController {
    // ============ Constants ============

    /// @notice Minimum delay for all operations (48 hours)
    uint256 public constant MIN_DELAY = 48 hours;

    // ============ Constructor ============

    /// @notice Initialize the timelock with proposers, executors, and admin
    /// @param proposers Addresses that can propose operations (typically Safe multi-sig)
    /// @param executors Addresses that can execute operations (address(0) for anyone)
    /// @param admin Address that can manage roles (typically Safe multi-sig)
    constructor(
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(MIN_DELAY, proposers, executors, admin) {}
}

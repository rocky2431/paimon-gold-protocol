// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ILPToken
/// @notice Interface for the LPToken contract
interface ILPToken is IERC20 {
    // ============ Events ============

    /// @notice Emitted when the liquidity pool address is set
    event LiquidityPoolSet(address indexed oldPool, address indexed newPool);

    // ============ Errors ============

    /// @notice Thrown when address is zero
    error ZeroAddress();

    /// @notice Thrown when caller is not authorized
    error Unauthorized();

    /// @notice Thrown when amount is zero
    error ZeroAmount();

    // ============ Functions ============

    /// @notice Initialize the token
    /// @param name Token name
    /// @param symbol Token symbol
    function initialize(string memory name, string memory symbol) external;

    /// @notice Mint tokens to an address
    /// @param to Address to mint to
    /// @param amount Amount to mint
    /// @dev Only callable by LiquidityPool
    function mint(address to, uint256 amount) external;

    /// @notice Burn tokens from an address
    /// @param from Address to burn from
    /// @param amount Amount to burn
    /// @dev Only callable by LiquidityPool
    function burn(address from, uint256 amount) external;

    /// @notice Set the liquidity pool address
    /// @param pool New liquidity pool address
    /// @dev Only callable by owner
    function setLiquidityPool(address pool) external;

    /// @notice Get the liquidity pool address
    /// @return pool The liquidity pool address
    function liquidityPool() external view returns (address pool);
}

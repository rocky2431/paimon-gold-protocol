// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ILPToken} from "./interfaces/ILPToken.sol";

/// @title LPToken
/// @notice UUPS upgradeable ERC20 token representing liquidity provider shares
/// @dev Mint/burn restricted to LiquidityPool contract
contract LPToken is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ILPToken
{
    // ============ State Variables ============

    /// @notice Address of the liquidity pool contract
    address private _liquidityPool;

    // ============ Constructor ============

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ============ Initializer ============

    /// @inheritdoc ILPToken
    function initialize(string memory name, string memory symbol) external initializer {
        __ERC20_init(name, symbol);
        __Ownable_init(msg.sender);
    }

    // ============ External Functions ============

    /// @inheritdoc ILPToken
    function mint(address to, uint256 amount) external {
        if (msg.sender != _liquidityPool) revert Unauthorized();
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        _mint(to, amount);
    }

    /// @inheritdoc ILPToken
    function burn(address from, uint256 amount) external {
        if (msg.sender != _liquidityPool) revert Unauthorized();
        if (from == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        _burn(from, amount);
    }

    /// @inheritdoc ILPToken
    function setLiquidityPool(address pool) external onlyOwner {
        if (pool == address(0)) revert ZeroAddress();

        address oldPool = _liquidityPool;
        _liquidityPool = pool;

        emit LiquidityPoolSet(oldPool, pool);
    }

    // ============ View Functions ============

    /// @inheritdoc ILPToken
    function liquidityPool() external view returns (address pool) {
        return _liquidityPool;
    }

    // ============ Internal Functions ============

    /// @notice Authorize upgrade to new implementation
    /// @param newImplementation Address of new implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

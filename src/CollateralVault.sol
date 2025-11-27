// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title CollateralVault
/// @notice Secure custody of user collateral for leverage trading
/// @dev Supports multiple stablecoins (USDT, USDC, BUSD) and native BNB
contract CollateralVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Errors ============

    /// @notice Thrown when deposit/withdraw amount is zero
    error InvalidAmount();

    /// @notice Thrown when token is not whitelisted
    error TokenNotWhitelisted();

    /// @notice Thrown when user has insufficient balance
    error InsufficientBalance();

    /// @notice Thrown when BNB transfer fails
    error TransferFailed();

    // ============ Events ============

    /// @notice Emitted when user deposits tokens
    event Deposited(address indexed user, address indexed token, uint256 amount);

    /// @notice Emitted when user withdraws tokens
    event Withdrawn(address indexed user, address indexed token, uint256 amount);

    /// @notice Emitted when token whitelist status changes
    event TokenWhitelisted(address indexed token, bool status);

    // ============ State Variables ============

    /// @notice Mapping of whitelisted tokens
    mapping(address => bool) private _whitelisted;

    /// @notice User balances: user => token => amount
    mapping(address => mapping(address => uint256)) private _balances;

    /// @notice Total deposited per token
    mapping(address => uint256) private _totalDeposited;

    // ============ Constructor ============

    constructor() Ownable(msg.sender) {}

    // ============ External Functions ============

    /// @notice Deposit ERC20 tokens as collateral
    /// @param token The token address to deposit
    /// @param amount The amount to deposit
    function deposit(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (!_whitelisted[token]) revert TokenNotWhitelisted();

        _balances[msg.sender][token] += amount;
        _totalDeposited[token] += amount;

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(msg.sender, token, amount);
    }

    /// @notice Deposit native BNB as collateral
    function depositBNB() external payable nonReentrant {
        if (msg.value == 0) revert InvalidAmount();

        _balances[msg.sender][address(0)] += msg.value;
        _totalDeposited[address(0)] += msg.value;

        emit Deposited(msg.sender, address(0), msg.value);
    }

    /// @notice Withdraw ERC20 tokens from collateral
    /// @param token The token address to withdraw
    /// @param amount The amount to withdraw
    function withdraw(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (_balances[msg.sender][token] < amount) revert InsufficientBalance();

        _balances[msg.sender][token] -= amount;
        _totalDeposited[token] -= amount;

        IERC20(token).safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, token, amount);
    }

    /// @notice Withdraw native BNB from collateral
    /// @param amount The amount to withdraw
    function withdrawBNB(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (_balances[msg.sender][address(0)] < amount) revert InsufficientBalance();

        _balances[msg.sender][address(0)] -= amount;
        _totalDeposited[address(0)] -= amount;

        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Withdrawn(msg.sender, address(0), amount);
    }

    /// @notice Set token whitelist status
    /// @param token The token address
    /// @param status True to whitelist, false to remove
    function setTokenWhitelist(address token, bool status) external onlyOwner {
        _whitelisted[token] = status;
        emit TokenWhitelisted(token, status);
    }

    // ============ View Functions ============

    /// @notice Get user balance for a specific token
    /// @param user The user address
    /// @param token The token address (address(0) for BNB)
    /// @return The user's balance
    function balanceOf(address user, address token) external view returns (uint256) {
        return _balances[user][token];
    }

    /// @notice Get total deposited for a specific token
    /// @param token The token address (address(0) for BNB)
    /// @return The total deposited amount
    function totalDeposited(address token) external view returns (uint256) {
        return _totalDeposited[token];
    }

    /// @notice Check if a token is whitelisted
    /// @param token The token address
    /// @return True if whitelisted
    function isWhitelisted(address token) external view returns (bool) {
        return _whitelisted[token];
    }

    // ============ Receive Function ============

    /// @notice Allow contract to receive BNB
    receive() external payable {}
}

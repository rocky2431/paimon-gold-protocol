// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPositionManager} from "./interfaces/IPositionManager.sol";
import {OracleAdapter} from "./OracleAdapter.sol";
import {CollateralVault} from "./CollateralVault.sol";

/// @title PositionManager
/// @notice Manages leveraged gold trading positions
/// @dev Core contract for position lifecycle management
contract PositionManager is IPositionManager, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Constants ============

    /// @notice Minimum leverage multiplier
    uint256 public constant MIN_LEVERAGE = 2;

    /// @notice Maximum leverage multiplier
    uint256 public constant MAX_LEVERAGE = 20;

    /// @notice Minimum position size in USD (18 decimals) - $10
    uint256 public constant MIN_POSITION_SIZE = 10 * 1e18;

    /// @notice Minimum blocks before position can be closed (flash loan protection)
    uint256 public constant MIN_HOLD_BLOCKS = 10;

    /// @notice Precision for calculations (18 decimals)
    uint256 private constant PRECISION = 1e18;

    // ============ State Variables ============

    /// @notice Oracle adapter for price feeds
    OracleAdapter public immutable oracle;

    /// @notice Collateral vault for custody
    CollateralVault public immutable vault;

    /// @notice Counter for position IDs
    uint256 private _nextPositionId;

    /// @notice Mapping of position ID to Position data
    mapping(uint256 => Position) private _positions;

    /// @notice Mapping of owner to their position IDs
    mapping(address => uint256[]) private _ownerPositions;

    /// @notice Mapping to track if position exists
    mapping(uint256 => bool) private _positionExists;

    // ============ Constructor ============

    constructor(address _oracle, address _vault) Ownable(msg.sender) {
        oracle = OracleAdapter(_oracle);
        vault = CollateralVault(payable(_vault));
        _nextPositionId = 1;
    }

    // ============ External Functions ============

    /// @inheritdoc IPositionManager
    function openPosition(
        address collateralToken,
        uint256 collateralAmount,
        uint256 leverage,
        bool isLong
    ) external nonReentrant whenNotPaused returns (uint256 positionId) {
        // Validate leverage
        if (leverage < MIN_LEVERAGE || leverage > MAX_LEVERAGE) {
            revert InvalidLeverage();
        }

        // Calculate position size
        uint256 size = collateralAmount * leverage;

        // Validate minimum position size
        if (size < MIN_POSITION_SIZE) {
            revert PositionTooSmall();
        }

        // Get current price from oracle
        uint256 entryPrice = oracle.getLatestPrice();

        // Transfer collateral from user
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);

        // Create position
        positionId = _nextPositionId++;

        _positions[positionId] = Position({
            id: positionId,
            owner: msg.sender,
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            size: size,
            entryPrice: entryPrice,
            leverage: leverage,
            isLong: isLong,
            openedAt: block.timestamp,
            openBlock: block.number
        });

        _positionExists[positionId] = true;
        _ownerPositions[msg.sender].push(positionId);

        emit PositionOpened(
            positionId,
            msg.sender,
            collateralToken,
            collateralAmount,
            size,
            entryPrice,
            leverage,
            isLong
        );
    }

    /// @inheritdoc IPositionManager
    function closePosition(
        uint256 positionId,
        uint256 closeAmount
    ) external nonReentrant whenNotPaused returns (uint256 payout) {
        // Validate position exists
        if (!_positionExists[positionId]) {
            revert PositionNotFound();
        }

        Position storage pos = _positions[positionId];

        // Validate ownership
        if (pos.owner != msg.sender) {
            revert NotPositionOwner();
        }

        // Flash loan protection
        if (block.number <= pos.openBlock + MIN_HOLD_BLOCKS) {
            revert PositionTooNew();
        }

        // Handle full close with max uint
        if (closeAmount == type(uint256).max) {
            closeAmount = pos.size;
        }

        // Validate close amount
        if (closeAmount > pos.size) {
            revert InvalidCloseAmount();
        }

        // Calculate the proportion being closed
        uint256 closeProportion = (closeAmount * PRECISION) / pos.size;
        uint256 collateralToReturn = (pos.collateralAmount * closeProportion) / PRECISION;

        // Get current price
        uint256 exitPrice = oracle.getLatestPrice();

        // Calculate PnL
        int256 pnl = _calculatePnL(
            pos.size,
            pos.entryPrice,
            exitPrice,
            pos.isLong,
            closeProportion
        );

        // Calculate payout
        if (pnl >= 0) {
            payout = collateralToReturn + uint256(pnl);
        } else {
            uint256 loss = uint256(-pnl);
            if (loss >= collateralToReturn) {
                payout = 0; // Liquidation scenario
            } else {
                payout = collateralToReturn - loss;
            }
        }

        // Update or delete position
        if (closeAmount == pos.size) {
            // Full close - delete position
            _positionExists[positionId] = false;
            _removePositionFromOwner(msg.sender, positionId);

            emit PositionClosed(positionId, msg.sender, exitPrice, pnl, payout);
        } else {
            // Partial close - update position
            pos.size -= closeAmount;
            pos.collateralAmount -= collateralToReturn;

            emit PositionPartialClosed(positionId, closeAmount, pos.size, pnl, payout);
        }

        // Transfer payout to user
        if (payout > 0) {
            IERC20(pos.collateralToken).safeTransfer(msg.sender, payout);
        }
    }

    // ============ View Functions ============

    /// @inheritdoc IPositionManager
    function getPosition(uint256 positionId) external view returns (Position memory position) {
        if (!_positionExists[positionId]) {
            revert PositionNotFound();
        }
        return _positions[positionId];
    }

    /// @inheritdoc IPositionManager
    function getPositionsByOwner(address owner) external view returns (uint256[] memory positionIds) {
        return _ownerPositions[owner];
    }

    /// @inheritdoc IPositionManager
    function calculatePnL(uint256 positionId) external view returns (int256 pnl) {
        if (!_positionExists[positionId]) {
            revert PositionNotFound();
        }

        Position storage pos = _positions[positionId];
        uint256 currentPrice = oracle.getLatestPriceView();

        return _calculatePnL(pos.size, pos.entryPrice, currentPrice, pos.isLong, PRECISION);
    }

    /// @inheritdoc IPositionManager
    function getHealthFactor(uint256 positionId) external view returns (uint256 healthFactor) {
        if (!_positionExists[positionId]) {
            revert PositionNotFound();
        }

        Position storage pos = _positions[positionId];
        uint256 currentPrice = oracle.getLatestPriceView();

        int256 pnl = _calculatePnL(pos.size, pos.entryPrice, currentPrice, pos.isLong, PRECISION);

        // Effective collateral = collateral + PnL
        int256 effectiveCollateral = int256(pos.collateralAmount) + pnl;

        if (effectiveCollateral <= 0) {
            return 0;
        }

        // Health factor = effectiveCollateral / initialCollateral
        // At opening: HF = collateral / collateral = 1
        healthFactor = (uint256(effectiveCollateral) * PRECISION) / pos.collateralAmount;
    }

    // ============ Admin Functions ============

    /// @notice Pause the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the contract
    function unpause() external onlyOwner {
        _unpause();
    }

    // ============ Internal Functions ============

    /// @notice Calculate PnL for a position
    /// @param size Position size
    /// @param entryPrice Entry price
    /// @param exitPrice Exit/current price
    /// @param isLong True for long, false for short
    /// @param proportion Proportion of position (PRECISION = 100%)
    /// @return pnl The PnL amount (can be negative)
    function _calculatePnL(
        uint256 size,
        uint256 entryPrice,
        uint256 exitPrice,
        bool isLong,
        uint256 proportion
    ) internal pure returns (int256 pnl) {
        // Apply proportion to size
        uint256 effectiveSize = (size * proportion) / PRECISION;

        if (isLong) {
            // Long: profit when price goes up
            // PnL = size * (exitPrice - entryPrice) / entryPrice
            if (exitPrice >= entryPrice) {
                uint256 gain = (effectiveSize * (exitPrice - entryPrice)) / entryPrice;
                pnl = int256(gain);
            } else {
                uint256 loss = (effectiveSize * (entryPrice - exitPrice)) / entryPrice;
                pnl = -int256(loss);
            }
        } else {
            // Short: profit when price goes down
            // PnL = size * (entryPrice - exitPrice) / entryPrice
            if (exitPrice <= entryPrice) {
                uint256 gain = (effectiveSize * (entryPrice - exitPrice)) / entryPrice;
                pnl = int256(gain);
            } else {
                uint256 loss = (effectiveSize * (exitPrice - entryPrice)) / entryPrice;
                pnl = -int256(loss);
            }
        }
    }

    /// @notice Remove a position ID from owner's array
    /// @param owner The owner address
    /// @param positionId The position ID to remove
    function _removePositionFromOwner(address owner, uint256 positionId) internal {
        uint256[] storage positions = _ownerPositions[owner];
        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i] == positionId) {
                positions[i] = positions[positions.length - 1];
                positions.pop();
                break;
            }
        }
    }
}

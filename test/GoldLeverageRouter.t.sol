// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {GoldLeverageRouter} from "../src/GoldLeverageRouter.sol";
import {IGoldLeverageRouter} from "../src/interfaces/IGoldLeverageRouter.sol";
import {IPositionManager} from "../src/interfaces/IPositionManager.sol";
import {ILiquidityPool} from "../src/interfaces/ILiquidityPool.sol";

/// @notice Mock ERC20 token for testing
contract MockERC20 is ERC20 {
    uint8 private _decimals;

    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        _decimals = decimals_;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}

/// @notice Mock PositionManager for testing routing
/// @dev Uses tx.origin to simulate router pattern where user identity is preserved
contract MockPositionManager {
    uint256 private _nextPositionId = 1;
    mapping(uint256 => IPositionManager.Position) private _positions;
    mapping(address => uint256[]) private _userPositions;

    function openPosition(
        address collateralToken,
        uint256 collateralAmount,
        uint256 leverage,
        bool isLong
    ) external returns (uint256 positionId) {
        // Use tx.origin to simulate proper user tracking through router
        address user = tx.origin;
        positionId = _nextPositionId++;
        _positions[positionId] = IPositionManager.Position({
            id: positionId,
            owner: user,
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            size: collateralAmount * leverage,
            entryPrice: 2500e18, // Mock price
            leverage: leverage,
            isLong: isLong,
            openedAt: block.timestamp,
            openBlock: block.number
        });
        _userPositions[user].push(positionId);
    }

    function closePosition(uint256 positionId, uint256) external returns (uint256 payout) {
        require(_positions[positionId].owner == tx.origin, "Not owner");
        payout = _positions[positionId].collateralAmount;
        delete _positions[positionId];
    }

    function addMargin(uint256 positionId, uint256 amount) external {
        require(_positions[positionId].owner == tx.origin, "Not owner");
        _positions[positionId].collateralAmount += amount;
    }

    function removeMargin(uint256 positionId, uint256 amount) external {
        require(_positions[positionId].owner == tx.origin, "Not owner");
        _positions[positionId].collateralAmount -= amount;
    }

    function getPosition(uint256 positionId) external view returns (IPositionManager.Position memory) {
        return _positions[positionId];
    }

    function getPositionsByOwner(address owner) external view returns (uint256[] memory) {
        return _userPositions[owner];
    }

    function calculatePnL(uint256) external pure returns (int256) {
        return 100e18; // Mock PnL
    }

    function getHealthFactor(uint256) external pure returns (uint256) {
        return 2e18; // Mock health factor
    }
}

/// @notice Mock LiquidityPool for testing routing
/// @dev Uses tx.origin to simulate router pattern where user identity is preserved
contract MockLiquidityPool {
    mapping(address => ILiquidityPool.UserInfo) private _userInfo;
    uint256 private _totalValue = 1_000_000e6;

    function addLiquidity(address, uint256 amount) external returns (uint256 lpAmount) {
        address user = tx.origin;
        lpAmount = amount * 1e12; // Scale 6 to 18 decimals
        _userInfo[user].lpBalance += lpAmount;
        _userInfo[user].depositTime = block.timestamp;
    }

    function removeLiquidity(uint256 lpAmount) external returns (uint256 assetAmount, uint256 feeReward) {
        address user = tx.origin;
        require(_userInfo[user].lpBalance >= lpAmount, "Insufficient balance");
        _userInfo[user].lpBalance -= lpAmount;
        assetAmount = lpAmount / 1e12;
        feeReward = 100e6; // Mock fee reward
    }

    function claimFees() external returns (uint256 feeAmount) {
        feeAmount = 50e6; // Mock fee claim
    }

    function pendingFees(address) external pure returns (uint256) {
        return 50e6;
    }

    function getUserInfo(address user) external view returns (ILiquidityPool.UserInfo memory) {
        return _userInfo[user];
    }

    function getTotalPoolValue() external view returns (uint256) {
        return _totalValue;
    }
}

/// @notice Mock CollateralVault
contract MockCollateralVault {
    mapping(address => mapping(address => uint256)) private _balances;

    function deposit(address token, uint256 amount) external {
        _balances[msg.sender][token] += amount;
    }

    function withdraw(address token, uint256 amount) external {
        require(_balances[msg.sender][token] >= amount, "Insufficient balance");
        _balances[msg.sender][token] -= amount;
    }

    function getBalance(address user, address token) external view returns (uint256) {
        return _balances[user][token];
    }
}

contract GoldLeverageRouterTest is Test {
    GoldLeverageRouter public router;
    GoldLeverageRouter public routerImpl;
    MockPositionManager public positionManager;
    MockLiquidityPool public liquidityPool;
    MockCollateralVault public collateralVault;
    MockERC20 public usdc;

    address public owner = address(this);
    address public admin = makeAddr("admin");
    address public pauser = makeAddr("pauser");
    address public keeper = makeAddr("keeper");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    function setUp() public {
        // Deploy mock tokens
        usdc = new MockERC20("USD Coin", "USDC", 6);

        // Deploy mock contracts
        positionManager = new MockPositionManager();
        liquidityPool = new MockLiquidityPool();
        collateralVault = new MockCollateralVault();

        // Deploy router with proxy
        routerImpl = new GoldLeverageRouter();
        bytes memory initData = abi.encodeWithSelector(
            GoldLeverageRouter.initialize.selector,
            address(positionManager),
            address(liquidityPool),
            address(collateralVault)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(routerImpl), initData);
        router = GoldLeverageRouter(address(proxy));

        // Setup roles
        router.grantRole(ADMIN_ROLE, admin);
        router.grantRole(PAUSER_ROLE, pauser);
        router.grantRole(KEEPER_ROLE, keeper);

        // Mint tokens to users
        usdc.mint(user1, 100_000e6);
        usdc.mint(user2, 100_000e6);

        // Approve router
        vm.prank(user1);
        usdc.approve(address(router), type(uint256).max);
        vm.prank(user2);
        usdc.approve(address(router), type(uint256).max);
    }

    // ============ Initialization Tests ============

    function test_Initialize_SetsPositionManager() public view {
        assertEq(router.positionManager(), address(positionManager));
    }

    function test_Initialize_SetsLiquidityPool() public view {
        assertEq(router.liquidityPool(), address(liquidityPool));
    }

    function test_Initialize_SetsCollateralVault() public view {
        assertEq(router.collateralVault(), address(collateralVault));
    }

    function test_Initialize_GrantsDefaultAdminRole() public view {
        assertTrue(router.hasRole(DEFAULT_ADMIN_ROLE, owner));
    }

    function test_Initialize_RevertIf_ZeroPositionManager() public {
        GoldLeverageRouter newRouterImpl = new GoldLeverageRouter();
        bytes memory initData = abi.encodeWithSelector(
            GoldLeverageRouter.initialize.selector,
            address(0),
            address(liquidityPool),
            address(collateralVault)
        );
        vm.expectRevert(IGoldLeverageRouter.ZeroAddress.selector);
        new ERC1967Proxy(address(newRouterImpl), initData);
    }

    function test_Initialize_RevertIf_ZeroLiquidityPool() public {
        GoldLeverageRouter newRouterImpl = new GoldLeverageRouter();
        bytes memory initData = abi.encodeWithSelector(
            GoldLeverageRouter.initialize.selector,
            address(positionManager),
            address(0),
            address(collateralVault)
        );
        vm.expectRevert(IGoldLeverageRouter.ZeroAddress.selector);
        new ERC1967Proxy(address(newRouterImpl), initData);
    }

    function test_Initialize_RevertIf_ZeroCollateralVault() public {
        GoldLeverageRouter newRouterImpl = new GoldLeverageRouter();
        bytes memory initData = abi.encodeWithSelector(
            GoldLeverageRouter.initialize.selector,
            address(positionManager),
            address(liquidityPool),
            address(0)
        );
        vm.expectRevert(IGoldLeverageRouter.ZeroAddress.selector);
        new ERC1967Proxy(address(newRouterImpl), initData);
    }

    // ============ Trading Function Tests ============

    function test_OpenPosition_Success() public {
        vm.prank(user1);
        uint256 positionId = router.openPosition(address(usdc), 1000e6, 5, true);

        assertEq(positionId, 1);
    }

    function test_OpenPosition_CreatesCorrectPosition() public {
        vm.prank(user1);
        uint256 positionId = router.openPosition(address(usdc), 1000e6, 10, true);

        IPositionManager.Position memory pos = router.getPosition(positionId);
        assertEq(pos.collateralAmount, 1000e6);
        assertEq(pos.leverage, 10);
        assertTrue(pos.isLong);
    }

    function test_OpenPosition_RevertIf_Paused() public {
        vm.prank(pauser);
        router.pause();

        vm.prank(user1);
        vm.expectRevert();
        router.openPosition(address(usdc), 1000e6, 5, true);
    }

    function test_OpenPosition_RevertIf_ZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(IGoldLeverageRouter.ZeroAmount.selector);
        router.openPosition(address(usdc), 0, 5, true);
    }

    function test_ClosePosition_Success() public {
        vm.startPrank(user1);
        uint256 positionId = router.openPosition(address(usdc), 1000e6, 5, true);
        uint256 payout = router.closePosition(positionId, type(uint256).max);
        vm.stopPrank();

        assertGt(payout, 0);
    }

    function test_ClosePosition_RevertIf_Paused() public {
        vm.prank(user1);
        uint256 positionId = router.openPosition(address(usdc), 1000e6, 5, true);

        vm.prank(pauser);
        router.pause();

        vm.prank(user1);
        vm.expectRevert();
        router.closePosition(positionId, type(uint256).max);
    }

    function test_AddMargin_Success() public {
        vm.startPrank(user1);
        uint256 positionId = router.openPosition(address(usdc), 1000e6, 5, true);
        router.addMargin(positionId, 500e6);
        vm.stopPrank();

        IPositionManager.Position memory pos = router.getPosition(positionId);
        assertEq(pos.collateralAmount, 1500e6);
    }

    function test_AddMargin_RevertIf_ZeroAmount() public {
        vm.startPrank(user1);
        uint256 positionId = router.openPosition(address(usdc), 1000e6, 5, true);
        vm.expectRevert(IGoldLeverageRouter.ZeroAmount.selector);
        router.addMargin(positionId, 0);
        vm.stopPrank();
    }

    function test_RemoveMargin_Success() public {
        vm.startPrank(user1);
        uint256 positionId = router.openPosition(address(usdc), 1000e6, 5, true);
        router.removeMargin(positionId, 200e6);
        vm.stopPrank();

        IPositionManager.Position memory pos = router.getPosition(positionId);
        assertEq(pos.collateralAmount, 800e6);
    }

    function test_RemoveMargin_RevertIf_ZeroAmount() public {
        vm.startPrank(user1);
        uint256 positionId = router.openPosition(address(usdc), 1000e6, 5, true);
        vm.expectRevert(IGoldLeverageRouter.ZeroAmount.selector);
        router.removeMargin(positionId, 0);
        vm.stopPrank();
    }

    // ============ LP Function Tests ============

    function test_AddLiquidity_Success() public {
        vm.prank(user1);
        uint256 lpAmount = router.addLiquidity(address(usdc), 10_000e6);

        assertEq(lpAmount, 10_000e6 * 1e12);
    }

    function test_AddLiquidity_RevertIf_Paused() public {
        vm.prank(pauser);
        router.pause();

        vm.prank(user1);
        vm.expectRevert();
        router.addLiquidity(address(usdc), 10_000e6);
    }

    function test_AddLiquidity_RevertIf_ZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(IGoldLeverageRouter.ZeroAmount.selector);
        router.addLiquidity(address(usdc), 0);
    }

    function test_RemoveLiquidity_Success() public {
        vm.startPrank(user1);
        uint256 lpAmount = router.addLiquidity(address(usdc), 10_000e6);
        (uint256 assetAmount, uint256 feeReward) = router.removeLiquidity(lpAmount);
        vm.stopPrank();

        assertEq(assetAmount, 10_000e6);
        assertGt(feeReward, 0);
    }

    function test_RemoveLiquidity_RevertIf_Paused() public {
        vm.prank(user1);
        uint256 lpAmount = router.addLiquidity(address(usdc), 10_000e6);

        vm.prank(pauser);
        router.pause();

        vm.prank(user1);
        vm.expectRevert();
        router.removeLiquidity(lpAmount);
    }

    function test_RemoveLiquidity_RevertIf_ZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(IGoldLeverageRouter.ZeroAmount.selector);
        router.removeLiquidity(0);
    }

    function test_ClaimFees_Success() public {
        vm.startPrank(user1);
        router.addLiquidity(address(usdc), 10_000e6);
        uint256 feeAmount = router.claimFees();
        vm.stopPrank();

        assertGt(feeAmount, 0);
    }

    function test_ClaimFees_RevertIf_Paused() public {
        vm.prank(user1);
        router.addLiquidity(address(usdc), 10_000e6);

        vm.prank(pauser);
        router.pause();

        vm.prank(user1);
        vm.expectRevert();
        router.claimFees();
    }

    // ============ View Function Tests ============

    function test_GetPosition_ReturnsCorrectData() public {
        vm.prank(user1);
        uint256 positionId = router.openPosition(address(usdc), 1000e6, 5, true);

        IPositionManager.Position memory pos = router.getPosition(positionId);
        assertEq(pos.id, positionId);
        assertEq(pos.collateralAmount, 1000e6);
    }

    function test_GetUserPositions_ReturnsAllPositions() public {
        vm.startPrank(user1, user1); // Set both msg.sender and tx.origin
        router.openPosition(address(usdc), 1000e6, 5, true);
        router.openPosition(address(usdc), 2000e6, 10, false);
        vm.stopPrank();

        uint256[] memory positions = router.getUserPositions(user1);
        assertEq(positions.length, 2);
    }

    function test_GetHealthFactor_ReturnsValue() public {
        vm.prank(user1);
        uint256 positionId = router.openPosition(address(usdc), 1000e6, 5, true);

        uint256 healthFactor = router.getHealthFactor(positionId);
        assertEq(healthFactor, 2e18);
    }

    function test_CalculatePnL_ReturnsValue() public {
        vm.prank(user1);
        uint256 positionId = router.openPosition(address(usdc), 1000e6, 5, true);

        int256 pnl = router.calculatePnL(positionId);
        assertEq(pnl, 100e18);
    }

    function test_GetPendingFees_ReturnsValue() public {
        uint256 pending = router.getPendingFees(user1);
        assertEq(pending, 50e6);
    }

    function test_GetUserLPInfo_ReturnsCorrectData() public {
        vm.prank(user1, user1); // Set both msg.sender and tx.origin
        router.addLiquidity(address(usdc), 10_000e6);

        ILiquidityPool.UserInfo memory info = router.getUserLPInfo(user1);
        assertEq(info.lpBalance, 10_000e6 * 1e12);
    }

    function test_GetPoolTVL_ReturnsValue() public view {
        uint256 tvl = router.getPoolTVL();
        assertEq(tvl, 1_000_000e6);
    }

    // ============ Admin Function Tests ============

    function test_SetPositionManager_Success() public {
        address newManager = makeAddr("newManager");

        vm.expectEmit(true, true, false, false);
        emit IGoldLeverageRouter.PositionManagerSet(address(positionManager), newManager);

        vm.prank(admin);
        router.setPositionManager(newManager);

        assertEq(router.positionManager(), newManager);
    }

    function test_SetPositionManager_RevertIf_NotAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        router.setPositionManager(makeAddr("newManager"));
    }

    function test_SetPositionManager_RevertIf_ZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(IGoldLeverageRouter.ZeroAddress.selector);
        router.setPositionManager(address(0));
    }

    function test_SetLiquidityPool_Success() public {
        address newPool = makeAddr("newPool");

        vm.expectEmit(true, true, false, false);
        emit IGoldLeverageRouter.LiquidityPoolSet(address(liquidityPool), newPool);

        vm.prank(admin);
        router.setLiquidityPool(newPool);

        assertEq(router.liquidityPool(), newPool);
    }

    function test_SetLiquidityPool_RevertIf_NotAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        router.setLiquidityPool(makeAddr("newPool"));
    }

    function test_SetCollateralVault_Success() public {
        address newVault = makeAddr("newVault");

        vm.expectEmit(true, true, false, false);
        emit IGoldLeverageRouter.CollateralVaultSet(address(collateralVault), newVault);

        vm.prank(admin);
        router.setCollateralVault(newVault);

        assertEq(router.collateralVault(), newVault);
    }

    function test_SetCollateralVault_RevertIf_NotAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        router.setCollateralVault(makeAddr("newVault"));
    }

    // ============ Pause Function Tests ============

    function test_Pause_Success() public {
        vm.expectEmit(true, false, false, true);
        emit IGoldLeverageRouter.EmergencyPause(pauser, block.timestamp);

        vm.prank(pauser);
        router.pause();

        assertTrue(router.paused());
    }

    function test_Pause_RevertIf_NotPauser() public {
        vm.prank(user1);
        vm.expectRevert();
        router.pause();
    }

    function test_Unpause_Success() public {
        vm.prank(pauser);
        router.pause();

        vm.expectEmit(true, false, false, true);
        emit IGoldLeverageRouter.EmergencyUnpause(admin, block.timestamp);

        vm.prank(admin);
        router.unpause();

        assertFalse(router.paused());
    }

    function test_Unpause_RevertIf_NotAdmin() public {
        vm.prank(pauser);
        router.pause();

        vm.prank(pauser);
        vm.expectRevert();
        router.unpause();
    }

    // ============ Access Control Tests ============

    function test_OnlyAdminCanGrantRoles() public {
        address newPauser = makeAddr("newPauser");

        router.grantRole(PAUSER_ROLE, newPauser);
        assertTrue(router.hasRole(PAUSER_ROLE, newPauser));
    }

    function test_NonAdminCannotGrantRoles() public {
        address newPauser = makeAddr("newPauser");

        vm.prank(user1);
        vm.expectRevert();
        router.grantRole(PAUSER_ROLE, newPauser);
    }

    function test_AdminCanRevokeRoles() public {
        router.revokeRole(PAUSER_ROLE, pauser);
        assertFalse(router.hasRole(PAUSER_ROLE, pauser));
    }

    // ============ Upgrade Tests ============

    function test_Upgrade_OnlyUpgrader() public {
        GoldLeverageRouter newImpl = new GoldLeverageRouter();

        router.grantRole(UPGRADER_ROLE, admin);

        vm.prank(admin);
        router.upgradeToAndCall(address(newImpl), "");
    }

    function test_Upgrade_RevertIf_NotUpgrader() public {
        GoldLeverageRouter newImpl = new GoldLeverageRouter();

        vm.prank(user1);
        vm.expectRevert();
        router.upgradeToAndCall(address(newImpl), "");
    }

    function test_Upgrade_PreservesState() public {
        // Setup initial state
        vm.prank(user1);
        router.openPosition(address(usdc), 1000e6, 5, true);

        // Upgrade
        GoldLeverageRouter newImpl = new GoldLeverageRouter();
        router.grantRole(UPGRADER_ROLE, admin);
        vm.prank(admin);
        router.upgradeToAndCall(address(newImpl), "");

        // Verify state preserved
        assertEq(router.positionManager(), address(positionManager));
        assertEq(router.liquidityPool(), address(liquidityPool));
    }

    // ============ Integration Tests ============

    function test_Integration_FullTradingFlow() public {
        vm.startPrank(user1);

        // Open position
        uint256 positionId = router.openPosition(address(usdc), 1000e6, 10, true);
        assertEq(positionId, 1);

        // Add margin
        router.addMargin(positionId, 500e6);
        IPositionManager.Position memory pos = router.getPosition(positionId);
        assertEq(pos.collateralAmount, 1500e6);

        // Remove margin
        router.removeMargin(positionId, 300e6);
        pos = router.getPosition(positionId);
        assertEq(pos.collateralAmount, 1200e6);

        // Close position
        uint256 payout = router.closePosition(positionId, type(uint256).max);
        assertGt(payout, 0);

        vm.stopPrank();
    }

    function test_Integration_FullLPFlow() public {
        vm.startPrank(user1);

        // Add liquidity
        uint256 lpAmount = router.addLiquidity(address(usdc), 10_000e6);
        assertGt(lpAmount, 0);

        // Check pending fees
        uint256 pending = router.getPendingFees(user1);
        assertGt(pending, 0);

        // Claim fees
        uint256 claimed = router.claimFees();
        assertGt(claimed, 0);

        // Remove liquidity
        (uint256 assetAmount, uint256 feeReward) = router.removeLiquidity(lpAmount);
        assertGt(assetAmount, 0);
        assertGt(feeReward, 0);

        vm.stopPrank();
    }

    function test_Integration_MultipleUsers() public {
        // User1 opens position
        vm.prank(user1, user1);
        uint256 pos1 = router.openPosition(address(usdc), 1000e6, 5, true);

        // User2 opens position
        vm.prank(user2, user2);
        uint256 pos2 = router.openPosition(address(usdc), 2000e6, 10, false);

        // User1 adds liquidity
        vm.prank(user1, user1);
        router.addLiquidity(address(usdc), 5000e6);

        // Verify separate positions
        assertEq(router.getUserPositions(user1).length, 1);
        assertEq(router.getUserPositions(user2).length, 1);
        assertEq(pos1, 1);
        assertEq(pos2, 2);
    }

    // ============ Gas Tests ============

    function test_Gas_OpenPosition() public {
        vm.prank(user1);
        uint256 gasBefore = gasleft();
        router.openPosition(address(usdc), 1000e6, 5, true);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Gas used for openPosition:", gasUsed);
        assertLt(gasUsed, 350_000); // Router adds overhead
    }

    function test_Gas_AddLiquidity() public {
        vm.prank(user1);
        uint256 gasBefore = gasleft();
        router.addLiquidity(address(usdc), 10_000e6);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Gas used for addLiquidity:", gasUsed);
        assertLt(gasUsed, 150_000);
    }

    // ============ Fuzz Tests ============

    function testFuzz_OpenPosition_AnyValidLeverage(uint256 leverage) public {
        leverage = bound(leverage, 2, 20);

        vm.prank(user1);
        uint256 positionId = router.openPosition(address(usdc), 1000e6, leverage, true);

        IPositionManager.Position memory pos = router.getPosition(positionId);
        assertEq(pos.leverage, leverage);
    }

    function testFuzz_AddLiquidity_AnyAmount(uint256 amount) public {
        amount = bound(amount, 1, 50_000e6);
        usdc.mint(user1, amount);

        vm.prank(user1);
        uint256 lpAmount = router.addLiquidity(address(usdc), amount);

        assertGt(lpAmount, 0);
    }
}

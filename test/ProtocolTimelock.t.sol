// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ProtocolTimelock} from "../src/governance/ProtocolTimelock.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @notice Mock contract for testing timelock operations
contract MockTarget {
    uint256 public value;
    bool public paused;

    event ValueSet(uint256 newValue);
    event Paused();
    event Unpaused();

    function setValue(uint256 _value) external {
        value = _value;
        emit ValueSet(_value);
    }

    function pause() external {
        paused = true;
        emit Paused();
    }

    function unpause() external {
        paused = false;
        emit Unpaused();
    }

    function revertingFunction() external pure {
        revert("Always reverts");
    }
}

/// @title ProtocolTimelockTest
/// @notice Comprehensive tests for ProtocolTimelock
contract ProtocolTimelockTest is Test {
    ProtocolTimelock public timelock;
    MockTarget public target;

    address public admin;
    address public proposer1;
    address public proposer2;
    address public proposer3;
    address public executor;
    address public user;

    uint256 public constant MIN_DELAY = 48 hours;

    function setUp() public {
        admin = makeAddr("admin");
        proposer1 = makeAddr("proposer1");
        proposer2 = makeAddr("proposer2");
        proposer3 = makeAddr("proposer3");
        executor = makeAddr("executor");
        user = makeAddr("user");

        // Setup proposers (simulating 3/5 multi-sig signers)
        address[] memory proposers = new address[](3);
        proposers[0] = proposer1;
        proposers[1] = proposer2;
        proposers[2] = proposer3;

        // Setup executors (anyone can execute after delay)
        address[] memory executors = new address[](1);
        executors[0] = address(0); // address(0) means anyone can execute

        vm.prank(admin);
        timelock = new ProtocolTimelock(proposers, executors, admin);

        target = new MockTarget();
    }

    // ============ Constructor Tests ============

    function test_Constructor_SetsMinDelay() public view {
        assertEq(timelock.getMinDelay(), MIN_DELAY);
    }

    function test_Constructor_GrantsProposerRole() public view {
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        assertTrue(timelock.hasRole(proposerRole, proposer1));
        assertTrue(timelock.hasRole(proposerRole, proposer2));
        assertTrue(timelock.hasRole(proposerRole, proposer3));
    }

    function test_Constructor_GrantsExecutorRole() public view {
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        // address(0) means anyone can execute
        assertTrue(timelock.hasRole(executorRole, address(0)));
    }

    function test_Constructor_GrantsAdminRole() public view {
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();
        assertTrue(timelock.hasRole(adminRole, admin));
    }

    // ============ Schedule Tests ============

    function test_Schedule_Success() public {
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        bytes32 salt = keccak256("test");

        vm.prank(proposer1);
        timelock.schedule(
            address(target),
            0,
            data,
            bytes32(0),
            salt,
            MIN_DELAY
        );

        bytes32 id = timelock.hashOperation(address(target), 0, data, bytes32(0), salt);
        assertTrue(timelock.isOperationPending(id));
    }

    function test_Schedule_EmitsEvent() public {
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        bytes32 salt = keccak256("test");

        bytes32 id = timelock.hashOperation(address(target), 0, data, bytes32(0), salt);

        vm.prank(proposer1);
        vm.expectEmit(true, true, true, true);
        emit TimelockController.CallScheduled(id, 0, address(target), 0, data, bytes32(0), MIN_DELAY);
        timelock.schedule(
            address(target),
            0,
            data,
            bytes32(0),
            salt,
            MIN_DELAY
        );
    }

    function test_Schedule_RevertIf_NotProposer() public {
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        bytes32 salt = keccak256("test");

        vm.prank(user);
        vm.expectRevert();
        timelock.schedule(
            address(target),
            0,
            data,
            bytes32(0),
            salt,
            MIN_DELAY
        );
    }

    function test_Schedule_RevertIf_DelayTooShort() public {
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        bytes32 salt = keccak256("test");

        vm.prank(proposer1);
        vm.expectRevert();
        timelock.schedule(
            address(target),
            0,
            data,
            bytes32(0),
            salt,
            1 hours // Less than MIN_DELAY
        );
    }

    // ============ Execute Tests ============

    function test_Execute_Success() public {
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        bytes32 salt = keccak256("test");

        // Schedule
        vm.prank(proposer1);
        timelock.schedule(
            address(target),
            0,
            data,
            bytes32(0),
            salt,
            MIN_DELAY
        );

        // Wait for delay
        vm.warp(block.timestamp + MIN_DELAY + 1);

        // Execute
        vm.prank(user);
        timelock.execute(
            address(target),
            0,
            data,
            bytes32(0),
            salt
        );

        assertEq(target.value(), 42);
    }

    function test_Execute_EmitsEvent() public {
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        bytes32 salt = keccak256("test");
        bytes32 id = timelock.hashOperation(address(target), 0, data, bytes32(0), salt);

        // Schedule
        vm.prank(proposer1);
        timelock.schedule(address(target), 0, data, bytes32(0), salt, MIN_DELAY);

        // Wait for delay
        vm.warp(block.timestamp + MIN_DELAY + 1);

        // Execute
        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit TimelockController.CallExecuted(id, 0, address(target), 0, data);
        timelock.execute(address(target), 0, data, bytes32(0), salt);
    }

    function test_Execute_RevertIf_NotReady() public {
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        bytes32 salt = keccak256("test");

        // Schedule
        vm.prank(proposer1);
        timelock.schedule(address(target), 0, data, bytes32(0), salt, MIN_DELAY);

        // Try to execute before delay (should fail)
        vm.warp(block.timestamp + MIN_DELAY - 1);

        vm.prank(user);
        vm.expectRevert();
        timelock.execute(address(target), 0, data, bytes32(0), salt);
    }

    function test_Execute_RevertIf_NotScheduled() public {
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        bytes32 salt = keccak256("test");

        vm.prank(user);
        vm.expectRevert();
        timelock.execute(address(target), 0, data, bytes32(0), salt);
    }

    function test_Execute_RevertIf_TargetReverts() public {
        bytes memory data = abi.encodeWithSelector(MockTarget.revertingFunction.selector);
        bytes32 salt = keccak256("revert");

        // Schedule
        vm.prank(proposer1);
        timelock.schedule(address(target), 0, data, bytes32(0), salt, MIN_DELAY);

        // Wait for delay
        vm.warp(block.timestamp + MIN_DELAY + 1);

        // Execute (should revert because target reverts)
        vm.prank(user);
        vm.expectRevert();
        timelock.execute(address(target), 0, data, bytes32(0), salt);
    }

    // ============ Cancel Tests ============

    function test_Cancel_Success() public {
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        bytes32 salt = keccak256("test");

        // Schedule
        vm.prank(proposer1);
        timelock.schedule(address(target), 0, data, bytes32(0), salt, MIN_DELAY);

        bytes32 id = timelock.hashOperation(address(target), 0, data, bytes32(0), salt);
        assertTrue(timelock.isOperationPending(id));

        // Cancel
        vm.prank(proposer1);
        timelock.cancel(id);

        assertFalse(timelock.isOperationPending(id));
    }

    function test_Cancel_RevertIf_NotProposer() public {
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        bytes32 salt = keccak256("test");

        // Schedule
        vm.prank(proposer1);
        timelock.schedule(address(target), 0, data, bytes32(0), salt, MIN_DELAY);

        bytes32 id = timelock.hashOperation(address(target), 0, data, bytes32(0), salt);

        // Try to cancel as non-proposer
        vm.prank(user);
        vm.expectRevert();
        timelock.cancel(id);
    }

    // ============ Batch Tests ============

    function test_ScheduleBatch_Success() public {
        address[] memory targets = new address[](2);
        targets[0] = address(target);
        targets[1] = address(target);

        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;

        bytes[] memory payloads = new bytes[](2);
        payloads[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 100);
        payloads[1] = abi.encodeWithSelector(MockTarget.pause.selector);

        bytes32 salt = keccak256("batch");

        vm.prank(proposer1);
        timelock.scheduleBatch(targets, values, payloads, bytes32(0), salt, MIN_DELAY);

        bytes32 id = timelock.hashOperationBatch(targets, values, payloads, bytes32(0), salt);
        assertTrue(timelock.isOperationPending(id));
    }

    function test_ExecuteBatch_Success() public {
        address[] memory targets = new address[](2);
        targets[0] = address(target);
        targets[1] = address(target);

        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;

        bytes[] memory payloads = new bytes[](2);
        payloads[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 100);
        payloads[1] = abi.encodeWithSelector(MockTarget.pause.selector);

        bytes32 salt = keccak256("batch");

        // Schedule
        vm.prank(proposer1);
        timelock.scheduleBatch(targets, values, payloads, bytes32(0), salt, MIN_DELAY);

        // Wait for delay
        vm.warp(block.timestamp + MIN_DELAY + 1);

        // Execute
        vm.prank(user);
        timelock.executeBatch(targets, values, payloads, bytes32(0), salt);

        assertEq(target.value(), 100);
        assertTrue(target.paused());
    }

    // ============ View Functions Tests ============

    function test_HashOperation_Deterministic() public view {
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        bytes32 salt = keccak256("test");

        bytes32 hash1 = timelock.hashOperation(address(target), 0, data, bytes32(0), salt);
        bytes32 hash2 = timelock.hashOperation(address(target), 0, data, bytes32(0), salt);

        assertEq(hash1, hash2);
    }

    function test_GetTimestamp_ReturnsCorrectValue() public {
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        bytes32 salt = keccak256("test");
        uint256 scheduledAt = block.timestamp;

        vm.prank(proposer1);
        timelock.schedule(address(target), 0, data, bytes32(0), salt, MIN_DELAY);

        bytes32 id = timelock.hashOperation(address(target), 0, data, bytes32(0), salt);
        assertEq(timelock.getTimestamp(id), scheduledAt + MIN_DELAY);
    }

    function test_IsOperationReady_ReturnsFalseBeforeDelay() public {
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        bytes32 salt = keccak256("test");

        vm.prank(proposer1);
        timelock.schedule(address(target), 0, data, bytes32(0), salt, MIN_DELAY);

        bytes32 id = timelock.hashOperation(address(target), 0, data, bytes32(0), salt);
        assertFalse(timelock.isOperationReady(id));
    }

    function test_IsOperationReady_ReturnsTrueAfterDelay() public {
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        bytes32 salt = keccak256("test");

        vm.prank(proposer1);
        timelock.schedule(address(target), 0, data, bytes32(0), salt, MIN_DELAY);

        vm.warp(block.timestamp + MIN_DELAY + 1);

        bytes32 id = timelock.hashOperation(address(target), 0, data, bytes32(0), salt);
        assertTrue(timelock.isOperationReady(id));
    }

    function test_IsOperationDone_ReturnsTrueAfterExecution() public {
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        bytes32 salt = keccak256("test");

        // Schedule
        vm.prank(proposer1);
        timelock.schedule(address(target), 0, data, bytes32(0), salt, MIN_DELAY);

        bytes32 id = timelock.hashOperation(address(target), 0, data, bytes32(0), salt);

        // Wait and execute
        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.prank(user);
        timelock.execute(address(target), 0, data, bytes32(0), salt);

        assertTrue(timelock.isOperationDone(id));
    }

    // ============ Admin Tests ============

    function test_UpdateDelay_Success() public {
        uint256 newDelay = 72 hours;

        // Schedule delay update
        bytes memory data = abi.encodeWithSelector(timelock.updateDelay.selector, newDelay);
        bytes32 salt = keccak256("delay-update");

        vm.prank(proposer1);
        timelock.schedule(address(timelock), 0, data, bytes32(0), salt, MIN_DELAY);

        vm.warp(block.timestamp + MIN_DELAY + 1);

        vm.prank(user);
        timelock.execute(address(timelock), 0, data, bytes32(0), salt);

        assertEq(timelock.getMinDelay(), newDelay);
    }

    // ============ Integration Tests ============

    function test_Integration_FullGovernanceFlow() public {
        // 1. Proposer schedules a value change
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 999);
        bytes32 salt = keccak256("governance-test");

        vm.prank(proposer1);
        timelock.schedule(address(target), 0, data, bytes32(0), salt, MIN_DELAY);

        // 2. Check operation is pending
        bytes32 id = timelock.hashOperation(address(target), 0, data, bytes32(0), salt);
        assertTrue(timelock.isOperationPending(id));
        assertFalse(timelock.isOperationReady(id));

        // 3. Wait for half the delay - still not ready
        vm.warp(block.timestamp + MIN_DELAY / 2);
        assertFalse(timelock.isOperationReady(id));

        // 4. Wait for full delay - now ready
        vm.warp(block.timestamp + MIN_DELAY / 2 + 1);
        assertTrue(timelock.isOperationReady(id));

        // 5. Anyone can execute
        vm.prank(user);
        timelock.execute(address(target), 0, data, bytes32(0), salt);

        // 6. Verify execution
        assertEq(target.value(), 999);
        assertTrue(timelock.isOperationDone(id));
    }

    function test_Integration_EmergencyPauseFlow() public {
        // Emergency pause should happen immediately (not via timelock)
        // This simulates the PAUSER_ROLE flow

        // First, set up the target to be pausable and not paused
        assertFalse(target.paused());

        // Emergency pause (direct call, no timelock)
        target.pause();
        assertTrue(target.paused());

        // Unpause via timelock (48h delay)
        bytes memory data = abi.encodeWithSelector(MockTarget.unpause.selector);
        bytes32 salt = keccak256("unpause");

        vm.prank(proposer1);
        timelock.schedule(address(target), 0, data, bytes32(0), salt, MIN_DELAY);

        // Still paused during delay
        vm.warp(block.timestamp + MIN_DELAY - 1);
        assertTrue(target.paused());

        // After delay, unpause
        vm.warp(block.timestamp + 2);
        vm.prank(user);
        timelock.execute(address(target), 0, data, bytes32(0), salt);

        assertFalse(target.paused());
    }

    function test_Integration_PredecessorDependency() public {
        // Operation 1: Set value to 50
        bytes memory data1 = abi.encodeWithSelector(MockTarget.setValue.selector, 50);
        bytes32 salt1 = keccak256("op1");

        // Operation 2: Set value to 100 (depends on op1)
        bytes memory data2 = abi.encodeWithSelector(MockTarget.setValue.selector, 100);
        bytes32 salt2 = keccak256("op2");

        bytes32 id1 = timelock.hashOperation(address(target), 0, data1, bytes32(0), salt1);

        // Schedule op1
        vm.prank(proposer1);
        timelock.schedule(address(target), 0, data1, bytes32(0), salt1, MIN_DELAY);

        // Schedule op2 with op1 as predecessor
        vm.prank(proposer1);
        timelock.schedule(address(target), 0, data2, id1, salt2, MIN_DELAY);

        // Wait for delay
        vm.warp(block.timestamp + MIN_DELAY + 1);

        // Can't execute op2 before op1
        vm.prank(user);
        vm.expectRevert();
        timelock.execute(address(target), 0, data2, id1, salt2);

        // Execute op1 first
        vm.prank(user);
        timelock.execute(address(target), 0, data1, bytes32(0), salt1);
        assertEq(target.value(), 50);

        // Now op2 can execute
        vm.prank(user);
        timelock.execute(address(target), 0, data2, id1, salt2);
        assertEq(target.value(), 100);
    }

    // ============ Gas Tests ============

    function test_Gas_Schedule() public {
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        bytes32 salt = keccak256("gas-test");

        vm.prank(proposer1);
        uint256 gasBefore = gasleft();
        timelock.schedule(address(target), 0, data, bytes32(0), salt, MIN_DELAY);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Gas used for schedule:", gasUsed);
        assertLt(gasUsed, 100_000);
    }

    function test_Gas_Execute() public {
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        bytes32 salt = keccak256("gas-test");

        vm.prank(proposer1);
        timelock.schedule(address(target), 0, data, bytes32(0), salt, MIN_DELAY);

        vm.warp(block.timestamp + MIN_DELAY + 1);

        vm.prank(user);
        uint256 gasBefore = gasleft();
        timelock.execute(address(target), 0, data, bytes32(0), salt);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Gas used for execute:", gasUsed);
        assertLt(gasUsed, 100_000);
    }

    // ============ Fuzz Tests ============

    function testFuzz_Schedule_AnyDelay(uint256 delay) public {
        delay = bound(delay, MIN_DELAY, 365 days);

        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        bytes32 salt = keccak256(abi.encodePacked("fuzz", delay));

        vm.prank(proposer1);
        timelock.schedule(address(target), 0, data, bytes32(0), salt, delay);

        bytes32 id = timelock.hashOperation(address(target), 0, data, bytes32(0), salt);
        assertTrue(timelock.isOperationPending(id));
    }
}

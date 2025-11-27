// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PaimonSetupCheck} from "../src/Counter.sol";

/// @title PaimonSetupCheckTest
/// @notice Test suite to verify Foundry + OpenZeppelin setup
contract PaimonSetupCheckTest is Test {
    PaimonSetupCheck public setupCheck;
    address public owner;
    address public user;

    function setUp() public {
        owner = address(this);
        user = makeAddr("user");
        setupCheck = new PaimonSetupCheck();
    }

    function test_InitialSetup() public view {
        assertEq(setupCheck.setupVersion(), 1);
        assertEq(setupCheck.owner(), owner);
    }

    function test_ProtocolName() public view {
        (string memory name, uint256 version) = setupCheck.getProtocolInfo();
        assertEq(name, "Paimon Gold Protocol");
        assertEq(version, 1);
    }

    function test_VerifySetup() public {
        bool success = setupCheck.verifySetup();
        assertTrue(success);
        assertEq(setupCheck.setupVersion(), 2);
    }

    function test_VerifySetupEmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit PaimonSetupCheck.SetupVerified(address(this), 2);
        setupCheck.verifySetup();
    }

    function testFuzz_MultipleVerifications(uint8 times) public {
        vm.assume(times > 0 && times < 100);

        for (uint8 i = 0; i < times; i++) {
            setupCheck.verifySetup();
        }

        assertEq(setupCheck.setupVersion(), uint256(times) + 1);
    }
}

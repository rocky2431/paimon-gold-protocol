// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {PaimonSetupCheck} from "../src/Counter.sol";

contract PaimonSetupScript is Script {
    PaimonSetupCheck public setupCheck;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        setupCheck = new PaimonSetupCheck();

        vm.stopBroadcast();
    }
}

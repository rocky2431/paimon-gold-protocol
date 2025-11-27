// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title PaimonSetupCheck
/// @notice Simple contract to verify Foundry + OpenZeppelin setup works correctly
/// @dev This is a placeholder contract for build verification - will be replaced by actual protocol contracts
contract PaimonSetupCheck is Ownable, ReentrancyGuard {
    uint256 public setupVersion;
    string public constant PROTOCOL_NAME = "Paimon Gold Protocol";

    event SetupVerified(address indexed verifier, uint256 version);

    constructor() Ownable(msg.sender) {
        setupVersion = 1;
    }

    /// @notice Verify the setup is working
    /// @return success True if setup is correct
    function verifySetup() external nonReentrant returns (bool success) {
        setupVersion++;
        emit SetupVerified(msg.sender, setupVersion);
        return true;
    }

    /// @notice Get protocol info
    /// @return name Protocol name
    /// @return version Current setup version
    function getProtocolInfo() external view returns (string memory name, uint256 version) {
        return (PROTOCOL_NAME, setupVersion);
    }
}

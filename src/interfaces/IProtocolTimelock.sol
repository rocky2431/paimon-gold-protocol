// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IProtocolTimelock
/// @notice Interface for the protocol timelock contract
/// @dev Extends OpenZeppelin TimelockController with protocol-specific configuration
interface IProtocolTimelock {
    // ============ Events ============

    /// @notice Emitted when minimum delay is updated
    event MinDelayUpdated(uint256 oldDelay, uint256 newDelay);

    /// @notice Emitted when emergency action is executed
    event EmergencyActionExecuted(address indexed executor, bytes32 indexed operationId);

    // ============ Errors ============

    /// @notice Thrown when delay is below minimum
    error DelayBelowMinimum();

    /// @notice Thrown when caller is not authorized
    error Unauthorized();

    /// @notice Thrown when operation is not ready
    error OperationNotReady();

    /// @notice Thrown when operation does not exist
    error OperationNotFound();

    // ============ View Functions ============

    /// @notice Get the minimum delay for timelock operations
    /// @return delay The minimum delay in seconds
    function getMinDelay() external view returns (uint256 delay);

    /// @notice Check if an operation is pending
    /// @param id The operation id
    /// @return pending True if the operation is pending
    function isOperationPending(bytes32 id) external view returns (bool pending);

    /// @notice Check if an operation is ready to execute
    /// @param id The operation id
    /// @return ready True if the operation is ready
    function isOperationReady(bytes32 id) external view returns (bool ready);

    /// @notice Check if an operation has been done
    /// @param id The operation id
    /// @return done True if the operation has been executed
    function isOperationDone(bytes32 id) external view returns (bool done);

    /// @notice Get the timestamp when operation becomes ready
    /// @param id The operation id
    /// @return timestamp The timestamp when operation can be executed
    function getTimestamp(bytes32 id) external view returns (uint256 timestamp);

    /// @notice Get the hash of an operation
    /// @param target Target address
    /// @param value ETH value
    /// @param data Call data
    /// @param predecessor Predecessor operation id (0 for none)
    /// @param salt Unique salt
    /// @return hash The operation id
    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external pure returns (bytes32 hash);

    /// @notice Get the hash of a batch operation
    /// @param targets Target addresses
    /// @param values ETH values
    /// @param payloads Call data array
    /// @param predecessor Predecessor operation id (0 for none)
    /// @param salt Unique salt
    /// @return hash The operation id
    function hashOperationBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    ) external pure returns (bytes32 hash);

    // ============ Scheduling Functions ============

    /// @notice Schedule an operation
    /// @param target Target address
    /// @param value ETH value
    /// @param data Call data
    /// @param predecessor Predecessor operation id (0 for none)
    /// @param salt Unique salt
    /// @param delay Delay before execution
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external;

    /// @notice Schedule a batch operation
    /// @param targets Target addresses
    /// @param values ETH values
    /// @param payloads Call data array
    /// @param predecessor Predecessor operation id (0 for none)
    /// @param salt Unique salt
    /// @param delay Delay before execution
    function scheduleBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external;

    // ============ Execution Functions ============

    /// @notice Execute an operation
    /// @param target Target address
    /// @param value ETH value
    /// @param payload Call data
    /// @param predecessor Predecessor operation id (0 for none)
    /// @param salt Unique salt
    function execute(
        address target,
        uint256 value,
        bytes calldata payload,
        bytes32 predecessor,
        bytes32 salt
    ) external payable;

    /// @notice Execute a batch operation
    /// @param targets Target addresses
    /// @param values ETH values
    /// @param payloads Call data array
    /// @param predecessor Predecessor operation id (0 for none)
    /// @param salt Unique salt
    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    ) external payable;

    // ============ Cancellation Functions ============

    /// @notice Cancel an operation
    /// @param id The operation id
    function cancel(bytes32 id) external;
}

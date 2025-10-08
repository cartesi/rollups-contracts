// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.10.0/src/Test.sol";

import {LibAddress} from "src/library/LibAddress.sol";
import {LibError} from "src/library/LibError.sol";

/// @notice This contract is used to test calls and delegatecalls.
/// It uses the LibAddress functions to make these operations safely.
contract Caller {
    /// @notice Make a safe call to a destination address.
    /// @param destination The call destination
    /// @param value The amount of Wei to be passed to the destination
    /// @param payload The call payload
    /// @return Whether the call was made or not (depending on the caller
    /// contract balance and the call value) and the caller contract balance.
    function makeSafeCall(address destination, uint256 value, bytes calldata payload)
        external
        returns (bool, uint256)
    {
        return LibAddress.safeCall(destination, value, payload);
    }

    /// @notice Make a safe delegatecall to a destination address.
    /// @param destination The delegatecall destination
    /// @param payload The call payload
    /// @dev Any Ether passed to this function is forwarded to the destination.
    function makeSafeDelegateCall(address destination, bytes calldata payload)
        external
        payable
    {
        return LibAddress.safeDelegateCall(destination, payload);
    }
}

/// @notice An EVM call message
/// @param sender Who made the call
/// @param value The amount of Wei forwarded
/// @param data The call data payload
struct Message {
    address sender;
    uint256 value;
    bytes data;
}

/// @notice Registers messages, indexed by registrant address.
/// Messages can be later retrieved, as well as their count (by registrant and total).
/// This contract is used to test successful calls and delegatecalls.
contract MessageRegistry {
    /// @notice Messages indexed by registrant addresses.
    mapping(address => Message[]) _messages;

    /// @notice The total number of messages registered.
    uint256 _totalMessageCount;

    /// @notice Tried to retrieve a nonexisting message.
    error NoMessage();

    /// @notice Register a message.
    /// @param message The message the caller would like to register
    /// @dev The caller of this function is the message registrant.
    function registerMessage(Message calldata message) external {
        _messages[msg.sender].push(message);
        ++_totalMessageCount;
    }

    /// @notice Retrieve a message by registrant and index.
    /// @param registrant The registrant address
    /// @param index The message index (among all messages from the registrant)
    /// @return The message
    /// @dev Reverts with error `NoMessage` if message index is out of bounds.
    /// @dev See `getMessageCount` for an exclusive upper bound on the index.
    function getMessage(address registrant, uint256 index)
        external
        view
        returns (Message memory)
    {
        require(index < getMessageCount(registrant), NoMessage());
        return _messages[registrant][index];
    }

    /// @notice Get the number of messages registered by a given address.
    /// @param registrant The registrant address
    /// @return number of messages from the registrant.
    function getMessageCount(address registrant) public view returns (uint256) {
        return _messages[registrant].length;
    }

    /// @notice Get the total number of messages registered by anyone.
    /// @return The total number of messages.
    function getTotalMessageCount() external view returns (uint256) {
        return _totalMessageCount;
    }
}

/// @notice Accepts any call of any sort, and registers them in a message registry.
/// It is used to test successful calls and delegatecalls.
contract AcceptingCallee {
    /// @notice The message registry used to register messages.
    MessageRegistry immutable _MSG_REGISTRY;

    /// @notice Constructs the accepting callee contract.
    /// @param msgRegistry A message registry
    constructor(MessageRegistry msgRegistry) {
        _MSG_REGISTRY = msgRegistry;
    }

    /// @notice The fallback function.
    /// @dev Registers every message on the registry.
    fallback() external payable {
        _MSG_REGISTRY.registerMessage(
            Message({sender: msg.sender, value: msg.value, data: msg.data})
        );
    }
}

/// @notice Stores data. This contract is necessary for testing
/// reverting delegatecalls because we cannot access the storage
/// space of the destination contract.
contract DataStorage {
    /// @notice The data stored on construction.
    bytes _data;

    /// @notice Constructs a data storage contract.
    /// @param data An arbitrary byte array
    constructor(bytes memory data) {
        _data = data;
    }

    /// @notice Retrieve the data from storage.
    /// @return The data stored on construction.
    function getData() external view returns (bytes memory) {
        return _data;
    }
}

/// @notice Rejects every call with a given error set on construction.
contract RejectingCallee {
    using LibError for bytes;

    /// @notice The data storage contract storing the error.
    /// @dev We choose not to store the data itself in the storage
    /// space of the rejecting contract because this contract is
    /// used to test delegate calls, which preserve the storage
    /// context of the caller, which means we cannot access the
    /// storage space of the rejecting callee. Instead, we store
    /// the error data elsewhere and embed the address of this
    /// data storage contract in the rejecting callee bytecode
    /// (by annotating it with the `immutable` keyword).
    DataStorage immutable _ERROR_DATA_STORAGE;

    /// @notice Construct a rejecting callee contract.
    /// @param errordata The error data to be raised on calls later
    constructor(bytes memory errordata) {
        _ERROR_DATA_STORAGE = new DataStorage(errordata);
    }

    /// @notice The fallback function.
    /// @dev Reverts with the error data passed on construction.
    fallback() external payable {
        _ERROR_DATA_STORAGE.getData().raise();
    }
}

contract LibAddressTest is Test {
    Caller caller;
    MessageRegistry msgRegistry;

    function setUp() external {
        caller = new Caller();
        msgRegistry = new MessageRegistry();
    }

    function testGetTotalMessageCount() external view {
        assertEq(msgRegistry.getTotalMessageCount(), 0);
    }

    function testGetMessageCount(address registrant) external view {
        assertEq(msgRegistry.getMessageCount(registrant), 0);
    }

    function testGetMessage(address registrant, uint256 index) external {
        vm.expectRevert(MessageRegistry.NoMessage.selector);
        msgRegistry.getMessage(registrant, index);
    }

    function testSafeCallAccepting(
        bytes32 salt,
        uint256 callerBalanceBefore,
        uint256 value,
        bytes calldata payload
    ) external {
        // First, we deploy an accepting callee contract using CREATE2
        // to add some entropy to the destination address.
        address destination = address(new AcceptingCallee{salt: salt}(msgRegistry));

        // We pick a random initial destination balance that doesn't overflow.
        uint256 destinationBalanceBefore = vm.randomUint(0, type(uint256).max - value);

        // Then, we initialize the caller and destination balances.
        vm.deal(address(caller), callerBalanceBefore);
        vm.deal(destination, destinationBalanceBefore);

        // We then trigger the safe call and store the return values:
        // whether the caller had enough Ether to complete the call,
        // and the balance of the caller before the call.
        (bool callerHadEnoughWei, uint256 callerBalanceBeforeReturned) =
            caller.makeSafeCall(destination, value, payload);

        // We make sure the balance returned matches the one initialized,
        // and that the caller had enough Ether to complete the call
        // iff the balance before was greater than or equal to the call value.
        assertEq(callerBalanceBeforeReturned, callerBalanceBefore);
        assertEq(callerHadEnoughWei, callerBalanceBefore >= value);

        // Then, we measure the balance of the caller and destination
        // after the call and compare then against the previous values.
        uint256 callerBalanceAfter = address(caller).balance;
        uint256 destinationBalanceAfter = destination.balance;

        if (callerHadEnoughWei) {
            // If the caller had enough Ether, then the call value
            // moved from the caller to the destination.
            assertEq(callerBalanceAfter + value, callerBalanceBefore);
            assertEq(destinationBalanceAfter, destinationBalanceBefore + value);

            // Check the registered message.
            assertEq(msgRegistry.getTotalMessageCount(), 1);
            assertEq(msgRegistry.getMessageCount(destination), 1);
            Message memory message = msgRegistry.getMessage(destination, 0);
            assertEq(message.sender, address(caller));
            assertEq(message.value, value);
            assertEq(message.data, payload);
        } else {
            // If the callee did not have enough Ether, then the
            // balances after are the same as those before.
            assertEq(callerBalanceAfter, callerBalanceBefore);
            assertEq(destinationBalanceAfter, destinationBalanceBefore);

            // Check the (still empty) message registry.
            assertEq(msgRegistry.getTotalMessageCount(), 0);
        }
    }

    function testSafeCallRejecting(
        bytes32 salt,
        uint256 value,
        bytes calldata payload,
        bytes calldata error
    ) external {
        // First, we deploy a rejecting callee contract using CREATE2
        // to add some entropy to the destination address.
        address destination = address(new RejectingCallee{salt: salt}(error));

        // We pick a random initial caller balance that covers the call value.
        uint256 callerBalanceBefore = vm.randomUint(value, type(uint256).max);

        // We pick a random initial destination balance that doesn't overflow.
        uint256 destinationBalanceBefore = vm.randomUint(0, type(uint256).max - value);

        // Then, we initialize the caller and destination balances.
        vm.deal(address(caller), callerBalanceBefore);
        vm.deal(destination, destinationBalanceBefore);

        // We then trigger the safe call, expecting it to revert with
        // the same error provided to the rejecting callee constructor.
        vm.expectRevert(error);
        caller.makeSafeCall(destination, value, payload);
    }

    function testSafeDelegateCallAccepting(
        address sender,
        uint256 senderBalance,
        bytes32 salt,
        bytes calldata payload
    ) external {
        // First, we deploy an accepting callee contract using CREATE2
        // to add some entropy to the destination address.
        address destination = address(new AcceptingCallee{salt: salt}(msgRegistry));

        // We pick a random value to be forwarded to the call that
        // is below the sender initial balance.
        uint256 value = vm.randomUint(0, senderBalance);

        // Then, we initialize the sender balance.
        vm.deal(sender, senderBalance);

        // We then trigger the safe delegatecall.
        // We prank a random account to show that msg.sender is preserved.
        // We also pass some value to show that msg.value is preserved.
        vm.prank(sender);
        caller.makeSafeDelegateCall{value: value}(destination, payload);

        // Check the registered message.
        // An interesting aspect of this test is that you can see that
        // the message registry is called not by the accepting callee, but rather
        // by the caller. This is a fundamental aspect of delegatecall.
        // Also note that the message value is the same as the one provided
        // to the original call.
        assertEq(msgRegistry.getTotalMessageCount(), 1);
        assertEq(msgRegistry.getMessageCount(address(caller)), 1);
        Message memory message = msgRegistry.getMessage(address(caller), 0);
        assertEq(message.sender, sender);
        assertEq(message.value, value);
        assertEq(message.data, payload);
    }

    function testSafeDelegateCallRejecting(
        bytes32 salt,
        bytes calldata payload,
        bytes calldata error
    ) external {
        // First, we deploy a rejecting callee contract using CREATE2
        // to add some entropy to the destination address.
        address destination = address(new RejectingCallee{salt: salt}(error));

        // We then trigger the safe delegatecall, expecting it to revert with
        // the same error provided to the rejecting callee constructor.
        vm.expectRevert(error);
        caller.makeSafeDelegateCall(destination, payload);
    }
}

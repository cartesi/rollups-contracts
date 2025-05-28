// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IApplication} from "./IApplication.sol";
import {IOutputsMerkleRootValidator} from "../consensus/IOutputsMerkleRootValidator.sol";
import {LibOutputValidityProof} from "../library/LibOutputValidityProof.sol";
import {OutputValidityProof} from "../common/OutputValidityProof.sol";
import {Outputs} from "../common/Outputs.sol";
import {LibAddress} from "../library/LibAddress.sol";
import {IOwnable} from "../access/IOwnable.sol";

import {ERC721Holder} from
    "@openzeppelin-contracts-5.2.0/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Holder} from
    "@openzeppelin-contracts-5.2.0/token/ERC1155/utils/ERC1155Holder.sol";
import {ReentrancyGuardTransient} from
    "@openzeppelin-contracts-5.2.0/utils/ReentrancyGuardTransient.sol";
import {IERC721Receiver} from
    "@openzeppelin-contracts-5.2.0/token/ERC721/IERC721Receiver.sol";
import {BitMaps} from "@openzeppelin-contracts-5.2.0/utils/structs/BitMaps.sol";
import {Clones} from "@openzeppelin-contracts-5.2.0/proxy/Clones.sol";

contract Application is
    IApplication,
    ERC721Holder,
    ERC1155Holder,
    ReentrancyGuardTransient
{
    using Clones for address;
    using BitMaps for BitMaps.BitMap;
    using LibAddress for address;
    using LibOutputValidityProof for OutputValidityProof;

    /// @notice Arguments embedded into the proxy contract's bytecode
    struct Args {
        bytes32 templateHash;
        bytes dataAvailability;
    }

    /// @notice Whether the proxy has been initialized already.
    bool internal _initialized;

    /// @notice Deployment block number
    uint256 internal _deploymentBlockNumber;

    /// @notice Keeps track of which outputs have been executed.
    /// @dev See the `wasOutputExecuted` function.
    BitMaps.BitMap internal _executed;

    /// @notice The current outputs Merkle root validator contract.
    /// @dev See the `getOutputsMerkleRootValidator` and `migrateToOutputsMerkleRootValidator` functions.
    IOutputsMerkleRootValidator internal _outputsMerkleRootValidator;

    /// @notice Application owner
    /// @dev See the `owner`, `transferOwnership` and `renounceOwnership` functions.
    address internal _owner;

    /// @notice Initialize an `Application` contract proxy.
    /// @param outputsMerkleRootValidator The initial outputs Merkle root validator contract
    /// @param initialOwner The initial application owner
    /// @dev Reverts if the initial application owner address is zero.
    function initialize(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address initialOwner
    ) external {
        assert(!_initialized);
        _ensureNewOwnerIsValid(initialOwner);
        _deploymentBlockNumber = block.number;
        _outputsMerkleRootValidator = outputsMerkleRootValidator;
        _transferOwnership(initialOwner);
        _initialized = true;
    }

    /// @notice Accept Ether transfers.
    /// @dev If you wish to transfer Ether to an application while informing
    ///      the backend of it, then please do so through the Ether portal contract.
    receive() external payable {}

    /// @inheritdoc IApplication
    function executeOutput(bytes calldata output, OutputValidityProof calldata proof)
        external
        override
        nonReentrant
    {
        validateOutput(output, proof);

        uint64 outputIndex = proof.outputIndex;

        if (output.length < 4) {
            revert OutputNotExecutable(output);
        }

        bytes4 selector = bytes4(output[:4]);
        bytes calldata arguments = output[4:];

        if (selector == Outputs.Voucher.selector) {
            if (_executed.get(outputIndex)) {
                revert OutputNotReexecutable(output);
            }
            _executeVoucher(arguments);
        } else if (selector == Outputs.DelegateCallVoucher.selector) {
            if (_executed.get(outputIndex)) {
                revert OutputNotReexecutable(output);
            }
            _executeDelegateCallVoucher(arguments);
        } else {
            revert OutputNotExecutable(output);
        }

        _executed.set(outputIndex);
        emit OutputExecuted(outputIndex, output);
    }

    /// @inheritdoc IApplication
    function migrateToOutputsMerkleRootValidator(
        IOutputsMerkleRootValidator newOutputsMerkleRootValidator
    ) external override onlyOwner {
        _outputsMerkleRootValidator = newOutputsMerkleRootValidator;
        emit OutputsMerkleRootValidatorChanged(newOutputsMerkleRootValidator);
    }

    /// @inheritdoc IApplication
    function wasOutputExecuted(uint256 outputIndex)
        external
        view
        override
        returns (bool)
    {
        return _executed.get(outputIndex);
    }

    /// @inheritdoc IApplication
    function validateOutput(bytes calldata output, OutputValidityProof calldata proof)
        public
        view
        override
    {
        validateOutputHash(keccak256(output), proof);
    }

    /// @inheritdoc IApplication
    function validateOutputHash(bytes32 outputHash, OutputValidityProof calldata proof)
        public
        view
        override
    {
        if (!proof.isSiblingsArrayLengthValid()) {
            revert InvalidOutputHashesSiblingsArrayLength();
        }

        bytes32 outputsMerkleRoot = proof.computeOutputsMerkleRoot(outputHash);

        if (!_isOutputsMerkleRootValid(outputsMerkleRoot)) {
            revert InvalidOutputsMerkleRoot(outputsMerkleRoot);
        }
    }

    /// @inheritdoc IApplication
    function getTemplateHash() external view override returns (bytes32) {
        return _args().templateHash;
    }

    /// @inheritdoc IApplication
    function getOutputsMerkleRootValidator()
        external
        view
        override
        returns (IOutputsMerkleRootValidator)
    {
        return _outputsMerkleRootValidator;
    }

    /// @inheritdoc IApplication
    function getDataAvailability() external view override returns (bytes memory) {
        return _args().dataAvailability;
    }

    /// @inheritdoc IApplication
    function getDeploymentBlockNumber() external view override returns (uint256) {
        return _deploymentBlockNumber;
    }

    /// @inheritdoc IOwnable
    function owner() external view override returns (address) {
        return _owner;
    }

    /// @inheritdoc IOwnable
    function renounceOwnership() external override onlyOwner {
        _transferOwnership(address(0));
    }

    /// @inheritdoc IOwnable
    function transferOwnership(address newOwner) public override onlyOwner {
        _ensureNewOwnerIsValid(newOwner);
        _transferOwnership(newOwner);
    }

    /// @notice Makes a function permissioned.
    modifier onlyOwner() {
        _ensureSenderIsOwner();
        _;
    }

    /// @notice Check if an outputs Merkle root is valid,
    /// according to the current outputs Merkle root validator.
    /// @param outputsMerkleRoot The output Merkle root
    function _isOutputsMerkleRootValid(bytes32 outputsMerkleRoot)
        internal
        view
        returns (bool)
    {
        return _outputsMerkleRootValidator.isOutputsMerkleRootValid(
            address(this), outputsMerkleRoot
        );
    }

    /// @notice Executes a voucher
    /// @param arguments ABI-encoded arguments
    function _executeVoucher(bytes calldata arguments) internal {
        address destination;
        uint256 value;
        bytes memory payload;

        (destination, value, payload) = abi.decode(arguments, (address, uint256, bytes));

        bool enoughFunds;
        uint256 balance;

        (enoughFunds, balance) = destination.safeCall(value, payload);

        if (!enoughFunds) {
            revert InsufficientFunds(value, balance);
        }
    }

    /// @notice Executes a delegatecall voucher
    /// @param arguments ABI-encoded arguments
    function _executeDelegateCallVoucher(bytes calldata arguments) internal {
        address destination;
        bytes memory payload;

        (destination, payload) = abi.decode(arguments, (address, bytes));

        destination.safeDelegateCall(payload);
    }

    /// @notice Get the initialization arguments embedded into the proxy's bytecode
    function _args() internal view returns (Args memory) {
        return abi.decode(address(this).fetchCloneArgs(), (Args));
    }

    /// @notice Transfer ownership without checking arguments or message sender.
    function _transferOwnership(address newOwner) internal {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /// @notice Revert if the message sender is not the owner.
    function _ensureSenderIsOwner() internal view {
        require(msg.sender == _owner, OwnableUnauthorizedAccount(msg.sender));
    }

    /// @notice Revert if the new owner address is the zero address.
    function _ensureNewOwnerIsValid(address newOwner) internal pure {
        require(newOwner != address(0), OwnableInvalidOwner(newOwner));
    }
}

// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IOwnable} from "../access/IOwnable.sol";
import {OutputValidityProof} from "../common/OutputValidityProof.sol";
import {Outputs} from "../common/Outputs.sol";
import {IOutputsMerkleRootValidator} from "../consensus/IOutputsMerkleRootValidator.sol";
import {LibAddress} from "../library/LibAddress.sol";
import {LibOutputValidityProof} from "../library/LibOutputValidityProof.sol";
import {IApplication} from "./IApplication.sol";

import {Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable.sol";
import {
    ERC1155Holder
} from "@openzeppelin-contracts-5.2.0/token/ERC1155/utils/ERC1155Holder.sol";
import {
    ERC721Holder
} from "@openzeppelin-contracts-5.2.0/token/ERC721/utils/ERC721Holder.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts-5.2.0/utils/ReentrancyGuard.sol";
import {BitMaps} from "@openzeppelin-contracts-5.2.0/utils/structs/BitMaps.sol";

contract Application is
    IApplication,
    Ownable,
    ERC721Holder,
    ERC1155Holder,
    ReentrancyGuard
{
    using BitMaps for BitMaps.BitMap;
    using LibAddress for address;
    using LibOutputValidityProof for OutputValidityProof;

    /// @notice Deployment block number
    uint256 immutable _deploymentBlockNumber = block.number;

    /// @notice The initial machine state hash.
    /// @dev See the `getTemplateHash` function.
    bytes32 internal immutable _templateHash;

    /// @notice Keeps track of which outputs have been executed.
    /// @dev See the `wasOutputExecuted` function.
    BitMaps.BitMap internal _executed;

    /// @notice The current outputs Merkle root validator contract.
    /// @dev See the `getOutputsMerkleRootValidator` and `migrateToOutputsMerkleRootValidator` functions.
    IOutputsMerkleRootValidator internal _outputsMerkleRootValidator;

    /// @notice The data availability solution.
    /// @dev See the `getDataAvailability` function.
    bytes internal _dataAvailability;

    /// @notice The number of outputs executed by the application.
    /// @dev See the `numberOfOutputsExecuted` function.
    uint256 _numOfExecutedOutputs;

    /// @notice Creates an `Application` contract.
    /// @param outputsMerkleRootValidator The initial outputs Merkle root validator contract
    /// @param initialOwner The initial application owner
    /// @param templateHash The initial machine state hash
    /// @dev Reverts if the initial application owner address is zero.
    constructor(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address initialOwner,
        bytes32 templateHash,
        bytes memory dataAvailability
    ) Ownable(initialOwner) {
        _templateHash = templateHash;
        _outputsMerkleRootValidator = outputsMerkleRootValidator;
        _dataAvailability = dataAvailability;
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
        ++_numOfExecutedOutputs;
        emit OutputExecuted(outputIndex, output);
    }

    /// @inheritdoc IApplication
    function migrateToOutputsMerkleRootValidator(IOutputsMerkleRootValidator newOutputsMerkleRootValidator)
        external
        override
        onlyOwner
    {
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
        return _templateHash;
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
        return _dataAvailability;
    }

    /// @inheritdoc IApplication
    function getDeploymentBlockNumber() external view override returns (uint256) {
        return _deploymentBlockNumber;
    }

    /// @inheritdoc IApplication
    function getNumberOfExecutedOutputs() external view override returns (uint256) {
        return _numOfExecutedOutputs;
    }

    /// @inheritdoc Ownable
    function owner() public view override(IOwnable, Ownable) returns (address) {
        return super.owner();
    }

    /// @inheritdoc Ownable
    function renounceOwnership() public override(IOwnable, Ownable) {
        super.renounceOwnership();
    }

    /// @inheritdoc Ownable
    function transferOwnership(address newOwner) public override(IOwnable, Ownable) {
        super.transferOwnership(newOwner);
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
}

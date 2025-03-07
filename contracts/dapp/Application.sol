// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IApplication} from "./IApplication.sol";
import {IConsensus} from "../consensus/IConsensus.sol";
import {LibOutputValidityProof} from "../library/LibOutputValidityProof.sol";
import {OutputValidityProof} from "../common/OutputValidityProof.sol";
import {Outputs} from "../common/Outputs.sol";
import {LibAddress} from "../library/LibAddress.sol";
import {IOwnable} from "../access/IOwnable.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721Holder} from
    "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Holder} from
    "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ReentrancyGuard} from
    "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC721Receiver} from
    "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";

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

    /// @notice The initial machine state hash.
    /// @dev See the `getTemplateHash` function.
    bytes32 internal immutable _templateHash;

    /// @notice Keeps track of which outputs have been executed.
    /// @dev See the `wasOutputExecuted` function.
    BitMaps.BitMap internal _executed;

    /// @notice The current consensus contract.
    /// @dev See the `getConsensus` and `migrateToConsensus` functions.
    IConsensus internal _consensus;

    /// @notice The data availability solution.
    /// @dev See the `getDataAvailability` function.
    bytes internal _dataAvailability;

    /// @notice Creates an `Application` contract.
    /// @param consensus The initial consensus contract
    /// @param initialOwner The initial application owner
    /// @param templateHash The initial machine state hash
    /// @dev Reverts if the initial application owner address is zero.
    constructor(
        IConsensus consensus,
        address initialOwner,
        bytes32 templateHash,
        bytes memory dataAvailability
    ) Ownable(initialOwner) {
        _templateHash = templateHash;
        _consensus = consensus;
        _dataAvailability = dataAvailability;
    }

    /// @notice Accept Ether transfers.
    /// @dev If you wish to transfer Ether to an application while informing
    ///      the backend of it, then please do so through the Ether portal contract.
    receive() external payable {}

    function executeOutput(
        bytes calldata output,
        OutputValidityProof calldata proof
    ) external override nonReentrant {
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

    function migrateToConsensus(IConsensus newConsensus)
        external
        override
        onlyOwner
    {
        _consensus = newConsensus;
        emit NewConsensus(newConsensus);
    }

    function wasOutputExecuted(uint256 outputIndex)
        external
        view
        override
        returns (bool)
    {
        return _executed.get(outputIndex);
    }

    function validateOutput(
        bytes calldata output,
        OutputValidityProof calldata proof
    ) public view override {
        validateOutputHash(keccak256(output), proof);
    }

    function validateOutputHash(
        bytes32 outputHash,
        OutputValidityProof calldata proof
    ) public view override {
        if (!proof.isSiblingsArrayLengthValid()) {
            revert InvalidOutputHashesSiblingsArrayLength();
        }

        bytes32 outputsMerkleRoot = proof.computeOutputsMerkleRoot(outputHash);

        if (!_isOutputsMerkleRootValid(outputsMerkleRoot)) {
            revert InvalidOutputsMerkleRoot(outputsMerkleRoot);
        }
    }

    function getTemplateHash() external view override returns (bytes32) {
        return _templateHash;
    }

    function getConsensus() external view override returns (IConsensus) {
        return _consensus;
    }

    function getDataAvailability()
        external
        view
        override
        returns (bytes memory)
    {
        return _dataAvailability;
    }

    function owner()
        public
        view
        override(IOwnable, Ownable)
        returns (address)
    {
        return super.owner();
    }

    function renounceOwnership() public override(IOwnable, Ownable) {
        super.renounceOwnership();
    }

    function transferOwnership(address newOwner)
        public
        override(IOwnable, Ownable)
    {
        super.transferOwnership(newOwner);
    }

    /// @notice Check if an outputs Merkle root is valid,
    /// according to the current consensus.
    /// @param outputsMerkleRoot The output Merkle root
    function _isOutputsMerkleRootValid(bytes32 outputsMerkleRoot)
        internal
        view
        returns (bool)
    {
        return _consensus.isOutputsMerkleRootValid(
            address(this), outputsMerkleRoot
        );
    }

    /// @notice Executes a voucher
    /// @param arguments ABI-encoded arguments
    function _executeVoucher(bytes calldata arguments) internal {
        address destination;
        uint256 value;
        bytes memory payload;

        (destination, value, payload) =
            abi.decode(arguments, (address, uint256, bytes));

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

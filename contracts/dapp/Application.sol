// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IApplication} from "./IApplication.sol";
import {IConsensus} from "../consensus/IConsensus.sol";
import {LibOutputValidityProof} from "../library/LibOutputValidityProof.sol";
import {OutputValidityProof} from "../common/OutputValidityProof.sol";
import {Outputs} from "../common/Outputs.sol";
import {LibAddress} from "../library/LibAddress.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
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

    /// @notice Creates an `Application` contract.
    /// @param consensus The initial consensus contract
    /// @param initialOwner The initial application owner
    /// @param templateHash The initial machine state hash
    constructor(
        IConsensus consensus,
        address initialOwner,
        bytes32 templateHash
    ) Ownable(initialOwner) {
        _templateHash = templateHash;
        _consensus = consensus;
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

    function migrateToConsensus(
        IConsensus newConsensus
    ) external override onlyOwner {
        _consensus = newConsensus;
        emit NewConsensus(newConsensus);
    }

    function wasOutputExecuted(
        uint256 outputIndex
    ) external view override returns (bool) {
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

        bytes32 claim = proof.computeClaim(outputHash);

        if (!_wasClaimAccepted(claim)) {
            revert ClaimNotAccepted(claim);
        }
    }

    function getTemplateHash() external view override returns (bytes32) {
        return _templateHash;
    }

    function getConsensus() external view override returns (IConsensus) {
        return _consensus;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155Holder, IERC165) returns (bool) {
        return
            interfaceId == type(IApplication).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @notice Check if an output Merkle root hash was ever accepted by the current consensus.
    /// @param claim The output Merkle root hash
    function _wasClaimAccepted(bytes32 claim) internal view returns (bool) {
        return _consensus.wasClaimAccepted(address(this), claim);
    }

    /// @notice Executes a voucher
    /// @param arguments ABI-encoded arguments
    function _executeVoucher(bytes calldata arguments) internal {
        address destination;
        uint256 value;
        bytes memory payload;

        (destination, value, payload) = abi.decode(
            arguments,
            (address, uint256, bytes)
        );

        destination.safeCall(value, payload);
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

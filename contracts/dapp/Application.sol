// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IApplication} from "./IApplication.sol";
import {IConsensus} from "../consensus/IConsensus.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {IPortal} from "../portals/IPortal.sol";
import {LibOutputValidityProof} from "../library/LibOutputValidityProof.sol";
import {OutputValidityProof} from "../common/OutputValidityProof.sol";
import {Outputs} from "../common/Outputs.sol";
import {InputRange} from "../common/InputRange.sol";
import {LibError} from "../library/LibError.sol";
import {LibInputRange} from "../library/LibInputRange.sol";

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
    using LibError for bytes;
    using LibOutputValidityProof for OutputValidityProof;
    using LibInputRange for InputRange;

    /// @notice The initial machine state hash.
    /// @dev See the `getTemplateHash` function.
    bytes32 internal immutable _templateHash;

    /// @notice Keeps track of which outputs have been executed.
    /// @dev See the `wasOutputExecuted` function.
    mapping(uint256 => BitMaps.BitMap) internal _executed;

    /// @notice The current consensus contract.
    /// @dev See the `getConsensus` and `migrateToConsensus` functions.
    IConsensus internal _consensus;

    /// @notice The input box contract.
    /// @dev See the `getInputBox` function.
    IInputBox internal immutable _inputBox;

    /// @notice The portals supported by the application.
    /// @dev See the `getPortals` function.
    IPortal[] internal _portals;

    /// @notice Creates an `Application` contract.
    /// @param consensus The initial consensus contract
    /// @param inputBox The input box contract
    /// @param portals The portals supported by the application
    /// @param initialOwner The initial application owner
    /// @param templateHash The initial machine state hash
    constructor(
        IConsensus consensus,
        IInputBox inputBox,
        IPortal[] memory portals,
        address initialOwner,
        bytes32 templateHash
    ) Ownable(initialOwner) {
        _templateHash = templateHash;
        _consensus = consensus;
        _inputBox = inputBox;
        for (uint256 i; i < portals.length; ++i) {
            _portals.push(portals[i]);
        }
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

        uint256 inputIndex = proof.calculateInputIndex();
        uint64 outputIndexWithinInput = proof.outputIndexWithinInput;

        BitMaps.BitMap storage bitmap = _executed[outputIndexWithinInput];

        if (output.length < 4) {
            revert OutputNotExecutable(output);
        }

        bytes4 selector = bytes4(output[:4]);
        bytes calldata arguments = output[4:];

        if (selector == Outputs.Voucher.selector) {
            if (bitmap.get(inputIndex)) {
                revert OutputNotReexecutable(output);
            }
            _executeVoucher(arguments);
        } else if (selector == Outputs.DelegateCallVoucher.selector) {
            if (bitmap.get(inputIndex)) {
                revert OutputNotReexecutable(output);
            }
            _executeDelegateCallVoucher(arguments);
        } else {
            revert OutputNotExecutable(output);
        }

        bitmap.set(inputIndex);
        emit OutputExecuted(uint64(inputIndex), outputIndexWithinInput, output);
    }

    function migrateToConsensus(
        IConsensus newConsensus
    ) external override onlyOwner {
        _consensus = newConsensus;
        emit NewConsensus(newConsensus);
    }

    function wasOutputExecuted(
        uint256 inputIndex,
        uint256 outputIndexWithinInput
    ) external view override returns (bool) {
        return _executed[outputIndexWithinInput].get(inputIndex);
    }

    function validateOutput(
        bytes calldata output,
        OutputValidityProof calldata proof
    ) public view override {
        uint256 inputIndex = proof.calculateInputIndex();

        if (!proof.inputRange.contains(inputIndex)) {
            revert InputIndexOutOfRange(inputIndex, proof.inputRange);
        }

        bytes32 outputHash = keccak256(output);

        if (!proof.isOutputHashesRootHashValid(outputHash)) {
            revert IncorrectOutputHashesRootHash();
        }

        if (!proof.isOutputsEpochRootHashValid()) {
            revert IncorrectOutputsEpochRootHash();
        }

        bytes32 epochHash = _getEpochHash(proof.inputRange);

        if (!proof.isEpochHashValid(epochHash)) {
            revert IncorrectEpochHash();
        }
    }

    function getTemplateHash() external view override returns (bytes32) {
        return _templateHash;
    }

    function getConsensus() external view override returns (IConsensus) {
        return _consensus;
    }

    function getInputBox() external view override returns (IInputBox) {
        return _inputBox;
    }

    function getPortals() external view override returns (IPortal[] memory) {
        return _portals;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155Holder, IERC165) returns (bool) {
        return
            interfaceId == type(IApplication).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @notice Get the epoch hash regarding an input range from the current consensus.
    /// @param inputRange The input range
    /// @return The epoch hash
    function _getEpochHash(
        InputRange calldata inputRange
    ) internal view returns (bytes32) {
        return _consensus.getEpochHash(address(this), inputRange);
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

        bool success;
        bytes memory returndata;

        (success, returndata) = destination.call{value: value}(payload);

        if (!success) {
            returndata.raise();
        }
    }

    /// @notice Executes a delegatecall voucher
    /// @param arguments ABI-encoded arguments
    function _executeDelegateCallVoucher(bytes calldata arguments) internal {
        address destination;
        bytes memory payload;

        (destination, payload) = abi.decode(arguments, (address, bytes));

        bool success;
        bytes memory returndata;

        (success, returndata) = destination.delegatecall(payload);

        if (!success) {
            returndata.raise();
        }
    }
}

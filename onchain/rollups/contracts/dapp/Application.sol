// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IApplication} from "./IApplication.sol";
import {IConsensus} from "../consensus/IConsensus.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {IInputRelay} from "../inputs/IInputRelay.sol";
import {LibOutputValidation} from "../library/LibOutputValidation.sol";
import {OutputValidityProof} from "../common/OutputValidityProof.sol";
import {Proof} from "../common/Proof.sol";
import {LibProof} from "../library/LibProof.sol";
import {InputRange} from "../common/InputRange.sol";
import {LibInputRange} from "../library/LibInputRange.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
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
    using LibOutputValidation for OutputValidityProof;
    using LibProof for Proof;
    using LibInputRange for InputRange;
    using Address for address;

    /// @notice Raised when executing an already executed voucher.
    error VoucherReexecutionNotAllowed();

    /// @notice Raised when the transfer fails.
    error EtherTransferFailed();

    /// @notice Raised when a mehtod is not called by application itself.
    error OnlyApplication();

    /// @notice The initial machine state hash.
    /// @dev See the `getTemplateHash` function.
    bytes32 internal immutable templateHash;

    /// @notice The executed voucher bitmask, which keeps track of which vouchers
    ///         were executed already in order to avoid re-execution.
    /// @dev See the `wasVoucherExecuted` function.
    mapping(uint256 => BitMaps.BitMap) internal voucherBitmaps;

    /// @notice The current consensus contract.
    /// @dev See the `getConsensus` and `migrateToConsensus` functions.
    IConsensus internal consensus;

    /// @notice The input box contract.
    /// @dev See the `getInputBox` function.
    IInputBox internal immutable inputBox;

    /// @notice The input relays.
    /// @dev See the `getInputRelays` function.
    IInputRelay[] internal inputRelays;

    /// @notice Creates an `Application` contract.
    /// @param _consensus The initial consensus contract
    /// @param _inputBox The input box contract
    /// @param _inputRelays The input relays
    /// @param _initialOwner The initial application owner
    /// @param _templateHash The initial machine state hash
    constructor(
        IConsensus _consensus,
        IInputBox _inputBox,
        IInputRelay[] memory _inputRelays,
        address _initialOwner,
        bytes32 _templateHash
    ) Ownable(_initialOwner) {
        templateHash = _templateHash;
        consensus = _consensus;
        inputBox = _inputBox;
        for (uint256 i; i < _inputRelays.length; ++i) {
            inputRelays.push(_inputRelays[i]);
        }
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155Holder, IERC165) returns (bool) {
        return
            interfaceId == type(IApplication).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function executeVoucher(
        address _destination,
        bytes calldata _payload,
        Proof calldata _proof
    ) external override nonReentrant {
        uint256 inputIndex = _proof.calculateInputIndex();

        if (!_proof.inputRange.contains(inputIndex)) {
            revert InputIndexOutOfRange(inputIndex, _proof.inputRange);
        }

        bytes32 epochHash = getEpochHash(_proof.inputRange);

        // reverts if proof isn't valid
        _proof.validity.validateVoucher(_destination, _payload, epochHash);

        uint256 outputIndexWithinInput = _proof.validity.outputIndexWithinInput;
        BitMaps.BitMap storage bitmap = voucherBitmaps[outputIndexWithinInput];

        // check if voucher has been executed
        if (bitmap.get(inputIndex)) {
            revert VoucherReexecutionNotAllowed();
        }

        // execute voucher
        _destination.functionCall(_payload);

        // mark it as executed and emit event
        bitmap.set(inputIndex);
        emit VoucherExecuted(inputIndex, outputIndexWithinInput);
    }

    function wasVoucherExecuted(
        uint256 _inputIndex,
        uint256 _outputIndexWithinInput
    ) external view override returns (bool) {
        return voucherBitmaps[_outputIndexWithinInput].get(_inputIndex);
    }

    function validateNotice(
        bytes calldata _notice,
        Proof calldata _proof
    ) external view override {
        uint256 inputIndex = _proof.calculateInputIndex();

        if (!_proof.inputRange.contains(inputIndex)) {
            revert InputIndexOutOfRange(inputIndex, _proof.inputRange);
        }

        bytes32 epochHash = getEpochHash(_proof.inputRange);

        // reverts if proof isn't valid
        _proof.validity.validateNotice(_notice, epochHash);
    }

    function migrateToConsensus(
        IConsensus _newConsensus
    ) external override onlyOwner {
        consensus = _newConsensus;
        emit NewConsensus(_newConsensus);
    }

    function getTemplateHash() external view override returns (bytes32) {
        return templateHash;
    }

    function getConsensus() external view override returns (IConsensus) {
        return consensus;
    }

    function getInputBox() external view override returns (IInputBox) {
        return inputBox;
    }

    function getInputRelays()
        external
        view
        override
        returns (IInputRelay[] memory)
    {
        return inputRelays;
    }

    /// @notice Accept Ether transfers.
    /// @dev If you wish to transfer Ether to an application while informing
    ///      the backend of it, then please do so through the Ether portal contract.
    receive() external payable {}

    /// @notice Transfer some amount of Ether to some recipient.
    /// @param _receiver The address which will receive the amount of Ether
    /// @param _value The amount of Ether to be transferred in Wei
    /// @dev This function can only be called by the application itself through vouchers.
    ///      If this method is not called by application itself, `OnlyApplication` error is raised.
    ///      If the transfer fails, `EtherTransferFailed` error is raised.
    function withdrawEther(address _receiver, uint256 _value) external {
        if (msg.sender != address(this)) {
            revert OnlyApplication();
        }

        (bool sent, ) = _receiver.call{value: _value}("");

        if (!sent) {
            revert EtherTransferFailed();
        }
    }

    /// @notice Get the epoch hash regarding the given input range
    /// and the application from the current consensus.
    /// @param inputRange The input range
    /// @return The epoch hash
    function getEpochHash(
        InputRange calldata inputRange
    ) internal view returns (bytes32) {
        return consensus.getEpochHash(address(this), inputRange);
    }
}

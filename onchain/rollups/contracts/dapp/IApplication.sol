// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {IConsensus} from "../consensus/IConsensus.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {IInputRelay} from "../inputs/IInputRelay.sol";
import {OutputValidityProof} from "../common/OutputValidityProof.sol";
import {Proof} from "../common/Proof.sol";
import {InputRange} from "../common/InputRange.sol";

/// @title Application interface
interface IApplication is IERC721Receiver, IERC1155Receiver {
    // Errors

    /// @notice Could not validate an output because
    /// the input that generated it is outside the given input range.
    /// @param inputIndex The input index
    /// @param inputRange The input range
    error InputIndexOutOfRange(uint256 inputIndex, InputRange inputRange);

    // Events

    /// @notice The application has migrated to another consensus contract.
    /// @param newConsensus The new consensus contract
    /// @dev MUST be triggered on a successful call to `migrateToConsensus`.
    event NewConsensus(IConsensus newConsensus);

    /// @notice A voucher was executed from the application.
    /// @param inputIndex The index of the input that emitted the voucher
    /// @param outputIndexWithinInput The index of the voucher amongst all outputs emitted by the input
    event VoucherExecuted(uint256 inputIndex, uint256 outputIndexWithinInput);

    // Permissioned functions

    /// @notice Migrate the application to a new consensus.
    /// @param _newConsensus The new consensus
    /// @dev Can only be called by the application owner.
    function migrateToConsensus(IConsensus _newConsensus) external;

    // Permissionless functions

    /// @notice Try to execute a voucher.
    /// Reverts if the proof is invalid.
    /// Reverts if the voucher was already successfully executed.
    /// Propagates any error raised by the low-level call.
    /// @param _destination The address that will receive the payload through a message call
    /// @param _payload The payload, which—in the case of Solidity contracts—encodes a function call
    /// @param _proof The proof used to validate the voucher against
    ///               a claim submitted by the current consensus contract
    /// @dev On a successful execution, emits a `VoucherExecuted` event.
    function executeVoucher(
        address _destination,
        bytes calldata _payload,
        Proof calldata _proof
    ) external;

    /// @notice Check whether a voucher has been executed.
    /// @param _inputIndex The index of the input in the input box
    /// @param _outputIndexWithinInput The index of output emitted by the input
    /// @return Whether the voucher has been executed before
    function wasVoucherExecuted(
        uint256 _inputIndex,
        uint256 _outputIndexWithinInput
    ) external view returns (bool);

    /// @notice Validate a notice.
    /// Reverts if the proof is invalid.
    /// @param _notice The notice
    /// @param _proof The proof used to validate the notice against
    ///               a claim submitted by the current consensus contract
    function validateNotice(
        bytes calldata _notice,
        Proof calldata _proof
    ) external view;

    /// @notice Get the application's template hash.
    /// @return The application's template hash
    function getTemplateHash() external view returns (bytes32);

    /// @notice Get the current consensus.
    /// @return The current consensus
    function getConsensus() external view returns (IConsensus);

    /// @notice Get the input box that the application is listening to.
    /// @return The input box
    function getInputBox() external view returns (IInputBox);

    /// @notice Get the input relays that the application expects inputs from.
    /// @return The input relays.
    function getInputRelays() external view returns (IInputRelay[] memory);
}

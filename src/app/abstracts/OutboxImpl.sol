// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {BitMaps} from "@openzeppelin-contracts-5.2.0/utils/structs/BitMaps.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts-5.2.0/utils/ReentrancyGuard.sol";

import {EpochManager} from "../interfaces/EpochManager.sol";
import {LibAddress} from "../../library/LibAddress.sol";
import {LibOutputValidityProof} from "../../library/LibOutputValidityProof.sol";
import {Outbox} from "../interfaces/Outbox.sol";
import {OutputValidityProof} from "../../common/OutputValidityProof.sol";
import {Outputs} from "../../common/Outputs.sol";

abstract contract OutboxImpl is Outbox, ReentrancyGuard, EpochManager {
    using BitMaps for BitMaps.BitMap;
    using LibAddress for address;
    using LibOutputValidityProof for OutputValidityProof;

    /// @notice Keeps track of which outputs have been executed.
    /// @dev See the `wasOutputExecuted` function.
    BitMaps.BitMap private _executedOutputs;

    /// @notice Keeps track of the number of outputs that have been executed.
    /// @dev See the `getNumberOfExecutedOutputs` function.
    uint256 private _numOfExecutedOutputs;

    function wasOutputExecuted(uint256 outputIndex) public view override returns (bool) {
        return _executedOutputs.get(outputIndex);
    }

    function getNumberOfExecutedOutputs() external view override returns (uint256) {
        return _numOfExecutedOutputs;
    }

    function isOutputsRootFinal(bytes32 outputsRoot) public view override virtual returns (bool);

    function validateOutputHash(bytes32 outputHash, OutputValidityProof calldata proof)
        public
        view
        override
    {
        if (!proof.isSiblingsArrayLengthValid()) {
            revert InvalidOutputHashesSiblingsArrayLength();
        }

        bytes32 outputsMerkleRoot = proof.computeOutputsMerkleRoot(outputHash);

        if (!isOutputsRootFinal(outputsMerkleRoot)) {
            revert InvalidOutputsMerkleRoot(outputsMerkleRoot);
        }
    }

    function validateOutput(bytes calldata output, OutputValidityProof calldata proof)
        public
        view
        override
    {
        validateOutputHash(keccak256(output), proof);
    }

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
            if (_executedOutputs.get(outputIndex)) {
                revert OutputNotReexecutable(output);
            }
            _executeVoucher(arguments);
        } else if (selector == Outputs.DelegateCallVoucher.selector) {
            if (_executedOutputs.get(outputIndex)) {
                revert OutputNotReexecutable(output);
            }
            _executeDelegateCallVoucher(arguments);
        } else {
            revert OutputNotExecutable(output);
        }

        _executedOutputs.set(outputIndex);
        ++_numOfExecutedOutputs;
        emit OutputExecuted(outputIndex, output);
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

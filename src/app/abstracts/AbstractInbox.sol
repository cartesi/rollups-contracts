// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {CanonicalMachine} from "../../common/CanonicalMachine.sol";
import {Inbox} from "../interfaces/Inbox.sol";
import {Inputs} from "../../common/Inputs.sol";
import {LibBinaryMerkleTree} from "../../library/LibBinaryMerkleTree.sol";
import {LibKeccak256} from "../../library/LibKeccak256.sol";
import {LibMath} from "../../library/LibMath.sol";

abstract contract AbstractInbox is Inbox {
    using LibMath for uint256;
    using LibBinaryMerkleTree for bytes;

    bytes32[] private _inputMerkleRoots;
    uint256 private _blockNumberOfLastSnapshot;
    uint256 private _numberOfInputsInLastSnapshot;

    /// @inheritdoc Inbox
    function addInput(bytes calldata payload) external override returns (bytes32) {
        uint256 index = _inputMerkleRoots.length;

        // update snapshot if first input of current block
        if (_blockNumberOfLastSnapshot < block.number) {
            _numberOfInputsInLastSnapshot = index;
            _blockNumberOfLastSnapshot = block.number;
        }

        bytes memory input = abi.encodeCall(
            Inputs.EvmAdvance,
            (
                block.chainid,
                address(this),
                msg.sender,
                block.number,
                block.timestamp,
                block.prevrandao,
                index,
                payload
            )
        );

        if (input.length > CanonicalMachine.INPUT_MAX_SIZE) {
            revert InputTooLarge(input.length, CanonicalMachine.INPUT_MAX_SIZE);
        }

        bytes32 inputMerkleRoot = _merkleRoot(input);

        _inputMerkleRoots.push(inputMerkleRoot);

        emit InputAdded(index, input);

        return inputMerkleRoot;
    }

    /// @inheritdoc Inbox
    function getNumberOfInputs() public view override returns (uint256) {
        return _inputMerkleRoots.length;
    }

    /// @inheritdoc Inbox
    function getNumberOfInputsBeforeCurrentBlock()
        public
        view
        override
        returns (uint256)
    {
        if (_blockNumberOfLastSnapshot == block.number) {
            return _numberOfInputsInLastSnapshot;
        } else {
            // _blockNumberOfLastSnapshot < block.number
            return getNumberOfInputs();
        }
    }

    /// @inheritdoc Inbox
    function getInputMerkleRoot(uint256 index) public view override returns (bytes32) {
        return _inputMerkleRoots[index];
    }

    /// @notice Compute the Merkle root of an input.
    /// @param input The input
    /// @return inputMerkleRoot The input Merkle root
    function _merkleRoot(bytes memory input)
        internal
        pure
        returns (bytes32 inputMerkleRoot)
    {
        uint256 log2DataBlockSize = CanonicalMachine.LOG2_MERKLE_TREE_DATA_BLOCK_SIZE;
        uint256 log2DriveSize = input.length.ceilLog2().max(log2DataBlockSize);
        return input.merkleRoot(
            log2DriveSize,
            log2DataBlockSize,
            LibKeccak256.hashBlock,
            LibKeccak256.hashPair
        );
    }
}

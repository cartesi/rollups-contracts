// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {IInputBox} from "./IInputBox.sol";
import {CanonicalMachine} from "../common/CanonicalMachine.sol";
import {Inputs} from "../common/Inputs.sol";
import {LibBinaryMerkleTree} from "../library/LibBinaryMerkleTree.sol";
import {LibKeccak256} from "../library/LibKeccak256.sol";
import {LibMath} from "../library/LibMath.sol";
import {LibAddress} from "../library/LibAddress.sol";

contract InputBox is IInputBox {
    using LibMath for uint256;
    using LibAddress for address;
    using LibBinaryMerkleTree for bytes;

    /// @notice Deployment block number
    uint256 immutable _deploymentBlockNumber = block.number;

    /// @notice Mapping of application contract addresses to arrays of input Merkle roots.
    mapping(address => bytes32[]) private _inputBoxes;

    /// @inheritdoc IInputBox
    function addInput(address appContract, bytes calldata payload)
        external
        override
        returns (bytes32)
    {
        require(appContract.hasCode(), ApplicationContractNotDeployed(appContract));

        bytes32[] storage inputBox = _inputBoxes[appContract];

        uint256 index = inputBox.length;

        bytes memory input = abi.encodeCall(
            Inputs.EvmAdvance,
            (
                block.chainid,
                appContract,
                msg.sender,
                block.number,
                block.timestamp,
                block.prevrandao,
                index,
                payload
            )
        );

        if (input.length > CanonicalMachine.INPUT_MAX_SIZE) {
            revert InputTooLarge(
                appContract, input.length, CanonicalMachine.INPUT_MAX_SIZE
            );
        }

        bytes32 inputMerkleRoot = _merkleRoot(input);

        inputBox.push(inputMerkleRoot);

        emit InputAdded(appContract, index, input);

        return inputMerkleRoot;
    }

    /// @inheritdoc IInputBox
    function getNumberOfInputs(address appContract)
        external
        view
        override
        returns (uint256)
    {
        return _inputBoxes[appContract].length;
    }

    /// @inheritdoc IInputBox
    function getInputMerkleRoot(address appContract, uint256 index)
        external
        view
        override
        returns (bytes32)
    {
        return _inputBoxes[appContract][index];
    }

    /// @inheritdoc IInputBox
    function getDeploymentBlockNumber() external view override returns (uint256) {
        return _deploymentBlockNumber;
    }

    /// @notice Compute the Merkle root of an input.
    /// @param input The input
    /// @return inputMerkleRoot The input Merkle root
    function _merkleRoot(bytes memory input)
        internal
        pure
        returns (bytes32 inputMerkleRoot)
    {
        uint256 log2DataBlockSize = CanonicalMachine.LOG2_DATA_BLOCK_SIZE;
        uint256 log2DriveSize = input.length.ceilLog2().max(log2DataBlockSize);
        return input.merkleRoot(
            log2DriveSize,
            log2DataBlockSize,
            LibKeccak256.hashBlock,
            LibKeccak256.hashPair
        );
    }
}

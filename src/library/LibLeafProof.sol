// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {AccessLogs} from "cartesi-machine-solidity-step-0.15.0/src/AccessLogs.sol";

import {CanonicalMachine} from "../common/CanonicalMachine.sol";
import {LeafProof} from "../common/LeafProof.sol";
import {MachineValidationErrors} from "../common/MachineValidationErrors.sol";
import {LibBinaryMerkleTree} from "./LibBinaryMerkleTree.sol";
import {LibKeccak256} from "./LibKeccak256.sol";

library LibLeafProof {
    type LeafIndex is uint64;
    type WordOffset is uint64;

    /// @notice Prove the value of the iflags_Y register of a machine.
    /// @param v The leaf proof for the iflags_Y register
    /// @param machineMerkleRoot The machine Merkle root
    /// @return iflagsY The iflags_Y register
    /// @dev May raise `InvalidSiblingsArrayLength` or `InvalidMachineMerkleProof`.
    function proveIflagsY(LeafProof calldata v, bytes32 machineMerkleRoot)
        internal
        pure
        returns (uint64 iflagsY)
    {
        return proveWord(v, machineMerkleRoot, CanonicalMachine.IFLAGS_Y_ADDRESS);
    }

    /// @notice Prove the value of the HTIF tohost register of a machine.
    /// @param v The leaf proof for the HTIF tohost register
    /// @param machineMerkleRoot The machine Merkle root
    /// @return htifTohost The HTIF tohost register
    /// @dev May raise `InvalidSiblingsArrayLength` or `InvalidMachineMerkleProof`.
    function proveHtifTohost(LeafProof calldata v, bytes32 machineMerkleRoot)
        internal
        pure
        returns (uint64 htifTohost)
    {
        return proveWord(v, machineMerkleRoot, CanonicalMachine.HTIF_TOHOST_ADDRESS);
    }

    /// @notice Prove the first data block of the CMIO tx buffer of a machine.
    /// @param v The leaf proof for the first data block of the CMIO tx buffer
    /// @param machineMerkleRoot The machine Merkle root
    /// @return txBuffer The first data block of the CMIO tx buffer
    /// @dev May raise `InvalidSiblingsArrayLength` or `InvalidMachineMerkleProof`.
    function proveTxBuffer(LeafProof calldata v, bytes32 machineMerkleRoot)
        internal
        pure
        returns (bytes32 txBuffer)
    {
        return proveDataBlock(v, machineMerkleRoot, CanonicalMachine.TX_BUFFER_START);
    }

    /// @notice Prove a word at a given address in the machine.
    /// @param v The leaf proof
    /// @param machineMerkleRoot The machine Merkle root
    /// @param wordAddress The word address
    /// @return word The proven word
    /// @dev May raise `InvalidSiblingsArrayLength` or `InvalidMachineMerkleProof`.
    function proveWord(
        LeafProof calldata v,
        bytes32 machineMerkleRoot,
        uint64 wordAddress
    ) internal pure returns (uint64 word) {
        (LeafIndex leafIndex, WordOffset wordOffset) = truncateToLeaf(wordAddress);
        bytes32 dataBlock = proveDataBlock(v, machineMerkleRoot, leafIndex);
        return getUint64WordFromDataBlock(dataBlock, wordOffset);
    }

    /// @notice Prove the value of a data block at a given address in the machine.
    /// @param v The leaf proof
    /// @param machineMerkleRoot The machine Merkle root
    /// @param dataBlockAddress The data block address
    /// @return dataBlock The proven data block
    /// @dev May raise `InvalidSiblingsArrayLength` or `InvalidMachineMerkleProof`.
    function proveDataBlock(
        LeafProof calldata v,
        bytes32 machineMerkleRoot,
        uint64 dataBlockAddress
    ) internal pure returns (bytes32 dataBlock) {
        (LeafIndex leafIndex,) = truncateToLeaf(dataBlockAddress);
        return proveDataBlock(v, machineMerkleRoot, leafIndex);
    }

    /// @notice Prove the value of a data block at a given leaf index in the machine.
    /// @param v The leaf proof
    /// @param machineMerkleRoot The machine Merkle root
    /// @param leafIndex The leaf index
    /// @return dataBlock The proven data block
    /// @dev May raise `InvalidSiblingsArrayLength` or `InvalidMachineMerkleProof`.
    function proveDataBlock(
        LeafProof calldata v,
        bytes32 machineMerkleRoot,
        LeafIndex leafIndex
    ) internal pure returns (bytes32 dataBlock) {
        require(
            machineMerkleRoot == computeMachineMerkleRoot(v, leafIndex),
            MachineValidationErrors.InvalidMachineMerkleProof()
        );

        return v.dataBlock;
    }

    /// @notice Compute the machine Merkle root from a leaf proof.
    /// @param v The leaf proof
    /// @param leafIndex The leaf index
    /// @return machineMerkleRoot The computed machine Merkle root
    /// @dev May raise `InvalidSiblingsArrayLength`.
    function computeMachineMerkleRoot(LeafProof calldata v, LeafIndex leafIndex)
        internal
        pure
        returns (bytes32 machineMerkleRoot)
    {
        require(
            v.siblings.length == CanonicalMachine.MEMORY_TREE_HEIGHT,
            MachineValidationErrors.InvalidSiblingsArrayLength()
        );

        return LibBinaryMerkleTree.merkleRootAfterReplacement(
            v.siblings,
            LeafIndex.unwrap(leafIndex),
            keccak256(abi.encode(v.dataBlock)),
            LibKeccak256.hashPair
        );
    }

    /// @notice Truncate a word address into leaf index and word offset.
    /// @param wordAddress The word address
    /// @return leafIndex The leaf index
    /// @return wordOffset The word offset within the data block
    function truncateToLeaf(uint64 wordAddress)
        internal
        pure
        returns (LeafIndex leafIndex, WordOffset wordOffset)
    {
        leafIndex = LeafIndex.wrap(wordAddress >> CanonicalMachine.LOG2_DATA_BLOCK_SIZE);
        wordOffset = WordOffset.wrap(wordAddress & CanonicalMachine.DATA_BLOCK_MASK);
    }

    /// @notice Get uint64 word at offset from data block.
    /// @param dataBlock The data block
    /// @param wordOffset The word offset within the data block
    /// @return word The uint64 word
    /// @dev Converts word from little-endian to big-endian order.
    function getUint64WordFromDataBlock(bytes32 dataBlock, WordOffset wordOffset)
        internal
        pure
        returns (uint64 word)
    {
        uint64 offset = WordOffset.unwrap(wordOffset);
        bytes8 raw = AccessLogs.getBytes8FromBytes32AtOffset(dataBlock, offset);
        return AccessLogs.machineWordToSolidityUint64(raw);
    }
}

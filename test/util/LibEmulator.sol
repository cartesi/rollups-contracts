// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {SafeCast} from "@openzeppelin-contracts-5.2.0/utils/math/SafeCast.sol";

import {AccessLogs} from "cartesi-machine-solidity-step-0.15.0/src/AccessLogs.sol";
import {EmulatorCompat} from "cartesi-machine-solidity-step-0.15.0/src/EmulatorCompat.sol";
import {EmulatorConstants} from "cartesi-machine-solidity-step-0.15.0/src/EmulatorConstants.sol";

import {AccountValidityProof} from "src/common/AccountValidityProof.sol";
import {CanonicalMachine} from "src/common/CanonicalMachine.sol";
import {LeafProof} from "src/common/LeafProof.sol";
import {MachineValidityProof} from "src/common/MachineValidityProof.sol";
import {OutputValidityProof} from "src/common/OutputValidityProof.sol";

import {LibBinaryKeccak256MerkleTree} from "../util/LibBinaryKeccak256MerkleTree.sol";
import {LibBytes32Array} from "../util/LibBytes32Array.sol";
import {CompressedNode} from "./CompressedNode.sol";
import {LibSparseNodeArray} from "./LibSparseNodeArray.sol";
import {SparseNode} from "./SparseNode.sol";

library LibEmulator {
    using SafeCast for uint256;
    using LibBytes32Array for bytes32[];
    using LibSparseNodeArray for SparseNode[];
    using LibBinaryKeccak256MerkleTree for bytes;
    using LibBinaryKeccak256MerkleTree for bytes32[];
    using LibBinaryKeccak256MerkleTree for CompressedNode[];

    struct State {
        bytes[] outputs;
        bytes[] accounts;
        uint64 iflagsY;
        uint64 htifTohost;
    }

    struct ProofComponents {
        bytes32 iflagsYDataBlock;
        bytes32 htifTohostDataBlock;
        bytes32 outputsMerkleRoot;
        CompressedNode[] compressedNodes;
    }

    /// @notice This error is raised whenever too many accounts
    /// would be added to the emulator state.
    /// @dev See LOG2_MAX_NUM_OF_ACCOUNTS
    error TooManyAccounts();

    /// @notice This error is raised whenever an account too large
    /// would be added to the emulator state.
    /// @dev See `getLog2MaxAccountSize`
    error AccountTooLarge();

    /// @notice This error is raised whenever an output too large
    /// would be added to the emulator state.
    /// @dev See `getLog2MaxOutputSize`
    error OutputTooLarge();

    type OutputIndex is uint64;
    type AccountIndex is uint64;

    bytes32 constant NO_OUTPUT_SENTINEL_VALUE = bytes32(0);
    bytes32 constant DEFAULT_NODE = bytes32(0);
    uint8 constant LOG2_LEAVES_PER_ACCOUNT = 0;
    uint8 constant LOG2_MAX_NUM_OF_ACCOUNTS = 17;
    uint64 constant ACCOUNTS_DRIVE_START_INDEX = 0x240000000;
    uint64 constant MEMORY_TREE_HEIGHT = CanonicalMachine.MEMORY_TREE_HEIGHT;

    // -------------
    // state changes
    // -------------

    function addOutput(State storage state, bytes memory output)
        internal
        returns (OutputIndex outputIndex)
    {
        require(output.length <= (1 << getLog2MaxOutputSize()), OutputTooLarge());
        bytes[] storage outputs = state.outputs;
        outputIndex = OutputIndex.wrap(outputs.length.toUint64());
        outputs.push(output);
    }

    function addAccount(State storage state, bytes memory account)
        internal
        returns (AccountIndex accountIndex)
    {
        require(account.length <= (1 << getLog2MaxAccountSize()), AccountTooLarge());
        bytes[] storage accounts = state.accounts;
        require(accounts.length < (1 << LOG2_MAX_NUM_OF_ACCOUNTS), TooManyAccounts());
        accountIndex = AccountIndex.wrap(accounts.length.toUint64());
        accounts.push(account);
    }

    function setIflagsY(State storage state, uint64 iflagsY) internal {
        state.iflagsY = iflagsY;
    }

    function setHtifTohostRxAccepted(State storage state) internal {
        setHtifTohost(
            state,
            EmulatorConstants.HTIF_DEV_YIELD,
            EmulatorConstants.HTIF_YIELD_CMD_MANUAL,
            EmulatorConstants.HTIF_YIELD_MANUAL_REASON_RX_ACCEPTED
        );
    }

    function setHtifTohost(State storage state, uint64 dev, uint64 cmd, uint64 reason)
        internal
    {
        uint64 devBits = EmulatorConstants.HTIF_DEV_MASK
            & EmulatorCompat.uint64ShiftLeft(dev, EmulatorConstants.HTIF_DEV_SHIFT);

        uint64 cmdBits = EmulatorConstants.HTIF_CMD_MASK
            & EmulatorCompat.uint64ShiftLeft(cmd, EmulatorConstants.HTIF_CMD_SHIFT);

        uint64 reasonBits = EmulatorConstants.HTIF_REASON_MASK
            & EmulatorCompat.uint64ShiftLeft(reason, EmulatorConstants.HTIF_REASON_SHIFT);

        uint64 htifTohost = devBits | cmdBits | reasonBits;
        setHtifTohost(state, htifTohost);
    }

    function setHtifTohost(State storage state, uint64 htifTohost) internal {
        state.htifTohost = htifTohost;
    }

    // -------------
    // state queries
    // -------------

    function getOutput(State storage state, OutputIndex outputIndex)
        internal
        view
        returns (bytes storage)
    {
        return state.outputs[OutputIndex.unwrap(outputIndex)];
    }

    function getOutputValidityProof(State storage state, OutputIndex outputIndex)
        internal
        view
        returns (OutputValidityProof memory)
    {
        bytes32[] memory outputHashes;

        outputHashes = getOutputHashes(state.outputs);

        return OutputValidityProof({
            outputIndex: OutputIndex.unwrap(outputIndex),
            outputHashesSiblings: getOutputSiblings(
                outputHashes, OutputIndex.unwrap(outputIndex)
            )
        });
    }

    function getOutputsMerkleRoot(State storage state) internal view returns (bytes32) {
        bytes32[] memory outputHashes;

        outputHashes = getOutputHashes(state.outputs);

        return getOutputsMerkleRoot(outputHashes);
    }

    function getAccount(State storage state, AccountIndex accountIndex)
        internal
        view
        returns (bytes storage)
    {
        return state.accounts[AccountIndex.unwrap(accountIndex)];
    }

    function getAccountValidityProof(State storage state, AccountIndex accountIndex)
        internal
        view
        returns (AccountValidityProof memory)
    {
        return AccountValidityProof({
            accountIndex: AccountIndex.unwrap(accountIndex),
            accountRootSiblings: getAccountRootSiblings(state, accountIndex)
        });
    }

    function getAccountMerkleRoots(State storage state)
        internal
        view
        returns (bytes32[] memory)
    {
        return getAccountMerkleRoots(state.accounts);
    }

    function getAccountsDriveMerkleRoot(State storage state)
        internal
        view
        returns (bytes32)
    {
        return getAccountsDriveMerkleRoot(getAccountMerkleRoots(state));
    }

    function getAccountRootSiblings(State storage state, AccountIndex accountIndex)
        internal
        view
        returns (bytes32[] memory accountRootSiblings)
    {
        accountRootSiblings = getAccountMerkleRootSiblingsInDrive(
            getAccountMerkleRoots(state), AccountIndex.unwrap(accountIndex)
        );

        require(
            accountRootSiblings.length == LOG2_MAX_NUM_OF_ACCOUNTS,
            "unexpected account Merkle root siblings in drive proof length"
        );
    }

    function buildIflagsYDataBlock(State storage state)
        internal
        view
        returns (bytes32 dataBlock)
    {
        dataBlock = AccessLogs.setBytes8ToBytes32AtOffset(
            AccessLogs.solidityUint64ToMachineWord(state.iflagsY),
            dataBlock,
            CanonicalMachine.IFLAGS_Y_ADDRESS & CanonicalMachine.DATA_BLOCK_MASK
        );
    }

    function buildHtifTohostDataBlock(State storage state)
        internal
        view
        returns (bytes32 dataBlock)
    {
        dataBlock = AccessLogs.setBytes8ToBytes32AtOffset(
            AccessLogs.solidityUint64ToMachineWord(state.htifTohost),
            dataBlock,
            CanonicalMachine.HTIF_TOHOST_ADDRESS & CanonicalMachine.DATA_BLOCK_MASK
        );
    }

    function buildProofComponents(State storage state)
        internal
        view
        returns (ProofComponents memory pc)
    {
        pc.iflagsYDataBlock = buildIflagsYDataBlock(state);
        pc.htifTohostDataBlock = buildHtifTohostDataBlock(state);
        pc.outputsMerkleRoot = getOutputsMerkleRoot(state);

        uint256 numOfAccounts = state.accounts.length;
        uint256 maxNumOfAccounts = 1 << LOG2_MAX_NUM_OF_ACCOUNTS;

        uint256 sparseNodeCount = 3 + numOfAccounts;

        require(numOfAccounts <= maxNumOfAccounts, TooManyAccounts());

        if (numOfAccounts < maxNumOfAccounts) {
            // If the number of accounts has not reached the limit,
            // we add a sparse node to pad the accounts drive with
            // zeroes (empty accounts).
            ++sparseNodeCount;
        }

        SparseNode[] memory sparseNodes = new SparseNode[](sparseNodeCount);

        uint256 sparseNodeIndex;

        sparseNodes[sparseNodeIndex++] = SparseNode({
            value: keccak256(abi.encode(pc.iflagsYDataBlock)),
            index: getIflagsYNodeIndex(),
            extra: 0
        });

        sparseNodes[sparseNodeIndex++] = SparseNode({
            value: keccak256(abi.encode(pc.htifTohostDataBlock)),
            index: getHtifTohostNodeIndex(),
            extra: 0
        });

        sparseNodes[sparseNodeIndex++] = SparseNode({
            value: keccak256(abi.encode(pc.outputsMerkleRoot)),
            index: getTxBufferNodeIndex(),
            extra: 0
        });

        for (uint256 i; i < numOfAccounts; ++i) {
            sparseNodes[sparseNodeIndex++] = SparseNode({
                value: getAccountMerkleRoot(state.accounts[i]),
                index: getAccountsDriveStartNodeIndex() + i,
                extra: 0
            });
        }

        if (numOfAccounts < maxNumOfAccounts) {
            sparseNodes[sparseNodeIndex++] = SparseNode({
                value: getEmptyAccountMerkleRoot(),
                index: getAccountsDriveStartNodeIndex() + numOfAccounts,
                extra: maxNumOfAccounts - numOfAccounts - 1
            });
        }

        assert(sparseNodeIndex == sparseNodeCount);

        pc.compressedNodes = sparseNodes.toCompressedNodeArray(DEFAULT_NODE);
    }

    // ------------------------
    // proof components queries
    // ------------------------

    function getMachineMerkleRoot(ProofComponents memory pc)
        internal
        pure
        returns (bytes32)
    {
        return pc.compressedNodes.merkleRootFromNodes(DEFAULT_NODE, MEMORY_TREE_HEIGHT);
    }

    function getSiblings(ProofComponents memory pc, uint64 nodeIndex)
        internal
        pure
        returns (bytes32[] memory siblings)
    {
        return pc.compressedNodes.siblings(DEFAULT_NODE, nodeIndex, MEMORY_TREE_HEIGHT);
    }

    function getLeafProof(ProofComponents memory pc, bytes32 dataBlock, uint64 nodeIndex)
        internal
        pure
        returns (LeafProof memory proof)
    {
        bytes32 node = pc.compressedNodes.at(nodeIndex, DEFAULT_NODE);
        assert(keccak256(abi.encode(dataBlock)) == node);
        return LeafProof({dataBlock: dataBlock, siblings: getSiblings(pc, nodeIndex)});
    }

    function getIflagsYProof(ProofComponents memory pc)
        internal
        pure
        returns (LeafProof memory proof)
    {
        return getLeafProof(pc, pc.iflagsYDataBlock, getIflagsYNodeIndex());
    }

    function getHtifTohostProof(ProofComponents memory pc)
        internal
        pure
        returns (LeafProof memory proof)
    {
        return getLeafProof(pc, pc.htifTohostDataBlock, getHtifTohostNodeIndex());
    }

    function getTxBufferProof(ProofComponents memory pc)
        internal
        pure
        returns (LeafProof memory proof)
    {
        return getLeafProof(pc, pc.outputsMerkleRoot, getTxBufferNodeIndex());
    }

    function getMachineValidityProof(ProofComponents memory pc)
        internal
        pure
        returns (MachineValidityProof memory proof)
    {
        return MachineValidityProof({
            iflagsYProof: getIflagsYProof(pc),
            htifTohostProof: getHtifTohostProof(pc),
            txBufferProof: getTxBufferProof(pc)
        });
    }

    function getAccountsDriveMerkleRootProof(ProofComponents memory pc)
        internal
        pure
        returns (bytes32[] memory accountsDriveMerkleRootProof)
    {
        bytes32[] memory siblings = getSiblings(pc, getAccountsDriveStartNodeIndex());

        (, accountsDriveMerkleRootProof) =
            siblings.split(LOG2_LEAVES_PER_ACCOUNT + LOG2_MAX_NUM_OF_ACCOUNTS);
    }

    // -----------------
    // Merkle operations
    // -----------------

    function getOutputsMerkleRoot(bytes32[] memory outputHashes)
        internal
        pure
        returns (bytes32)
    {
        return outputHashes.merkleRootFromNodes(
            NO_OUTPUT_SENTINEL_VALUE, CanonicalMachine.LOG2_MAX_OUTPUTS
        );
    }

    function getOutputSiblings(bytes32[] memory outputHashes, uint64 outputIndex)
        internal
        pure
        returns (bytes32[] memory)
    {
        return outputHashes.siblings(
            NO_OUTPUT_SENTINEL_VALUE, outputIndex, CanonicalMachine.LOG2_MAX_OUTPUTS
        );
    }

    function getAccountsDriveMerkleRoot(bytes32[] memory accountMerkleRoots)
        internal
        pure
        returns (bytes32)
    {
        return accountMerkleRoots.merkleRootFromNodes(
            getEmptyAccountMerkleRoot(), LOG2_MAX_NUM_OF_ACCOUNTS
        );
    }

    function getAccountMerkleRoot(bytes memory account) internal pure returns (bytes32) {
        return account.merkleRoot(
            CanonicalMachine.LOG2_DATA_BLOCK_SIZE + LOG2_LEAVES_PER_ACCOUNT,
            CanonicalMachine.LOG2_DATA_BLOCK_SIZE
        );
    }

    function getAccountMerkleRoots(bytes[] memory accounts)
        internal
        pure
        returns (bytes32[] memory accountMerkleRoots)
    {
        accountMerkleRoots = new bytes32[](accounts.length);
        for (uint256 i; i < accountMerkleRoots.length; ++i) {
            accountMerkleRoots[i] = getAccountMerkleRoot(accounts[i]);
        }
    }

    function getAccountMerkleRootSiblingsInDrive(
        bytes32[] memory accountMerkleRoots,
        uint64 accountIndex
    ) internal pure returns (bytes32[] memory) {
        return accountMerkleRoots.siblings(
            getEmptyAccountMerkleRoot(), accountIndex, LOG2_MAX_NUM_OF_ACCOUNTS
        );
    }

    function getEmptyAccountMerkleRoot() internal pure returns (bytes32) {
        bytes memory emptyAccount;
        return getAccountMerkleRoot(emptyAccount);
    }

    // ---------------
    // Hash operations
    // ---------------

    function getOutputHashes(bytes[] memory outputs)
        internal
        pure
        returns (bytes32[] memory leaves)
    {
        leaves = new bytes32[](outputs.length);
        for (uint256 i; i < leaves.length; ++i) {
            leaves[i] = keccak256(outputs[i]);
        }
    }

    // ------------------
    // Bitwise operations
    // ------------------

    function getNodeIndex(uint64 wordAddress) internal pure returns (uint64) {
        return wordAddress >> CanonicalMachine.LOG2_DATA_BLOCK_SIZE;
    }

    function getIflagsYNodeIndex() internal pure returns (uint64) {
        return getNodeIndex(CanonicalMachine.IFLAGS_Y_ADDRESS);
    }

    function getHtifTohostNodeIndex() internal pure returns (uint64) {
        return getNodeIndex(CanonicalMachine.HTIF_TOHOST_ADDRESS);
    }

    function getTxBufferNodeIndex() internal pure returns (uint64) {
        return getNodeIndex(CanonicalMachine.TX_BUFFER_START);
    }

    function getLog2MaxAccountSize()
        internal
        pure
        returns (uint8 log2MaxAccountSizeInBytes)
    {
        return CanonicalMachine.LOG2_DATA_BLOCK_SIZE + LOG2_LEAVES_PER_ACCOUNT;
    }

    function getLog2MaxOutputSize()
        internal
        pure
        returns (uint8 log2MaxOutputSizeInBytes)
    {
        return EmulatorConstants.AR_CMIO_TX_BUFFER_LOG2_SIZE;
    }

    function getAccountsDriveStartNodeIndex()
        internal
        pure
        returns (uint64 accountsDriveStartNodeIndex)
    {
        return ACCOUNTS_DRIVE_START_INDEX << getAccountsDriveRootNodeHeight();
    }

    function getAccountsDriveRootNodeHeight()
        internal
        pure
        returns (uint64 accountsDriveStartNodeHeight)
    {
        return LOG2_LEAVES_PER_ACCOUNT + LOG2_MAX_NUM_OF_ACCOUNTS;
    }
}

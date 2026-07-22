// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {SafeCast} from "@openzeppelin-contracts-5.2.0/utils/math/SafeCast.sol";

import {AccountValidityProof} from "src/common/AccountValidityProof.sol";
import {CanonicalMachine} from "src/common/CanonicalMachine.sol";
import {OutputValidityProof} from "src/common/OutputValidityProof.sol";
import {LibBinaryMerkleTree} from "src/library/LibBinaryMerkleTree.sol";
import {LibKeccak256} from "src/library/LibKeccak256.sol";

import {LibBinaryKeccak256MerkleTree} from "../util/LibBinaryKeccak256MerkleTree.sol";
import {LibBytes32Array} from "../util/LibBytes32Array.sol";
import {CompressedNode} from "./CompressedNode.sol";
import {LibBinaryMerkleTreeHelper} from "./LibBinaryMerkleTreeHelper.sol";
import {LibSparseNodeArray} from "./LibSparseNodeArray.sol";
import {SparseNode} from "./SparseNode.sol";

library LibEmulator {
    using SafeCast for uint256;
    using LibBinaryMerkleTree for bytes;
    using LibBytes32Array for bytes32[];
    using LibSparseNodeArray for SparseNode[];
    using LibBinaryMerkleTreeHelper for bytes32[];
    using LibBinaryKeccak256MerkleTree for bytes32[];
    using LibBinaryKeccak256MerkleTree for CompressedNode[];

    struct State {
        bytes[] outputs;
        bytes[] accounts;
    }

    struct ProofComponents {
        bytes32 outputsMerkleRoot;
        CompressedNode[] compressedNodes;
    }

    /// @notice This error is raised whenever too many accounts
    /// were added to the emulator state.
    error TooManyAccounts();

    type OutputIndex is uint64;
    type AccountIndex is uint64;

    bytes32 constant NO_OUTPUT_SENTINEL_VALUE = bytes32(0);
    bytes32 constant DEFAULT_NODE = bytes32(0);
    uint8 constant LOG2_LEAVES_PER_ACCOUNT = 0;
    uint8 constant LOG2_MAX_NUM_OF_ACCOUNTS = 17;
    uint64 constant ACCOUNTS_DRIVE_START_INDEX = 0x240000000;

    // -------------
    // state changes
    // -------------

    function addOutput(State storage state, bytes memory output)
        internal
        returns (OutputIndex outputIndex)
    {
        bytes[] storage outputs = state.outputs;
        outputIndex = OutputIndex.wrap(outputs.length.toUint64());
        outputs.push(output);
    }

    function addAccount(State storage state, bytes memory account)
        internal
        returns (AccountIndex accountIndex)
    {
        bytes[] storage accounts = state.accounts;
        require(accounts.length < (1 << LOG2_MAX_NUM_OF_ACCOUNTS), TooManyAccounts());
        accountIndex = AccountIndex.wrap(accounts.length.toUint64());
        accounts.push(account);
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

    function buildProofComponents(State storage state)
        internal
        view
        returns (ProofComponents memory pc)
    {
        pc.outputsMerkleRoot = getOutputsMerkleRoot(state);

        uint256 numOfAccounts = state.accounts.length;
        uint256 maxNumOfAccounts = 1 << LOG2_MAX_NUM_OF_ACCOUNTS;

        uint256 sparseNodeCount = 1 + numOfAccounts;

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
            value: keccak256(abi.encode(pc.outputsMerkleRoot)),
            index: getOutputsMerkleRootNodeIndex(),
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

    function getOutputsMerkleRootProof(ProofComponents memory pc)
        internal
        pure
        returns (bytes32[] memory outputsMerkleRootProof)
    {
        return pc.compressedNodes
            .siblings(
                DEFAULT_NODE,
                getOutputsMerkleRootNodeIndex(),
                CanonicalMachine.MEMORY_TREE_HEIGHT
            );
    }

    function getMachineMerkleRoot(ProofComponents memory pc)
        internal
        pure
        returns (bytes32)
    {
        return pc.compressedNodes
            .merkleRootFromCompressedNodes(
                DEFAULT_NODE, CanonicalMachine.MEMORY_TREE_HEIGHT
            );
    }

    function getAccountsDriveMerkleRootProof(ProofComponents memory pc)
        internal
        pure
        returns (bytes32[] memory accountsDriveMerkleRootProof)
    {
        bytes32[] memory siblings = pc.compressedNodes
            .siblings(
                DEFAULT_NODE,
                getAccountsDriveStartNodeIndex(),
                CanonicalMachine.MEMORY_TREE_HEIGHT
            );

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
            NO_OUTPUT_SENTINEL_VALUE,
            CanonicalMachine.LOG2_MAX_OUTPUTS,
            LibKeccak256.hashPair
        );
    }

    function getOutputSiblings(bytes32[] memory outputHashes, uint64 outputIndex)
        internal
        pure
        returns (bytes32[] memory)
    {
        return outputHashes.siblings(
            NO_OUTPUT_SENTINEL_VALUE,
            outputIndex,
            CanonicalMachine.LOG2_MAX_OUTPUTS,
            LibKeccak256.hashPair
        );
    }

    function getAccountsDriveMerkleRoot(bytes32[] memory accountMerkleRoots)
        internal
        pure
        returns (bytes32)
    {
        return accountMerkleRoots.merkleRootFromNodes(
            getEmptyAccountMerkleRoot(), LOG2_MAX_NUM_OF_ACCOUNTS, LibKeccak256.hashPair
        );
    }

    function getAccountMerkleRoot(bytes memory account) internal pure returns (bytes32) {
        return account.merkleRoot(
            CanonicalMachine.LOG2_DATA_BLOCK_SIZE + LOG2_LEAVES_PER_ACCOUNT,
            CanonicalMachine.LOG2_DATA_BLOCK_SIZE,
            LibKeccak256.hashBlock,
            LibKeccak256.hashPair
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
            getEmptyAccountMerkleRoot(),
            accountIndex,
            LOG2_MAX_NUM_OF_ACCOUNTS,
            LibKeccak256.hashPair
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

    function getOutputsMerkleRootNodeIndex()
        internal
        pure
        returns (uint64 outputsMerkleRootNodeIndex)
    {
        return CanonicalMachine.TX_BUFFER_START >> CanonicalMachine.LOG2_DATA_BLOCK_SIZE;
    }

    function getLog2MaxAccountSize()
        internal
        pure
        returns (uint8 log2MaxAccountSizeInBytes)
    {
        return CanonicalMachine.LOG2_DATA_BLOCK_SIZE + LOG2_LEAVES_PER_ACCOUNT;
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

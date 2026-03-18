// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {SafeCast} from "@openzeppelin-contracts-5.2.0/utils/math/SafeCast.sol";

import {AccountValidityProof} from "src/common/AccountValidityProof.sol";
import {CanonicalMachine} from "src/common/CanonicalMachine.sol";
import {OutputValidityProof} from "src/common/OutputValidityProof.sol";
import {LibBinaryMerkleTree} from "src/library/LibBinaryMerkleTree.sol";
import {LibKeccak256} from "src/library/LibKeccak256.sol";

import {ExternalLibBinaryMerkleTree} from "../library/LibBinaryMerkleTree.t.sol";
import {LibBytes32Array} from "../util/LibBytes32Array.sol";
import {LibBinaryMerkleTreeHelper} from "./LibBinaryMerkleTreeHelper.sol";

library LibEmulator {
    using SafeCast for uint256;
    using LibBinaryMerkleTree for bytes;
    using LibBytes32Array for bytes32[];
    using LibBinaryMerkleTreeHelper for bytes32[];
    using ExternalLibBinaryMerkleTree for bytes32[];

    struct State {
        bytes[] outputs;
        bytes[] accounts;
    }

    struct ProofComponents {
        bytes32 outputsMerkleRoot;
        bytes32 forkNodeLeftChild;
        bytes32 forkNodeRightChild;
        bytes32[] forkNodeSiblings;
        bytes32[] outputsMerkleRootSiblings;
        bytes32[] accountsDriveMerkleRootSiblings;
    }

    type OutputIndex is uint64;
    type AccountIndex is uint64;

    bytes32 constant NO_OUTPUT_SENTINEL_VALUE = bytes32(0);
    uint8 constant LOG2_LEAVES_PER_ACCOUNT = 0;
    uint8 constant LOG2_MAX_NUM_OF_ACCOUNTS = 17;
    uint64 constant ACCOUNTS_DRIVE_START_INDEX = 0x240000000;
    uint8 constant FORK_NODE_HEIGHT = 51;

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

    function getAccountValidityProof(
        State storage state,
        ProofComponents memory pc,
        AccountIndex accountIndex
    ) internal view returns (AccountValidityProof memory) {
        return AccountValidityProof({
            accountIndex: AccountIndex.unwrap(accountIndex),
            accountRootSiblings: getAccountRootSiblings(state, pc, accountIndex)
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

    function buildProofComponents(State storage state)
        internal
        view
        returns (ProofComponents memory pc)
    {
        pc.outputsMerkleRoot = getOutputsMerkleRoot(state);

        pc.outputsMerkleRootSiblings = new bytes32[](FORK_NODE_HEIGHT - 1);
        pc.accountsDriveMerkleRootSiblings =
            new bytes32[](FORK_NODE_HEIGHT - 1 - getAccountsDriveRootNodeHeight());
        pc.forkNodeSiblings =
            new bytes32[](CanonicalMachine.MEMORY_TREE_HEIGHT - FORK_NODE_HEIGHT);

        pc.forkNodeLeftChild = pc.outputsMerkleRootSiblings
            .merkleRootAfterReplacement(
                getOutputsMerkleRootNodeIndex()
                    & ((1 << pc.outputsMerkleRootSiblings.length) - 1),
                keccak256(abi.encode(pc.outputsMerkleRoot))
            );

        pc.forkNodeRightChild =
            pc.accountsDriveMerkleRootSiblings
                .merkleRootAfterReplacement(
                    (getAccountsDriveStartNodeIndex() >> getAccountsDriveRootNodeHeight())
                        & ((1 << pc.accountsDriveMerkleRootSiblings.length) - 1),
                    getAccountsDriveMerkleRoot(state)
                );
    }

    function getOutputsMerkleRootProof(ProofComponents memory pc)
        internal
        pure
        returns (bytes32[] memory outputsMerkleRootProof)
    {
        bytes32[] memory forkNodeChildSibling = new bytes32[](1);
        forkNodeChildSibling[0] = pc.forkNodeRightChild;

        outputsMerkleRootProof = pc.outputsMerkleRootSiblings.concat(forkNodeChildSibling)
            .concat(pc.forkNodeSiblings);

        require(
            outputsMerkleRootProof.length == CanonicalMachine.MEMORY_TREE_HEIGHT,
            "unexpected outputs Merkle proof length"
        );
    }

    function getMachineMerkleRoot(ProofComponents memory pc)
        internal
        pure
        returns (bytes32)
    {
        return pc.forkNodeSiblings
            .merkleRootAfterReplacement(
                getOutputsMerkleRootNodeIndex() >> FORK_NODE_HEIGHT,
                LibKeccak256.hashPair(pc.forkNodeLeftChild, pc.forkNodeRightChild)
            );
    }

    function getAccountRootSiblings(
        State storage state,
        ProofComponents memory pc,
        AccountIndex accountIndex
    ) internal view returns (bytes32[] memory accountRootSiblings) {
        bytes32[] memory forkNodeChildSibling = new bytes32[](1);
        forkNodeChildSibling[0] = pc.forkNodeLeftChild;

        bytes32[] memory accountMerkleRootSiblingsInDrive =
            getAccountMerkleRootSiblingsInDrive(
                getAccountMerkleRoots(state), AccountIndex.unwrap(accountIndex)
            );

        require(
            accountMerkleRootSiblingsInDrive.length == LOG2_MAX_NUM_OF_ACCOUNTS,
            "unexpected account Merkle root siblings in drive proof length"
        );

        require(
            pc.accountsDriveMerkleRootSiblings.length
                == (FORK_NODE_HEIGHT - 1 - LOG2_MAX_NUM_OF_ACCOUNTS
                        - LOG2_LEAVES_PER_ACCOUNT),
            "unexpected fork node siblings length"
        );

        require(
            (getOutputsMerkleRootNodeIndex() >> (FORK_NODE_HEIGHT - 1)) & 1 == 0,
            "outputs merkle root predecessor is left node"
        );

        require(
            (getAccountsDriveStartNodeIndex() >> (FORK_NODE_HEIGHT - 1)) & 1 == 1,
            "accounts drive predecessor is right node"
        );

        require(
            pc.forkNodeSiblings.length
                == (CanonicalMachine.MEMORY_TREE_HEIGHT - FORK_NODE_HEIGHT),
            "unexpected fork node siblings length"
        );

        accountRootSiblings = accountMerkleRootSiblingsInDrive.concat(
                pc.accountsDriveMerkleRootSiblings
            ).concat(forkNodeChildSibling).concat(pc.forkNodeSiblings);

        require(
            accountRootSiblings.length
                == (CanonicalMachine.MEMORY_TREE_HEIGHT - LOG2_LEAVES_PER_ACCOUNT),
            "unexpected account root siblings length"
        );
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

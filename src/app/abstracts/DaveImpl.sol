// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {IDataProvider} from "prt-contracts/IDataProvider.sol";
import {ITournamentFactory} from "prt-contracts/ITournamentFactory.sol";
import {ITournament} from "prt-contracts/ITournament.sol";
import {Machine} from "prt-contracts/types/Machine.sol";

import {EpochManagerImpl} from "./EpochManagerImpl.sol";

abstract contract DaveImpl is EpochManagerImpl, IDataProvider {
    ITournamentFactory immutable _TOURNAMENT_FACTORY;

    ITournament private _tournament;
    Machine.Hash private _lastFinalizedPostEpochStateRoot;

    constructor(ITournamentFactory tournamentFactory) {
        _TOURNAMENT_FACTORY = tournamentFactory;
    }

    function getEpochFinalizerInterfaceId() external pure override returns (bytes4) {
        return type(ITournament).interfaceId;
    }

    function closeCurrentEpoch(uint256 currentEpochIndex) external override {
        ensureCurrentEpochCanBeClosed(currentEpochIndex);
        _tournament = _TOURNAMENT_FACTORY.instantiate(_getPreEpochStateRoot(), this);
        _closeCurrentEpoch(address(_tournament));
    }

    function finalizeCurrentEpoch(
        uint256 currentEpochIndex,
        bytes32 postEpochOutputsRoot,
        bytes32[] calldata proof
    ) external override {
        bytes32 postEpochStateRoot;
        postEpochStateRoot = _preFinalize(currentEpochIndex, postEpochOutputsRoot, proof);
        _lastFinalizedPostEpochStateRoot = Machine.Hash.wrap(postEpochStateRoot);
        _finalizeCurrentEpoch(postEpochStateRoot, postEpochOutputsRoot);
    }

    function provideMerkleRootOfInput(uint256 inputIndexWithinEpoch, bytes calldata)
        external
        view
        override
        returns (bytes32)
    {
        uint256 inputIndex = _getInputIndexInclusiveLowerBound() + inputIndexWithinEpoch;

        if (inputIndex >= _getInputIndexExclusiveUpperBound()) {
            // out-of-bounds index: repeat the state (as a fixpoint function)
            return bytes32(0);
        }

        return _getInputMerkleRoot(inputIndex);
    }

    function _isPostEpochStateRootValid(bytes32 postEpochStateRoot)
        internal
        view
        override
        returns (bool)
    {
        bool isFinished;
        Machine.Hash finalMachineStateHash;
        (isFinished,, finalMachineStateHash) = _tournament.arbitrationResult();
        bytes32 validPostEpochStateRoot = Machine.Hash.unwrap(finalMachineStateHash);
        return isFinished && postEpochStateRoot == validPostEpochStateRoot;
    }

    /// @notice Get the pre-epoch state root.
    function _getPreEpochStateRoot() internal view returns (Machine.Hash) {
        if (getCurrentEpochIndex() == 0) {
            return _getGenesisStateRoot();
        } else {
            return _lastFinalizedPostEpochStateRoot;
        }
    }

    /// @notice Get the Merkle root of an input by its index.
    /// @param inputIndex The input index
    function _getInputMerkleRoot(uint256 inputIndex)
        internal
        view
        virtual
        returns (bytes32);

    /// @notice Get the genesis state root.
    function _getGenesisStateRoot() internal view virtual returns (Machine.Hash);
}

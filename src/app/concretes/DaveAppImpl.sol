// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {IDataProvider} from "prt-contracts/IDataProvider.sol";
import {ITournamentFactory} from "prt-contracts/ITournamentFactory.sol";
import {ITournament} from "prt-contracts/ITournament.sol";
import {Machine} from "prt-contracts/types/Machine.sol";

import {DaveApp} from "../interfaces/DaveApp.sol";
import {OutboxImpl} from "../abstracts/OutboxImpl.sol";
import {TokenReceiverImpl} from "../abstracts/TokenReceiverImpl.sol";

contract DaveAppImpl is DaveApp, OutboxImpl, TokenReceiverImpl {
    bytes32 immutable _GENESIS_STATE_ROOT;
    ITournamentFactory immutable _TOURNAMENT_FACTORY;

    ITournament private _tournament;
    Machine.Hash private _preEpochStateRoot;

    /// @notice Constructs the DaveAppImpl contract
    /// @param genesisStateRoot The genesis state root
    /// @param tournamentFactory The tournament factory
    constructor(bytes32 genesisStateRoot, ITournamentFactory tournamentFactory) {
        _GENESIS_STATE_ROOT = genesisStateRoot;
        _TOURNAMENT_FACTORY = tournamentFactory;
        _preEpochStateRoot = Machine.Hash.wrap(genesisStateRoot);
    }

    function getGenesisStateRoot()
        public
        view
        override
        returns (bytes32 genesisStateRoot)
    {
        return _GENESIS_STATE_ROOT;
    }

    function getEpochFinalizerInterfaceId() external pure override returns (bytes4) {
        return type(ITournament).interfaceId;
    }

    function closeEpoch(uint256 epochIndex) external override {
        canEpochBeClosed(epochIndex);
        _tournament = _TOURNAMENT_FACTORY.instantiate(_preEpochStateRoot, this);
        _closeEpoch(address(_tournament));
    }

    function finalizeEpoch(
        uint256 epochIndex,
        bytes32 postEpochOutputsRoot,
        bytes32[] calldata proof
    ) external override {
        bytes32 postEpochStateRoot;
        postEpochStateRoot = _preFinalize(epochIndex, postEpochOutputsRoot, proof);
        _preEpochStateRoot = Machine.Hash.wrap(postEpochStateRoot);
        _finalizeEpoch(postEpochStateRoot, postEpochOutputsRoot);
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

        return getInputMerkleRoot(inputIndex);
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
}

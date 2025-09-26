// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {ITournamentFactory} from "prt-contracts/ITournamentFactory.sol";
import {Machine} from "prt-contracts/types/Machine.sol";

import {DaveApp} from "../interfaces/DaveApp.sol";
import {DaveImpl} from "../abstracts/DaveImpl.sol";
import {InboxImpl} from "../abstracts/InboxImpl.sol";
import {OutboxImpl} from "../abstracts/OutboxImpl.sol";
import {TokenReceiverImpl} from "../abstracts/TokenReceiverImpl.sol";

contract DaveAppImpl is DaveApp, DaveImpl, InboxImpl, OutboxImpl, TokenReceiverImpl {
    bytes32 immutable _GENESIS_STATE_ROOT;

    /// @notice Constructs the DaveAppImpl contract
    /// @param genesisStateRoot The genesis state root
    /// @param tournamentFactory The tournament factory
    constructor(bytes32 genesisStateRoot, ITournamentFactory tournamentFactory)
        DaveImpl(tournamentFactory)
    {
        _GENESIS_STATE_ROOT = genesisStateRoot;
    }

    function getGenesisStateRoot()
        public
        view
        override
        returns (bytes32 genesisStateRoot)
    {
        return _GENESIS_STATE_ROOT;
    }

    function _getGenesisStateRoot()
        internal
        view
        override
        returns (Machine.Hash genesisStateRoot)
    {
        return Machine.Hash.wrap(getGenesisStateRoot());
    }

    function _getNumberOfInputsBeforeCurrentBlock()
        internal
        view
        override
        returns (uint256)
    {
        return getNumberOfInputsBeforeCurrentBlock();
    }

    function _getInputMerkleRoot(uint256 inputIndex)
        internal
        view
        override
        returns (bytes32)
    {
        return getInputMerkleRoot(inputIndex);
    }

    function _isOutputsRootFinal(bytes32 outputsRoot)
        internal
        view
        override
        returns (bool)
    {
        return isOutputsRootFinal(outputsRoot);
    }
}

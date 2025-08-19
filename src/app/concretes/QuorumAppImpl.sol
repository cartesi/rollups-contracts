// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {App} from "../interfaces/App.sol";
import {QuorumImpl} from "../abstracts/QuorumImpl.sol";
import {InboxImpl} from "../abstracts/InboxImpl.sol";
import {OutboxImpl} from "../abstracts/OutboxImpl.sol";
import {TokenReceiverImpl} from "../abstracts/TokenReceiverImpl.sol";

contract QuorumAppImpl is App, QuorumImpl, InboxImpl, OutboxImpl, TokenReceiverImpl {
    uint256 immutable _DEPLOYMENT_BLOCK_NUMBER = block.number;
    bytes32 immutable _GENESIS_STATE_ROOT;

    /// @notice Constructs the QuorumAppImpl contract
    /// @param genesisStateRoot The genesis state root
    /// @param validators The validators array
    constructor(bytes32 genesisStateRoot, address[] memory validators)
        QuorumImpl(validators)
    {
        _GENESIS_STATE_ROOT = genesisStateRoot;
    }

    function getDeploymentBlockNumber()
        external
        view
        override
        returns (uint256 deploymentBlockNumber)
    {
        return _DEPLOYMENT_BLOCK_NUMBER;
    }

    function getGenesisStateRoot()
        public
        view
        override
        returns (bytes32 genesisStateRoot)
    {
        return _GENESIS_STATE_ROOT;
    }

    function _getNumberOfInputsBeforeCurrentBlock()
        internal
        view
        override
        returns (uint256)
    {
        return getNumberOfInputsBeforeCurrentBlock();
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

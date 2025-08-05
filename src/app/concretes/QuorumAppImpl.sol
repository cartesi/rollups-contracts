// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {Clones} from "@openzeppelin-contracts-5.2.0/proxy/Clones.sol";

import {App} from "../interfaces/App.sol";
import {QuorumImpl} from "../abstracts/QuorumImpl.sol";
import {InboxImpl} from "../abstracts/InboxImpl.sol";
import {OutboxImpl} from "../abstracts/OutboxImpl.sol";

contract QuorumAppImpl is App, QuorumImpl, InboxImpl, OutboxImpl {
    using Clones for address;

    /// @notice Arguments embedded in the contract's bytecode.
    /// @param deploymentBlockNumber The deployment block number
    /// @param genesisStateRoot The genesis state root
    struct Args {
        uint256 deploymentBlockNumber;
        bytes32 genesisStateRoot;
    }

    /// @notice Get the contract arguments.
    function _getArgs() internal view returns (Args memory) {
        return abi.decode(address(this).fetchCloneArgs(), (Args));
    }

    function getDeploymentBlockNumber()
        external
        view
        override
        returns (uint256 deploymentBlockNumber)
    {
        return _getArgs().deploymentBlockNumber;
    }

    function getGenesisStateRoot()
        public
        view
        override
        returns (bytes32 genesisStateRoot)
    {
        return _getArgs().genesisStateRoot;
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

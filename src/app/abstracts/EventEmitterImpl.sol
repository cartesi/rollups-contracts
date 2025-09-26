// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {EventEmitter} from "../interfaces/EventEmitter.sol";

abstract contract EventEmitterImpl is EventEmitter {
    uint256 private immutable _DEPLOYMENT_BLOCK_NUMBER = block.number;

    function getDeploymentBlockNumber()
        public
        view
        override
        returns (uint256 deploymentBlockNumber)
    {
        return _DEPLOYMENT_BLOCK_NUMBER;
    }
}

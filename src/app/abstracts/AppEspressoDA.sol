// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {IAppDA} from "../interfaces/IAppDA.sol";

abstract contract AppEspressoDA is IAppDA {
    /// @inheritdoc IAppDA
    function getDataAvailabilitySources()
        external
        pure
        override
        returns (string[] memory daSources)
    {
        daSources = new string[](2);
        daSources[0] = "Espresso";
        daSources[1] = "Ethereum";
    }
}

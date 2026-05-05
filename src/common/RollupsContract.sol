// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.26;

import {IVersionGetter} from "./IVersionGetter.sol";

abstract contract RollupsContract is IVersionGetter {
    function version()
        external
        pure
        override
        returns (
            uint64 major,
            uint64 minor,
            uint64 patch,
            string memory preRelease,
            string memory buildMetadata
        )
    {
        major = 3;
        minor = 0;
        patch = 0;
        preRelease = "alpha.4";
        buildMetadata = "";
    }
}

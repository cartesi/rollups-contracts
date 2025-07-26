// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IAppMetadata} from "../interfaces/IAppMetadata.sol";
import {Metadata} from "../../common/Metadata.sol";

abstract contract AppMetadata is IAppMetadata {
    /// @inheritdoc IAppMetadata
    function getCartesiRollupsContractsMajorVersion()
        external
        pure
        override
        returns (uint256)
    {
        return Metadata.MAJOR_VERSION;
    }
}

// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IAppVersion} from "../interfaces/IAppVersion.sol";
import {Metadata} from "../../common/Metadata.sol";

abstract contract AppVersion is IAppVersion {
    /// @inheritdoc IAppVersion
    function getVersion() external pure override returns (uint256) {
        return Metadata.MAJOR_VERSION;
    }
}

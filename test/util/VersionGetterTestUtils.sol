// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {IVersionGetter} from "src/common/IVersionGetter.sol";
import "src/common/Version.sol" as Version;

abstract contract VersionGetterTestUtils is Test {
    function _testVersion(IVersionGetter versionGetter) internal view {
        uint64 major;
        uint64 minor;
        uint64 patch;
        string memory preRelease;
        string memory buildMetadata;

        (major, minor, patch, preRelease, buildMetadata) = versionGetter.version();

        assertEq(major, Version.MAJOR);
        assertEq(minor, Version.MINOR);
        assertEq(patch, Version.PATCH);
        assertEq(preRelease, Version.PRE_RELEASE);
        assertEq(buildMetadata, Version.BUILD_METADATA);
    }
}

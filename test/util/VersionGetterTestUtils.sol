// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {IVersionGetter} from "src/common/IVersionGetter.sol";

abstract contract VersionGetterTestUtils is Test {
    error InvalidPreRelease(string preRelease);
    error InvalidBuildMetadata(string buildMetadata);

    function _testVersion(IVersionGetter versionGetter) internal view {
        uint64 major;
        uint64 minor;
        uint64 patch;
        string memory preRelease;
        string memory buildMetadata;

        (major, minor, patch, preRelease, buildMetadata) = versionGetter.version();

        bytes memory preReleaseBytes = bytes(preRelease);
        bool isPreReleaseEmpty = preReleaseBytes.length == 0;

        require(
            isPreReleaseEmpty || _isPreReleaseValid(preReleaseBytes),
            InvalidPreRelease(preRelease)
        );

        bytes memory buildMetadataBytes = bytes(buildMetadata);
        bool isBuildMetadataEmpty = buildMetadataBytes.length == 0;

        require(
            isBuildMetadataEmpty || _isBuildMetadataValid(buildMetadataBytes),
            InvalidBuildMetadata(buildMetadata)
        );

        string memory reassembledVersion = string.concat(
            vm.toString(major),
            ".",
            vm.toString(minor),
            ".",
            vm.toString(patch),
            isPreReleaseEmpty ? "" : "-",
            preRelease,
            isBuildMetadataEmpty ? "" : "+",
            buildMetadata
        );

        // forge-lint: disable-next-line(unsafe-cheatcode)
        string memory packageJson = vm.readFile("package.json");
        string memory packageVersion = vm.parseJsonString(packageJson, ".version");

        assertEq(reassembledVersion, packageVersion, "package version");
    }

    // (?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*
    function _isPreReleaseValid(bytes memory preRelease)
        internal
        pure
        returns (bool isValid)
    {
        uint256 state;
        for (uint256 i; i < preRelease.length; ++i) {
            bytes1 char = preRelease[i];
            if (state == 0) {
                if (_isZero(char)) {
                    state = 1;
                } else if (_isPositiveDigit(char)) {
                    state = 2;
                } else if (_isAlphaOrHyphen(char)) {
                    state = 3;
                } else {
                    return false;
                }
            } else if (state == 1) {
                if (_isDot(char)) {
                    state = 0;
                } else if (_isAlphaOrHyphen(char)) {
                    state = 3;
                } else if (_isDigit(char)) {
                    state = 4;
                } else {
                    return false;
                }
            } else if (state == 2) {
                if (_isDot(char)) {
                    state = 0;
                } else if (_isDigit(char)) {
                    state = 2;
                } else if (_isAlphaOrHyphen(char)) {
                    state = 3;
                } else {
                    return false;
                }
            } else if (state == 3) {
                if (_isDot(char)) {
                    state = 0;
                } else if (_isAlphanumericOrHyphen(char)) {
                    state = 3;
                } else {
                    return false;
                }
            } else {
                assert(state == 4);
                if (_isAlphaOrHyphen(char)) {
                    state = 3;
                } else if (_isDigit(char)) {
                    state = 4;
                } else {
                    return false;
                }
            }
        }
        return state >= 1 && state <= 3;
    }

    // [0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*
    function _isBuildMetadataValid(bytes memory buildMetadata)
        internal
        pure
        returns (bool isValid)
    {
        uint256 state;
        for (uint256 i; i < buildMetadata.length; ++i) {
            bytes1 char = buildMetadata[i];
            if (state == 0) {
                if (_isAlphanumericOrHyphen(char)) {
                    state = 1;
                } else {
                    return false;
                }
            } else {
                assert(state == 1);
                if (_isAlphanumericOrHyphen(char)) {
                    state = 1;
                } else if (_isDot(char)) {
                    state = 0;
                } else {
                    return false;
                }
            }
        }
        return state == 1;
    }

    function _isAlphanumericOrHyphen(bytes1 char) internal pure returns (bool) {
        return _isAlphaOrHyphen(char) || _isDigit(char);
    }

    function _isDigit(bytes1 char) internal pure returns (bool) {
        return _isZero(char) || _isPositiveDigit(char);
    }

    function _isZero(bytes1 char) internal pure returns (bool) {
        return char == "0";
    }

    function _isPositiveDigit(bytes1 char) internal pure returns (bool) {
        return char >= "1" && char <= "9";
    }

    function _isAlphaOrHyphen(bytes1 char) internal pure returns (bool) {
        return (char >= "a" && char <= "z") || (char >= "A" && char <= "Z") || char == "-";
    }

    function _isDot(bytes1 char) internal pure returns (bool) {
        return char == ".";
    }
}

// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

function isDot(bytes1 char) pure returns (bool) {
    return char == ".";
}

function isZero(bytes1 char) pure returns (bool) {
    return char == "0";
}

function isNonZeroDigit(bytes1 char) pure returns (bool) {
    return char >= "1" && char <= "9";
}

function isDigit(bytes1 char) pure returns (bool) {
    return isZero(char) || isNonZeroDigit(char);
}

function isAlphaOrHyphen(bytes1 char) pure returns (bool) {
    return (char >= "a" && char <= "z") || (char >= "A" && char <= "Z") || char == "-";
}

function isAlphanumericOrHyphen(bytes1 char) pure returns (bool) {
    return isAlphaOrHyphen(char) || isDigit(char);
}

/// @notice Checks whether a byte array encodes a pre-release string.
/// @param preRelease The pre-release input byte array
/// @return Whether the pre-release string is valid.
/// @dev Matches ((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*)?
function isPreReleaseValid(bytes memory preRelease) pure returns (bool) {
    if (preRelease.length == 0) {
        return true;
    }
    uint256 state;
    for (uint256 offset; offset < preRelease.length; ++offset) {
        bytes1 char = preRelease[offset];
        if (state == 0) {
            if (isZero(char)) {
                state = 1;
            } else if (isNonZeroDigit(char)) {
                state = 2;
            } else if (isAlphaOrHyphen(char)) {
                state = 3;
            } else {
                return false;
            }
        } else if (state == 1) {
            if (isDot(char)) {
                state = 0;
            } else if (isAlphaOrHyphen(char)) {
                state = 3;
            } else if (isDigit(char)) {
                state = 4;
            } else {
                return false;
            }
        } else if (state == 2) {
            if (isDot(char)) {
                state = 0;
            } else if (isDigit(char)) {
                state = 2;
            } else if (isAlphaOrHyphen(char)) {
                state = 3;
            } else {
                return false;
            }
        } else if (state == 3) {
            if (isDot(char)) {
                state = 0;
            } else if (isAlphanumericOrHyphen(char)) {
                state = 3;
            } else {
                return false;
            }
        } else {
            assert(state == 4);
            if (isAlphaOrHyphen(char)) {
                state = 3;
            } else if (isDigit(char)) {
                state = 4;
            } else {
                return false;
            }
        }
    }
    assert(state <= 4);
    return state >= 1 && state <= 3;
}

/// @notice Checks whether a byte array encodes a build-metadata string.
/// @param buildMetadata The build-metadata input byte array
/// @return Whether the build-metadata string is valid.
/// @dev Matches ([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*)?
function isBuildMetadataValid(bytes memory buildMetadata) pure returns (bool) {
    if (buildMetadata.length == 0) {
        return true;
    }
    uint256 state;
    for (uint256 offset; offset < buildMetadata.length; ++offset) {
        bytes1 char = buildMetadata[offset];
        if (state == 0) {
            if (isAlphanumericOrHyphen(char)) {
                state = 1;
            } else {
                return false;
            }
        } else {
            assert(state == 1);
            if (isAlphanumericOrHyphen(char)) {
                state = 1;
            } else if (isDot(char)) {
                state = 0;
            } else {
                return false;
            }
        }
    }
    assert(state <= 1);
    return state == 1;
}

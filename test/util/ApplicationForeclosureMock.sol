// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

contract ApplicationForeclosureMock {
    bool public isForeclosed;

    function foreclose() external {
        isForeclosed = true;
    }
}

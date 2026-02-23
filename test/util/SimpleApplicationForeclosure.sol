// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {IApplicationForeclosure} from "src/dapp/IApplicationForeclosure.sol";

contract SimpleApplicationForeclosure is IApplicationForeclosure {
    address immutable GUARDIAN;
    bool public isForeclosed;

    constructor(address guardian) {
        GUARDIAN = guardian;
    }

    function foreclose() external override {
        require(msg.sender == getGuardian(), NotGuardian());
        isForeclosed = true;
        emit Foreclosure();
    }

    function getGuardian() public view override returns (address) {
        return GUARDIAN;
    }
}

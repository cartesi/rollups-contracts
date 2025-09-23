// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.10.0/src/Test.sol";

import {LibError} from "src/library/LibError.sol";

interface IErrorRaiser {
    function raise(bytes calldata error) external;
}

contract ErrorRaiser is IErrorRaiser {
    function raise(bytes calldata error) external pure override {
        LibError.raise(error);
    }
}

contract LibErrorTest is Test {
    IErrorRaiser _errorRaiser;

    function setUp() external {
        _errorRaiser = new ErrorRaiser();
    }

    function testRaise(bytes calldata error) external {
        vm.expectRevert(error);
        _errorRaiser.raise(error);
    }
}

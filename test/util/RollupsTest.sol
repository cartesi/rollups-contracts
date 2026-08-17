// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import "../../script/utils/CoreContracts.sol" as CoreContracts;
import "../../script/utils/DevContracts.sol" as DevContracts;

struct ContractSuites {
    CoreContracts.Suite core;
    DevContracts.Suite dev;
}

abstract contract RollupsTest is Test {
    /// @notice Core and dev contracts deployed deterministically.
    ContractSuites _contracts;

    /// @notice This error can be raised by tests that check logs emitted by non-view
    /// function calls, either because the log emitter or topic #0 were unexpected. Logs
    /// can be obtained via the recordLogs/getRecordedLogs cheatcode pair.
    /// @param log The unexpected EVM log
    error UnexpectedLog(Vm.Log log);

    /// @notice This error can be raised by tests that check errors raised by functions
    /// calls because the event selector was unexpected. Errors can be caught through
    /// try-catch blocks in Solidity and handled through byte manipulation libraries
    /// and Solidity's native ABI decoding capabilities.
    /// @param errorData The unexpected error encoded according to Solidity ABI
    error UnexpectedError(bytes errorData);

    constructor() {
        // We ensure the CREATE2 factory is deployed so that we can deploy the core and
        // dev contracts deterministically. We do so through the "etch" Forge cheatcode.
        // This is only necessary in local Forge tests and fork tests for networks in
        // which the CREATE2 factory might not be already deployed (but could be easily
        // done so by funding the deployer address and submitting a legacy tx). Some
        // networks might not support legacy transactions, in which case an alternative
        // CREATE2 factory must be used instead.
        if (CREATE2_FACTORY.code.length == 0) {
            vm.etch(
                CREATE2_FACTORY,
                bytes.concat(
                    hex"7fffffffffffffffffffffffffffffffffffffffffffff",
                    hex"ffffffffffffffffffe036016000816020823780358282",
                    hex"34f58015156039578182fd5b8082525050506014600cf3"
                )
            );
        }

        _contracts.core = CoreContracts.deploy();
        _contracts.dev = DevContracts.deploy(_contracts.core);
    }
}

// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Outputs} from "../common/Outputs.sol";
import {Voucher} from "../common/Voucher.sol";

library LibVoucher {
    /// @notice Encode a voucher as an output.
    /// @param v The voucher
    /// @return output The encoded voucher
    function encode(Voucher memory v) internal pure returns (bytes memory output) {
        return abi.encodeCall(Outputs.Voucher, (v.destination, v.value, v.payload));
    }
}

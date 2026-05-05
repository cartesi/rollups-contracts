// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {DelegateCallVoucher} from "../common/DelegateCallVoucher.sol";
import {Outputs} from "../common/Outputs.sol";

library LibDelegateCallVoucher {
    /// @notice Encode a delegate-call voucher as an output.
    /// @param v The delegate-call voucher
    /// @return output The encoded delegate-call voucher
    function encode(DelegateCallVoucher memory v)
        internal
        pure
        returns (bytes memory output)
    {
        return abi.encodeCall(Outputs.DelegateCallVoucher, (v.destination, v.payload));
    }
}

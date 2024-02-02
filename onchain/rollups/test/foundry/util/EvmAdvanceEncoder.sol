// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title EVM Advance Encoder
pragma solidity ^0.8.22;

import {Inputs} from "contracts/common/Inputs.sol";

library EvmAdvanceEncoder {
    function encode(
        uint256 chainId,
        address app,
        address sender,
        uint256 index,
        bytes memory payload
    ) internal view returns (bytes memory) {
        return
            abi.encodeCall(
                Inputs.EvmAdvance,
                (
                    chainId,
                    app,
                    sender,
                    block.number,
                    block.timestamp,
                    index,
                    payload
                )
            );
    }
}

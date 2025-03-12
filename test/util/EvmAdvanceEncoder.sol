// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title EVM Advance Encoder
pragma solidity ^0.8.22;

import {Inputs} from "src/common/Inputs.sol";

library EvmAdvanceEncoder {
    function encode(
        uint256 chainId,
        address appContract,
        address sender,
        uint256 index,
        bytes memory payload
    ) internal view returns (bytes memory) {
        return abi.encodeCall(
            Inputs.EvmAdvance,
            (
                chainId,
                appContract,
                sender,
                block.number,
                block.timestamp,
                block.prevrandao,
                index,
                payload
            )
        );
    }
}

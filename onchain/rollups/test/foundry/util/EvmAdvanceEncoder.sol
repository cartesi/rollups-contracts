// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title EVM Advance Encoder
pragma solidity ^0.8.8;

import {Inputs} from "contracts/common/Inputs.sol";

library EvmAdvanceEncoder {
    function encode(
        address _sender,
        uint256 _index,
        bytes memory _payload
    ) internal view returns (bytes memory) {
        return
            abi.encodeCall(
                Inputs.EvmAdvance,
                (_sender, block.number, block.timestamp, _index, _payload)
            );
    }
}

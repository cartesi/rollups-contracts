// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {LibMath} from "./LibMath.sol";

library LibBytes {
    using LibMath for uint256;

    /// @notice Get a data block by index and log2 size.
    /// @param data the data byte array
    /// @param index the data block index
    /// @param log2DataBlockSize the log2 of the data block size
    /// @dev Data blocks are right-padded with zeros if necessary.
    function getBlock(bytes memory data, uint256 index, uint256 log2DataBlockSize)
        internal
        pure
        returns (bytes memory dataBlock)
    {
        dataBlock = new bytes(1 << log2DataBlockSize);
        uint256 start = index << log2DataBlockSize;
        if (start < data.length) {
            uint256 end = data.length.min(start + dataBlock.length);
            assembly {
                mcopy(add(dataBlock, 0x20), add(add(data, 0x20), start), sub(end, start))
            }
        }
    }
}

// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Erc1155BatchDeposit} from "../../src/common/Erc1155BatchDeposit.sol";
import {Erc1155SingleDeposit} from "../../src/common/Erc1155SingleDeposit.sol";
import {Erc20Deposit} from "../../src/common/Erc20Deposit.sol";
import {Erc721Deposit} from "../../src/common/Erc721Deposit.sol";
import {EtherDeposit} from "../../src/common/EtherDeposit.sol";
import {InputEncoding} from "../../src/common/InputEncoding.sol";

library LibDepositEncoder {
    /// @notice Extra data not present in deposit structures.
    /// @param baseLayerData Base-layer data
    /// @param execLayerData Execution-layer data
    /// @dev Ether and ERC-20 deposits don't use the base-layer data.
    struct ExtraData {
        bytes baseLayerData;
        bytes execLayerData;
    }

    function encode(EtherDeposit calldata deposit, ExtraData calldata extraData)
        external
        pure
        returns (bytes memory payload)
    {
        return InputEncoding.encodeEtherDeposit(
            deposit.sender, deposit.value, extraData.execLayerData
        );
    }

    function encode(Erc20Deposit calldata deposit, ExtraData calldata extraData)
        external
        pure
        returns (bytes memory payload)
    {
        return InputEncoding.encodeErc20Deposit(
            deposit.token, deposit.sender, deposit.value, extraData.execLayerData
        );
    }

    function encode(Erc721Deposit calldata deposit, ExtraData calldata extraData)
        external
        pure
        returns (bytes memory payload)
    {
        return InputEncoding.encodeErc721Deposit(
            deposit.token,
            deposit.sender,
            deposit.tokenId,
            extraData.baseLayerData,
            extraData.execLayerData
        );
    }

    function encode(Erc1155SingleDeposit calldata deposit, ExtraData calldata extraData)
        external
        pure
        returns (bytes memory payload)
    {
        return InputEncoding.encodeSingleErc1155Deposit(
            deposit.token,
            deposit.sender,
            deposit.tokenId,
            deposit.value,
            extraData.baseLayerData,
            extraData.execLayerData
        );
    }

    function encode(Erc1155BatchDeposit calldata deposit, ExtraData calldata extraData)
        external
        pure
        returns (bytes memory payload)
    {
        return InputEncoding.encodeBatchErc1155Deposit(
            deposit.token,
            deposit.sender,
            deposit.tokenIds,
            deposit.values,
            extraData.baseLayerData,
            extraData.execLayerData
        );
    }
}

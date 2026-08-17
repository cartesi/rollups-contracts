// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Erc1155BatchDeposit} from "../../src/common/Erc1155BatchDeposit.sol";
import {Erc1155SingleDeposit} from "../../src/common/Erc1155SingleDeposit.sol";
import {Erc20Deposit} from "../../src/common/Erc20Deposit.sol";
import {Erc721Deposit} from "../../src/common/Erc721Deposit.sol";
import {EtherDeposit} from "../../src/common/EtherDeposit.sol";
import {InputEncoding} from "../../src/common/InputEncoding.sol";

library LibDepositDecoder {
    function decodeEtherDeposit(bytes calldata payload)
        external
        pure
        returns (EtherDeposit memory deposit)
    {
        return InputEncoding.decodeEtherDeposit(payload);
    }

    function decodeErc20Deposit(bytes calldata payload)
        external
        pure
        returns (Erc20Deposit memory deposit)
    {
        return InputEncoding.decodeErc20Deposit(payload);
    }

    function decodeErc721Deposit(bytes calldata payload)
        external
        pure
        returns (Erc721Deposit memory deposit)
    {
        return InputEncoding.decodeErc721Deposit(payload);
    }

    function decodeErc1155SingleDeposit(bytes calldata payload)
        external
        pure
        returns (Erc1155SingleDeposit memory deposit)
    {
        return InputEncoding.decodeErc1155SingleDeposit(payload);
    }

    function decodeErc1155BatchDeposit(bytes calldata payload)
        external
        pure
        returns (Erc1155BatchDeposit memory deposit)
    {
        return InputEncoding.decodeErc1155BatchDeposit(payload);
    }
}

// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {Erc1155BatchDeposit} from "../../src/common/Erc1155BatchDeposit.sol";
import {Erc1155SingleDeposit} from "../../src/common/Erc1155SingleDeposit.sol";
import {Erc20Deposit} from "../../src/common/Erc20Deposit.sol";
import {Erc721Deposit} from "../../src/common/Erc721Deposit.sol";
import {EtherDeposit} from "../../src/common/EtherDeposit.sol";

import {LibDepositDecoder} from "../util/LibDepositDecoder.sol";
import {LibDepositEncoder} from "../util/LibDepositEncoder.sol";

contract InputEncodingTest is Test {
    using LibDepositEncoder for EtherDeposit;
    using LibDepositEncoder for Erc20Deposit;
    using LibDepositEncoder for Erc721Deposit;
    using LibDepositEncoder for Erc1155SingleDeposit;
    using LibDepositEncoder for Erc1155BatchDeposit;
    using LibDepositDecoder for bytes;

    function testEtherDeposit(
        EtherDeposit calldata deposit,
        LibDepositEncoder.ExtraData calldata extraData
    ) external pure {
        assertEq(
            abi.encode(deposit),
            abi.encode(deposit.encode(extraData).decodeEtherDeposit())
        );
    }

    function testErc20Deposit(
        Erc20Deposit calldata deposit,
        LibDepositEncoder.ExtraData calldata extraData
    ) external pure {
        assertEq(
            abi.encode(deposit),
            abi.encode(deposit.encode(extraData).decodeErc20Deposit())
        );
    }

    function testErc721Deposit(
        Erc721Deposit calldata deposit,
        LibDepositEncoder.ExtraData calldata extraData
    ) external pure {
        assertEq(
            abi.encode(deposit),
            abi.encode(deposit.encode(extraData).decodeErc721Deposit())
        );
    }

    function testErc1155SingleDeposit(
        Erc1155SingleDeposit calldata deposit,
        LibDepositEncoder.ExtraData calldata extraData
    ) external pure {
        assertEq(
            abi.encode(deposit),
            abi.encode(deposit.encode(extraData).decodeErc1155SingleDeposit())
        );
    }

    function testErc1155BatchDeposit(
        Erc1155BatchDeposit calldata deposit,
        LibDepositEncoder.ExtraData calldata extraData
    ) external pure {
        assertEq(
            abi.encode(deposit),
            abi.encode(deposit.encode(extraData).decodeErc1155BatchDeposit())
        );
    }
}

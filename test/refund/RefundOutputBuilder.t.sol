// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {IERC1155} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155.sol";
import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

import {Erc1155BatchDeposit} from "src/common/Erc1155BatchDeposit.sol";
import {Erc1155SingleDeposit} from "src/common/Erc1155SingleDeposit.sol";
import {Erc20Deposit} from "src/common/Erc20Deposit.sol";
import {Erc721Deposit} from "src/common/Erc721Deposit.sol";
import {EtherDeposit} from "src/common/EtherDeposit.sol";
import {Outputs} from "src/common/Outputs.sol";
import {ISafeERC20Transfer} from "src/delegatecall/ISafeERC20Transfer.sol";
import {LibBytes} from "src/library/LibBytes.sol";
import {IERC1155BatchPortal} from "src/portals/IERC1155BatchPortal.sol";
import {IERC1155SinglePortal} from "src/portals/IERC1155SinglePortal.sol";
import {IERC20Portal} from "src/portals/IERC20Portal.sol";
import {IERC721Portal} from "src/portals/IERC721Portal.sol";
import {IEtherPortal} from "src/portals/IEtherPortal.sol";
import {IRefundOutputBuilder} from "src/refund/IRefundOutputBuilder.sol";
import {IRefundOutputBuilderErrors} from "src/refund/IRefundOutputBuilderErrors.sol";

import {InputBoxTestUtils} from "../util/InputBoxTestUtils.sol";
import {LibAddressArray} from "../util/LibAddressArray.sol";
import {LibDepositEncoder} from "../util/LibDepositEncoder.sol";
import {RollupsTest} from "../util/RollupsTest.sol";
import {VersionGetterTestUtils} from "../util/VersionGetterTestUtils.sol";

contract RefundOutputBuilderTest is
    RollupsTest,
    InputBoxTestUtils,
    VersionGetterTestUtils
{
    using LibBytes for bytes;
    using LibAddressArray for Vm;
    using LibDepositEncoder for EtherDeposit;
    using LibDepositEncoder for Erc20Deposit;
    using LibDepositEncoder for Erc721Deposit;
    using LibDepositEncoder for Erc1155SingleDeposit;
    using LibDepositEncoder for Erc1155BatchDeposit;

    IEtherPortal _etherPortal;
    IERC20Portal _erc20Portal;
    IERC721Portal _erc721Portal;
    IERC1155SinglePortal _erc1155SinglePortal;
    IERC1155BatchPortal _erc1155BatchPortal;
    ISafeERC20Transfer _safeErc20Transfer;
    IRefundOutputBuilder _refundOutputBuilder;

    function setUp() external {
        _etherPortal = _contracts.core.etherPortal;
        _erc20Portal = _contracts.core.erc20Portal;
        _erc721Portal = _contracts.core.erc721Portal;
        _erc1155SinglePortal = _contracts.core.erc1155SinglePortal;
        _erc1155BatchPortal = _contracts.core.erc1155BatchPortal;
        _safeErc20Transfer = _contracts.core.safeErc20Transfer;
        _refundOutputBuilder = _contracts.core.refundOutputBuilder;
    }

    function testVersion() external view {
        _testVersion(_refundOutputBuilder);
    }

    function testBuildRefundOutputRevertsUnknownInputSender(bytes calldata inputPayload)
        external
    {
        address appContract = _newActiveAppMock();

        address[] memory portalAddresses = new address[](5);
        portalAddresses[0] = address(_etherPortal);
        portalAddresses[1] = address(_erc20Portal);
        portalAddresses[2] = address(_erc721Portal);
        portalAddresses[3] = address(_erc1155SinglePortal);
        portalAddresses[4] = address(_erc1155BatchPortal);

        address inputSender = vm.randomAddressNotIn(portalAddresses);

        vm.prank(vm.randomAddress());
        vm.expectRevert(_encodeUnknownInputSender(inputSender));
        _refundOutputBuilder.buildRefundOutput(appContract, inputSender, inputPayload);
    }

    function testBuildRefundOutputForEtherDeposit(
        EtherDeposit calldata deposit,
        LibDepositEncoder.ExtraData calldata extraData
    ) external {
        address appContract = _newActiveAppMock();

        vm.prank(vm.randomAddress());
        bytes memory output = _refundOutputBuilder.buildRefundOutput(
            appContract,
            address(_etherPortal), // inputSender
            deposit.encode(extraData) // inputPayload
        );

        (bool isOutput, bytes4 sel, bytes memory args) = output.consumeBytes4();
        assertTrue(isOutput, "is output");
        assertEq(sel, Outputs.Voucher.selector, "is voucher");

        address destination;
        uint256 value;
        bytes memory payload;
        (destination, value, payload) = abi.decode(args, (address, uint256, bytes));
        assertEq(destination, deposit.sender, "voucher destination");
        assertEq(value, deposit.value, "voucher value");
        assertEq(payload.length, 0, "voucher payload length");
    }

    function testBuildRefundOutputForIllFormedEtherDeposit(
        address appContract,
        bytes calldata inputPayload
    ) external {
        vm.assume(inputPayload.length < 52);
        vm.expectRevert();
        vm.prank(vm.randomAddress());
        _refundOutputBuilder.buildRefundOutput(
            appContract, address(_etherPortal), inputPayload
        );
    }

    function testBuildRefundOutputForErc20Deposit(
        Erc20Deposit calldata deposit,
        LibDepositEncoder.ExtraData calldata extraData
    ) external {
        address appContract = _newActiveAppMock();

        vm.prank(vm.randomAddress());
        bytes memory output = _refundOutputBuilder.buildRefundOutput(
            appContract,
            address(_erc20Portal), // inputSender
            deposit.encode(extraData) // inputPayload
        );

        (bool isOutput, bytes4 sel, bytes memory args) = output.consumeBytes4();
        assertTrue(isOutput, "is output");
        assertEq(sel, Outputs.DelegateCallVoucher.selector, "is delegate-call voucher");

        address destination;
        bytes memory payload;
        (destination, payload) = abi.decode(args, (address, bytes));
        assertEq(destination, address(_safeErc20Transfer), "voucher destination");

        (bool isCall, bytes4 sel2, bytes memory args2) = payload.consumeBytes4();
        assertTrue(isCall, "is Solidity function call");
        assertEq(sel2, ISafeERC20Transfer.safeTransfer.selector, "call selector");

        IERC20 token;
        address to;
        uint256 value;
        (token, to, value) = abi.decode(args2, (IERC20, address, uint256));
        assertEq(address(token), address(deposit.token), "transfer token");
        assertEq(to, deposit.sender, "transfer destination");
        assertEq(value, deposit.value, "transfer value");
    }

    function testBuildRefundOutputForIllFormedErc20Deposit(
        address appContract,
        bytes calldata inputPayload
    ) external {
        vm.assume(inputPayload.length < 72);
        vm.expectRevert();
        vm.prank(vm.randomAddress());
        _refundOutputBuilder.buildRefundOutput(
            appContract, address(_erc20Portal), inputPayload
        );
    }

    function testBuildRefundOutputForErc721Deposit(
        Erc721Deposit calldata deposit,
        LibDepositEncoder.ExtraData calldata extraData
    ) external {
        address appContract = _newActiveAppMock();

        vm.prank(vm.randomAddress());
        bytes memory output = _refundOutputBuilder.buildRefundOutput(
            appContract,
            address(_erc721Portal), // inputSender
            deposit.encode(extraData) // inputPayload
        );

        (bool isOutput, bytes4 sel, bytes memory args) = output.consumeBytes4();
        assertTrue(isOutput, "is output");
        assertEq(sel, Outputs.Voucher.selector, "is voucher");

        address destination;
        uint256 value;
        bytes memory payload;
        (destination, value, payload) = abi.decode(args, (address, uint256, bytes));
        assertEq(destination, address(deposit.token), "voucher destination");
        assertEq(value, 0, "voucher value");

        (bool isCall, bytes4 sel2, bytes memory args2) = payload.consumeBytes4();
        assertTrue(isCall, "is Solidity function call");
        assertEq(sel2, bytes4(keccak256("safeTransferFrom(address,address,uint256)")));

        address from;
        address to;
        uint256 tokenId;
        (from, to, tokenId) = abi.decode(args2, (address, address, uint256));
        assertEq(from, appContract, "transfer origin");
        assertEq(to, deposit.sender, "transfer destination");
        assertEq(tokenId, deposit.tokenId, "transfer token ID");
    }

    function testBuildRefundOutputForIllFormedErc721Deposit(
        address appContract,
        bytes calldata inputPayload
    ) external {
        vm.assume(inputPayload.length < 72);
        vm.expectRevert();
        vm.prank(vm.randomAddress());
        _refundOutputBuilder.buildRefundOutput(
            appContract, address(_erc721Portal), inputPayload
        );
    }

    function testBuildRefundOutputForErc1155SingleDeposit(
        Erc1155SingleDeposit calldata deposit,
        LibDepositEncoder.ExtraData calldata extraData
    ) external {
        address appContract = _newActiveAppMock();

        vm.prank(vm.randomAddress());
        bytes memory output = _refundOutputBuilder.buildRefundOutput(
            appContract,
            address(_erc1155SinglePortal), // inputSender
            deposit.encode(extraData) // inputPayload
        );

        (bool isOutput, bytes4 sel, bytes memory args) = output.consumeBytes4();
        assertTrue(isOutput, "is output");
        assertEq(sel, Outputs.Voucher.selector, "is voucher");

        address destination;
        uint256 value;
        bytes memory payload;
        (destination, value, payload) = abi.decode(args, (address, uint256, bytes));
        assertEq(destination, address(deposit.token), "voucher destination");
        assertEq(value, 0, "voucher value");

        (bool isCall, bytes4 sel2, bytes memory args2) = payload.consumeBytes4();
        assertTrue(isCall, "is Solidity function call");
        assertEq(sel2, IERC1155.safeTransferFrom.selector);

        address from;
        address to;
        uint256 tokenId;
        uint256 depositValue;
        bytes memory data;
        (from, to, tokenId, depositValue, data) =
            abi.decode(args2, (address, address, uint256, uint256, bytes));
        assertEq(from, appContract, "transfer origin");
        assertEq(to, deposit.sender, "transfer destination");
        assertEq(tokenId, deposit.tokenId, "transfer token ID");
        assertEq(depositValue, deposit.value, "transfer value");
        assertEq(data, new bytes(0), "transfer extra data");
    }

    function testBuildRefundOutputForIllFormedErc1155SingleDeposit(
        address appContract,
        bytes calldata inputPayload
    ) external {
        vm.assume(inputPayload.length < 104);
        vm.expectRevert();
        vm.prank(vm.randomAddress());
        _refundOutputBuilder.buildRefundOutput(
            appContract, address(_erc1155SinglePortal), inputPayload
        );
    }

    function testBuildRefundOutputForErc1155BatchDeposit(
        Erc1155BatchDeposit calldata deposit,
        LibDepositEncoder.ExtraData calldata extraData
    ) external {
        address appContract = _newActiveAppMock();

        vm.prank(vm.randomAddress());
        bytes memory output = _refundOutputBuilder.buildRefundOutput(
            appContract,
            address(_erc1155BatchPortal), // inputSender
            deposit.encode(extraData) // inputPayload
        );

        (bool isOutput, bytes4 sel, bytes memory args) = output.consumeBytes4();
        assertTrue(isOutput, "is output");
        assertEq(sel, Outputs.Voucher.selector, "is voucher");

        address destination;
        uint256 value;
        bytes memory payload;
        (destination, value, payload) = abi.decode(args, (address, uint256, bytes));
        assertEq(destination, address(deposit.token), "voucher destination");
        assertEq(value, 0, "voucher value");

        (bool isCall, bytes4 sel2, bytes memory args2) = payload.consumeBytes4();
        assertTrue(isCall, "is Solidity function call");
        assertEq(sel2, IERC1155.safeBatchTransferFrom.selector);

        address from;
        address to;
        uint256[] memory tokenIds;
        uint256[] memory depositValues;
        bytes memory data;
        (from, to, tokenIds, depositValues, data) =
            abi.decode(args2, (address, address, uint256[], uint256[], bytes));
        assertEq(from, appContract, "transfer origin");
        assertEq(to, deposit.sender, "transfer destination");
        assertEq(tokenIds, deposit.tokenIds, "transfer token IDs");
        assertEq(depositValues, deposit.values, "transfer values");
        assertEq(data, new bytes(0), "transfer extra data");
    }

    function testBuildRefundOutputForIllFormedErc1155BatchDeposit(
        address appContract,
        bytes calldata inputPayload
    ) external {
        vm.assume(inputPayload.length < 40);
        vm.expectRevert();
        vm.prank(vm.randomAddress());
        _refundOutputBuilder.buildRefundOutput(
            appContract, address(_erc1155BatchPortal), inputPayload
        );
    }

    function _encodeUnknownInputSender(address inputSender)
        internal
        pure
        returns (bytes memory encodedError)
    {
        return abi.encodeWithSelector(
            IRefundOutputBuilderErrors.UnknownInputSender.selector, inputSender
        );
    }
}

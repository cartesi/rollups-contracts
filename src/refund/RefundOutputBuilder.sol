// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {DelegateCallVoucher} from "../common/DelegateCallVoucher.sol";
import {Erc1155BatchDeposit} from "../common/Erc1155BatchDeposit.sol";
import {Erc1155SingleDeposit} from "../common/Erc1155SingleDeposit.sol";
import {Erc20Deposit} from "../common/Erc20Deposit.sol";
import {Erc721Deposit} from "../common/Erc721Deposit.sol";
import {EtherDeposit} from "../common/EtherDeposit.sol";
import {InputEncoding} from "../common/InputEncoding.sol";
import {RollupsContract} from "../common/RollupsContract.sol";
import {Voucher} from "../common/Voucher.sol";
import {ISafeERC20Transfer} from "../delegatecall/ISafeERC20Transfer.sol";
import {LibDelegateCallVoucher} from "../library/LibDelegateCallVoucher.sol";
import {LibErc1155BatchDeposit} from "../library/LibErc1155BatchDeposit.sol";
import {LibErc1155SingleDeposit} from "../library/LibErc1155SingleDeposit.sol";
import {LibErc20Deposit} from "../library/LibErc20Deposit.sol";
import {LibErc721Deposit} from "../library/LibErc721Deposit.sol";
import {LibEtherDeposit} from "../library/LibEtherDeposit.sol";
import {LibVoucher} from "../library/LibVoucher.sol";
import {IERC1155BatchPortal} from "../portals/IERC1155BatchPortal.sol";
import {IERC1155SinglePortal} from "../portals/IERC1155SinglePortal.sol";
import {IERC20Portal} from "../portals/IERC20Portal.sol";
import {IERC721Portal} from "../portals/IERC721Portal.sol";
import {IEtherPortal} from "../portals/IEtherPortal.sol";
import {IRefundOutputBuilder} from "./IRefundOutputBuilder.sol";

contract RefundOutputBuilder is IRefundOutputBuilder, RollupsContract {
    using InputEncoding for bytes;
    using LibEtherDeposit for EtherDeposit;
    using LibErc20Deposit for Erc20Deposit;
    using LibErc721Deposit for Erc721Deposit;
    using LibErc1155BatchDeposit for Erc1155BatchDeposit;
    using LibErc1155SingleDeposit for Erc1155SingleDeposit;
    using LibVoucher for Voucher;
    using LibDelegateCallVoucher for DelegateCallVoucher;

    IEtherPortal immutable ETHER_PORTAL;
    IERC20Portal immutable ERC20_PORTAL;
    IERC721Portal immutable ERC721_PORTAL;
    IERC1155SinglePortal immutable ERC1155_SINGLE_PORTAL;
    IERC1155BatchPortal immutable ERC1155_BATCH_PORTAL;
    ISafeERC20Transfer immutable SAFE_TRANSFER;

    constructor(
        IEtherPortal etherPortal,
        IERC20Portal erc20Portal,
        IERC721Portal erc721Portal,
        IERC1155SinglePortal erc1155SinglePortal,
        IERC1155BatchPortal erc1155BatchPortal,
        ISafeERC20Transfer safeTransfer
    ) {
        ETHER_PORTAL = etherPortal;
        ERC20_PORTAL = erc20Portal;
        ERC721_PORTAL = erc721Portal;
        ERC1155_SINGLE_PORTAL = erc1155SinglePortal;
        ERC1155_BATCH_PORTAL = erc1155BatchPortal;
        SAFE_TRANSFER = safeTransfer;
    }

    function buildRefundOutput(
        address appContract,
        address inputSender,
        bytes calldata payload
    ) external view override returns (bytes memory output) {
        if (inputSender == address(ETHER_PORTAL)) {
            return payload.decodeEtherDeposit().buildRefund().encode();
        } else if (inputSender == address(ERC20_PORTAL)) {
            return payload.decodeErc20Deposit().buildRefund(SAFE_TRANSFER).encode();
        } else if (inputSender == address(ERC721_PORTAL)) {
            return payload.decodeErc721Deposit().buildRefund(appContract).encode();
        } else if (inputSender == address(ERC1155_SINGLE_PORTAL)) {
            return payload.decodeErc1155SingleDeposit().buildRefund(appContract).encode();
        } else if (inputSender == address(ERC1155_BATCH_PORTAL)) {
            return payload.decodeErc1155BatchDeposit().buildRefund(appContract).encode();
        } else {
            revert UnknownInputSender(inputSender);
        }
    }
}

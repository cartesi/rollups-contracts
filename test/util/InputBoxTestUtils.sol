// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {Inputs} from "src/common/Inputs.sol";
import {IInputBox} from "src/inputs/IInputBox.sol";

import {ApplicationCheckerTestUtils} from "./ApplicationCheckerTestUtils.sol";
import {LibBytes} from "./LibBytes.sol";
import {LibTopic} from "./LibTopic.sol";

contract InputBoxTestUtils is ApplicationCheckerTestUtils {
    using LibTopic for address;
    using LibBytes for bytes;

    function _addInputs(
        IInputBox inputBox,
        address appContract,
        bytes[] calldata payloads
    ) internal {
        for (uint256 i; i < payloads.length; ++i) {
            inputBox.addInput(appContract, payloads[i]);
        }
    }

    function _decodeInput(
        bytes memory input,
        address appContract,
        address sender,
        uint256 index
    ) internal view returns (bytes memory payloadArg) {
        (bytes4 inputSelector, bytes memory inputArgs) = input.consumeBytes4();
        assertEq(inputSelector, Inputs.EvmAdvance.selector);

        uint256 chainIdArg;
        address appContractArg;
        address msgSenderArg;
        uint256 blockNumberArg;
        uint256 blockTimestampArg;
        uint256 prevRandaoArg;
        uint256 indexArg;

        (
            chainIdArg,
            appContractArg,
            msgSenderArg,
            blockNumberArg,
            blockTimestampArg,
            prevRandaoArg,
            indexArg,
            payloadArg
        ) =
            abi.decode(
                inputArgs,
                (uint256, address, address, uint256, uint256, uint256, uint256, bytes)
            );

        assertEq(chainIdArg, block.chainid);
        assertEq(appContractArg, appContract);
        assertEq(msgSenderArg, sender);
        assertEq(blockNumberArg, vm.getBlockNumber());
        assertEq(blockTimestampArg, vm.getBlockTimestamp());
        assertEq(prevRandaoArg, block.prevrandao);
        assertEq(indexArg, index);
    }

    function _decodeInputAdded(
        Vm.Log memory log,
        address appContract,
        address sender,
        uint256 index
    ) internal view returns (bytes memory input, bytes memory payload) {
        require(log.topics.length >= 1, "unexpected InputBox annonymous event");
        require(
            log.topics[0] == IInputBox.InputAdded.selector,
            "unexpected selector of InputBox event"
        );
        assertEq(log.topics[1], appContract.asTopic());
        assertEq(log.topics[2], bytes32(index));
        (input) = abi.decode(log.data, (bytes));
        payload = _decodeInput(input, appContract, sender, index);
    }
}

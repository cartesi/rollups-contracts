// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Create2} from "@openzeppelin-contracts-5.2.0/utils/Create2.sol";

import {ITournamentFactory} from "prt-contracts/ITournamentFactory.sol";
import {Machine} from "prt-contracts/types/Machine.sol";

import {OneOfN} from "./OneOfN.sol";
import {IInputBox} from "../../inputs/IInputBox.sol";

/// @title Dave Consensus Factory
/// @notice Allows anyone to reliably deploy a new `OneOfN` contract.
contract OneOfNFactory {
    IInputBox inputBox;
    ITournamentFactory tournamentFactory;

    event OneOfNCreated(OneOfN oneOfN);

    constructor(IInputBox _inputBox, ITournamentFactory _tournament) {
        inputBox = _inputBox;
        tournamentFactory = _tournament;
    }

    function newOneOfN(
        address appContract,
        Machine.Hash initialMachineStateHash,
        bytes32 salt
    ) external returns (OneOfN) {
        OneOfN oneOfN = new OneOfN{salt: salt}(
            inputBox, appContract, tournamentFactory, initialMachineStateHash
        );

        emit OneOfNCreated(oneOfN);

        return oneOfN;
    }

    function calculateOneOfNAddress(
        address appContract,
        Machine.Hash initialMachineStateHash,
        bytes32 salt
    ) external view returns (address) {
        return Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(OneOfN).creationCode,
                    abi.encode(
                        inputBox, appContract, tournamentFactory, initialMachineStateHash
                    )
                )
            )
        );
    }
}

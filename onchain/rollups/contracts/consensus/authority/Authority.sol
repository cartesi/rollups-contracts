// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IConsensus} from "../IConsensus.sol";
import {AbstractConsensus} from "../AbstractConsensus.sol";
import {InputRange} from "../../common/InputRange.sol";

/// @notice A consensus contract controlled by a single address, the owner.
/// @dev This contract inherits from OpenZeppelin's `Ownable` contract.
///      For more information on `Ownable`, please consult OpenZeppelin's official documentation.
contract Authority is AbstractConsensus, Ownable {
    /// @param initialOwner The initial contract owner
    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @notice Submit a claim.
    /// @param dapp The DApp contract address
    /// @param inputRange The input range
    /// @param epochHash The epoch hash
    /// @dev On success, triggers a `ClaimSubmission` event and a `ClaimAcceptance` event.
    /// @dev Can only be called by the owner.
    function submitClaim(
        address dapp,
        InputRange calldata inputRange,
        bytes32 epochHash
    ) external override onlyOwner {
        emit ClaimSubmission(msg.sender, dapp, inputRange, epochHash);
        _acceptClaim(dapp, inputRange, epochHash);
    }
}

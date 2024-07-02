// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IConsensus} from "../IConsensus.sol";
import {AbstractConsensus} from "../AbstractConsensus.sol";

/// @notice A consensus contract controlled by a single address, the owner.
/// @dev This contract inherits from OpenZeppelin's `Ownable` contract.
///      For more information on `Ownable`, please consult OpenZeppelin's official documentation.
contract Authority is AbstractConsensus, Ownable {
    /// @param initialOwner The initial contract owner
    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @notice Submit a claim.
    /// @param appContract The application contract address
    /// @param claim The output Merkle root hash
    /// @dev Fires a `ClaimSubmission` event and a `ClaimAcceptance` event.
    /// @dev Can only be called by the owner.
    function submitClaim(
        address appContract,
        bytes32 claim
    ) external onlyOwner {
        emit ClaimSubmission(msg.sender, appContract, claim);
        _acceptClaim(appContract, claim);
    }
}

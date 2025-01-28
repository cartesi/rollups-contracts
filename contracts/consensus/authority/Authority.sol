// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IAuthority} from "./IAuthority.sol";
import {IClaimSubmitter} from "../IClaimSubmitter.sol";
import {AbstractClaimSubmitter} from "../AbstractClaimSubmitter.sol";
import {IOwnable} from "../../access/IOwnable.sol";

/// @notice A consensus contract controlled by a single address, the owner.
/// @dev This contract inherits from OpenZeppelin's `Ownable` contract.
///      For more information on `Ownable`, please consult OpenZeppelin's official documentation.
contract Authority is IAuthority, AbstractClaimSubmitter, Ownable {
    /// @param initialOwner The initial contract owner
    /// @param epochLength The epoch length
    /// @dev Reverts if the epoch length is zero.
    constructor(
        address initialOwner,
        uint256 epochLength
    ) AbstractClaimSubmitter(epochLength) Ownable(initialOwner) {}

    /// @notice Submit a claim.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param claim The output Merkle root hash
    /// @dev Fires a `ClaimSubmission` event and a `ClaimAcceptance` event.
    /// @dev Can only be called by the owner.
    function submitClaim(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 claim
    ) external override onlyOwner {
        emit ClaimSubmission(
            msg.sender,
            appContract,
            lastProcessedBlockNumber,
            claim
        );
        _acceptClaim(appContract, lastProcessedBlockNumber, claim);
    }

    function owner() public view override(IOwnable, Ownable) returns (address) {
        return super.owner();
    }

    function renounceOwnership() public override(IOwnable, Ownable) {
        super.renounceOwnership();
    }

    function transferOwnership(
        address newOwner
    ) public override(IOwnable, Ownable) {
        super.transferOwnership(newOwner);
    }

    /// @inheritdoc AbstractClaimSubmitter
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(IERC165, AbstractClaimSubmitter) returns (bool) {
        return
            interfaceId == type(IAuthority).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}

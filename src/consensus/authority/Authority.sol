// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC165} from "@openzeppelin-contracts-5.2.0/utils/introspection/IERC165.sol";
import {Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable.sol";

import {IAuthority} from "./IAuthority.sol";
import {IConsensus} from "../IConsensus.sol";
import {AbstractConsensus} from "../AbstractConsensus.sol";
import {IOwnable} from "../../access/IOwnable.sol";

/// @notice A consensus contract controlled by a single address, the owner.
/// @dev This contract inherits from OpenZeppelin's `Ownable` contract.
///      For more information on `Ownable`, please consult OpenZeppelin's official documentation.
contract Authority is IAuthority, AbstractConsensus, Ownable {
    /// @param initialOwner The initial contract owner
    /// @param epochLength The epoch length
    /// @dev Reverts if the epoch length is zero.
    constructor(address initialOwner, uint256 epochLength)
        AbstractConsensus(epochLength)
        Ownable(initialOwner)
    {}

    /// @inheritdoc IConsensus
    function submitClaim(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 outputsMerkleRoot
    ) external override onlyOwner {
        emit ClaimSubmission(
            msg.sender, appContract, lastProcessedBlockNumber, outputsMerkleRoot
        );
        _acceptClaim(appContract, lastProcessedBlockNumber, outputsMerkleRoot);
    }

    /// @inheritdoc Ownable
    function owner() public view override(IOwnable, Ownable) returns (address) {
        return super.owner();
    }

    /// @inheritdoc Ownable
    function renounceOwnership() public override(IOwnable, Ownable) {
        super.renounceOwnership();
    }

    /// @inheritdoc Ownable
    function transferOwnership(address newOwner) public override(IOwnable, Ownable) {
        super.transferOwnership(newOwner);
    }

    /// @inheritdoc AbstractConsensus
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IERC165, AbstractConsensus)
        returns (bool)
    {
        return interfaceId == type(IAuthority).interfaceId
            || super.supportsInterface(interfaceId);
    }
}

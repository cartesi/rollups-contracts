// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable.sol";
import {IERC165} from "@openzeppelin-contracts-5.2.0/utils/introspection/IERC165.sol";
import {BitMaps} from "@openzeppelin-contracts-5.2.0/utils/structs/BitMaps.sol";

import {IOwnable} from "../../access/IOwnable.sol";
import {AbstractConsensus} from "../AbstractConsensus.sol";
import {IConsensus} from "../IConsensus.sol";
import {IAuthority} from "./IAuthority.sol";

/// @notice A consensus contract controlled by a single address, the owner.
/// @dev This contract inherits from OpenZeppelin's `Ownable` contract.
///      For more information on `Ownable`, please consult OpenZeppelin's official documentation.
contract Authority is IAuthority, AbstractConsensus, Ownable {
    using BitMaps for BitMaps.BitMap;

    /// @notice Epochs with a submitted (and accepted) claim, per application.
    /// @dev Epochs are stored in bitmap structure by their number (last processed block number / epoch length).
    mapping(address => BitMaps.BitMap) _validatedEpochs;

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
        _validateLastProcessedBlockNumber(lastProcessedBlockNumber);

        uint256 epochNumber = lastProcessedBlockNumber / EPOCH_LENGTH;

        BitMaps.BitMap storage bitmap = _validatedEpochs[appContract];

        require(
            !bitmap.get(epochNumber), NotFirstClaim(appContract, lastProcessedBlockNumber)
        );

        _submitClaim(msg.sender, appContract, lastProcessedBlockNumber, outputsMerkleRoot);

        _acceptClaim(appContract, lastProcessedBlockNumber, outputsMerkleRoot);

        bitmap.set(epochNumber);
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

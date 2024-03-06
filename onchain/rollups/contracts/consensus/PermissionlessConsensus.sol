// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)
pragma solidity ^0.8.13;

library Slot {
    enum StatusTag {
        None,
        SingleClaim,
        Dispute
    }

    struct Status {
        StatusTag tag;
        bytes32 claim;
    }

    struct T {
        mapping(bytes32 => Status) statuses;
    }
}

contract PermissionlessConsensus {
    uint immutable public CONSENSUS_START;
    uint constant public EPOCH_LENGTH = 4 * 60 * 60; // four hours

    bytes32 public latestConfirmedClaim;
    uint public latestConfirmedEpoch;

    Slot.T[] openSlots;


    constructor (bytes32 initialHash) {
        latestConfirmedClaim = initialHash;
        latestConfirmedEpoch = 0;
        CONSENSUS_START = block.timestamp;
    }

    function getClaim() view public returns(bytes32) {
        return latestConfirmedClaim;
    }

    function latestOpenEpochNumber() view public returns(uint) {
        return (block.timestamp - CONSENSUS_START) / EPOCH_LENGTH;
    }

    function epochConfirmationDeadline(uint epoch) view public returns(uint) {
        return CONSENSUS_START + epoch * EPOCH_LENGTH;
    }

    function postClaim(uint epoch, bytes32 parentHash, bytes32 stateHash) external {
        require(epoch <= latestOpenEpochNumber());
        require(epoch > latestConfirmedEpoch);

        Slot.T storage slot = openSlots[epoch];
        Slot.Status storage status = slot.statuses[parentHash];

        if (block.timestamp > epochConfirmationDeadline(epoch)) {
            revert("too late...");
        } else if (status.tag == Slot.StatusTag.Dispute) {
            return; // already a dispute...
        } else if (status.tag == Slot.StatusTag.None) {
            status.tag = Slot.StatusTag.SingleClaim;
            status.claim = stateHash;
        } else { // single claim...
            assert(status.tag == Slot.StatusTag.SingleClaim);
            if (status.claim == stateHash) {
                return;
            } else {
                address disputeAddress = address(0x0); // TODO instantiate Dave!
                status.tag = Slot.StatusTag.Dispute;
                status.claim = bytes32(uint256(uint160(disputeAddress)));
            }
        }
    }

    function confirmClaim(uint epoch, bytes32 parentHash, bytes32 stateHash) external {
        require(epoch <= latestOpenEpochNumber());
        require(epoch > latestConfirmedEpoch);
        require(latestConfirmedClaim == parentHash);
        require(latestConfirmedEpoch + 1 == epoch);

        Slot.T storage slot = openSlots[epoch];
        Slot.Status storage status = slot.statuses[parentHash];

        if (status.tag == Slot.StatusTag.SingleClaim) {
            require(block.timestamp > epochConfirmationDeadline(epoch));
            latestConfirmedClaim = status.claim;
            latestConfirmedEpoch++;
        } else if (status.tag == Slot.StatusTag.Dispute) {
            address disputeAddress =  address(bytes20(status.claim));
            (bool hasFinished, bytes32 finalState) =
                // TODO: call Dave and get result!
                (disputeAddress == address(0), bytes32(bytes20(disputeAddress)));

            require(hasFinished);
            latestConfirmedClaim = finalState;
            latestConfirmedEpoch++;
        } else {
            revert();
        }
    }
}

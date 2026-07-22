// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {EmulatorCompat} from "cartesi-machine-solidity-step-0.15.0/src/EmulatorCompat.sol";
import {EmulatorConstants} from "cartesi-machine-solidity-step-0.15.0/src/EmulatorConstants.sol";

import {LeafProof} from "../common/LeafProof.sol";
import {MachineValidationErrors} from "../common/MachineValidationErrors.sol";
import {MachineValidityProof} from "../common/MachineValidityProof.sol";
import {LibLeafProof} from "./LibLeafProof.sol";

library LibMachineValidityProof {
    using LibLeafProof for LeafProof;

    /// @notice Validate a machine and prove its outputs Merkle root.
    /// @param v The machine validity proof
    /// @param machineMerkleRoot The machine Merkle root
    /// @return outputsMerkleRoot The proven outputs Merkle root
    /// @dev May raise `InvalidSiblingsArrayLength`, `InvalidMachineMerkleProof`,
    /// `InvalidPostEpochMachineIflagsYRegister`, or
    /// `InvalidPostEpochMachineHtifTohostRegister`.
    function validate(MachineValidityProof calldata v, bytes32 machineMerkleRoot)
        internal
        pure
        returns (bytes32 outputsMerkleRoot)
    {
        require(
            v.iflagsYProof.proveIflagsY(machineMerkleRoot) != 0,
            MachineValidationErrors.InvalidPostEpochMachineIflagsYRegister()
        );

        require(
            EmulatorCompat.isYieldedManualWith(
                v.htifTohostProof.proveHtifTohost(machineMerkleRoot),
                EmulatorConstants.HTIF_YIELD_MANUAL_REASON_RX_ACCEPTED
            ),
            MachineValidationErrors.InvalidPostEpochMachineHtifTohostRegister()
        );

        return v.txBufferProof.proveTxBuffer(machineMerkleRoot);
    }
}

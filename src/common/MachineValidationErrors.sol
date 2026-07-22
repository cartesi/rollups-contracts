// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

interface MachineValidationErrors {
    /// @notice A siblings array has an invalid length. A leaf proof siblings array has
    /// an expected length given by the log2 of the machine memory space - the log2 of
    /// the machine data block size (in bytes). See the `CanonicalMachine` library for
    /// the value of these constants. This is most likely an issue on the claim submitter
    /// code rather than on the application.
    error InvalidSiblingsArrayLength();

    /// @notice The machine Merkle root produced by a Merkle proof differs from the one
    /// provided separately. This indicates that either the leaf proof data block, the
    /// leaf proof siblings array, or the machine Merkle root is incorrect. This is most
    /// likely an issue on the claim submitter code rather than on the application.
    error InvalidMachineMerkleProof();

    /// @notice The post-epoch machine iflags_Y register is unset (zero) and therefore
    /// unsuitable for finalization. This may suggest that the machine has reached an
    /// unrecoverable state and that the application should be foreclosed to unlock
    /// user funds through emergency withdrawals and non-finalized deposit refunds.
    error InvalidPostEpochMachineIflagsYRegister();

    /// @notice The post-epoch machine HTIF tohost register does not signal that the
    /// machine is manually yielded with 'rx accepted' reason. This may suggest that
    /// the machine has reached an unrecoverable state and that the application should be
    /// foreclosed to unlock user funds through emergency withdrawals and non-finalized
    /// deposit refunds.
    error InvalidPostEpochMachineHtifTohostRegister();
}

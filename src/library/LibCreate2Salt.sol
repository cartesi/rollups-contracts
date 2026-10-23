// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

/// @notice Derives the CREATE2 salts of deterministic deployments,
/// so that permissionless and reserved addresses never collide.
library LibCreate2Salt {
    /// @notice The type of a deterministic deployment.
    /// @dev Prefixes the CREATE2 salt pre-image, so that the types never collide.
    /// New types must be appended, so that existing addresses do not change.
    enum DeploymentType {
        PERMISSIONLESS,
        RESERVED
    }

    /// @notice Derive the CREATE2 salt of a permissionless deployment.
    /// @param salt The user-provided salt
    /// @return The CREATE2 salt
    function permissionless(bytes32 salt) internal pure returns (bytes32) {
        return keccak256(abi.encode(DeploymentType.PERMISSIONLESS, salt));
    }

    /// @notice Derive the CREATE2 salt of a deployment reserved for a caller.
    /// @param salt The user-provided salt
    /// @param caller The caller for which the address is reserved
    /// @return The CREATE2 salt
    function reserved(bytes32 salt, address caller) internal pure returns (bytes32) {
        return keccak256(abi.encode(DeploymentType.RESERVED, salt, caller));
    }
}

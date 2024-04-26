// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import {AddrResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/AddrResolver.sol";

library LibENS {
    /// @notice Resolve ENS node to address
    /// @param ens The ENS registry
    /// @param node The ENS node
    /// @return The address that ENS node resolves to
    function resolveToAddress(
        ENS ens,
        bytes32 node
    ) internal view returns (address) {
        AddrResolver resolver = AddrResolver(ens.resolver(node));
        return resolver.addr(node);
    }
}

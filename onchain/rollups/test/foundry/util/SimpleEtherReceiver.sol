// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title A Simple Ether Receiver Contract
pragma solidity ^0.8.8;

interface IEtherReceiver {
    fallback() external payable;
}

contract SimpleEtherReceiver is IEtherReceiver {
    fallback() external payable override {}
}

// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Vm} from "forge-std/Vm.sol";
import {InputRange} from "contracts/common/InputRange.sol";

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

library LibServerManager {
    using LibServerManager for string;
    using LibServerManager for RawHash;
    using LibServerManager for RawHash[];
    using LibServerManager for RawOutputValidityProof;
    using LibServerManager for RawProof;
    using LibServerManager for RawProof[];
    using SafeCast for uint256;

    struct RawHash {
        bytes32 data;
    }

    struct RawOutputValidityProof {
        string inputIndexWithinEpoch;
        RawHash machineStateHash;
        RawHash noticesEpochRootHash;
        RawHash[] outputHashInOutputHashesSiblings;
        RawHash[] outputHashesInEpochSiblings;
        RawHash outputHashesRootHash;
        string outputIndexWithinInput;
        RawHash vouchersEpochRootHash;
    }

    struct RawProof {
        bytes32 context; // unused
        string inputIndex;
        string outputEnum;
        string outputIndex;
        RawOutputValidityProof validity;
    }

    struct RawFinishEpochResponse {
        RawHash machineHash;
        RawHash noticesEpochRootHash;
        RawProof[] proofs;
        RawHash vouchersEpochRootHash;
    }

    struct OutputValidityProof {
        uint256 inputIndexWithinEpoch;
        uint256 outputIndexWithinInput;
        bytes32 outputHashesRootHash;
        bytes32 vouchersEpochRootHash;
        bytes32 noticesEpochRootHash;
        bytes32 machineStateHash;
        bytes32[] outputHashInOutputHashesSiblings;
        bytes32[] outputHashesInEpochSiblings;
    }

    enum OutputEnum {
        VOUCHER,
        NOTICE
    }

    struct Proof {
        uint256 inputIndex;
        uint256 outputIndex;
        OutputEnum outputEnum;
        OutputValidityProof validity;
    }

    struct FinishEpochResponse {
        bytes32 machineHash;
        bytes32 vouchersEpochRootHash;
        bytes32 noticesEpochRootHash;
        Proof[] proofs;
    }

    error InvalidOutputEnum(string);

    function toUint(string memory s, Vm vm) internal pure returns (uint256) {
        return vm.parseUint(s);
    }

    function fmt(RawHash memory h) internal pure returns (bytes32) {
        return h.data;
    }

    function fmt(RawHash[] memory hs) internal pure returns (bytes32[] memory) {
        bytes32[] memory b32s = new bytes32[](hs.length);
        for (uint256 i; i < hs.length; ++i) {
            b32s[i] = hs[i].fmt();
        }
        return b32s;
    }

    function fmt(
        RawOutputValidityProof memory v,
        Vm vm
    ) internal pure returns (OutputValidityProof memory) {
        return
            OutputValidityProof({
                inputIndexWithinEpoch: v.inputIndexWithinEpoch.toUint(vm),
                outputIndexWithinInput: v.outputIndexWithinInput.toUint(vm),
                outputHashesRootHash: v.outputHashesRootHash.fmt(),
                vouchersEpochRootHash: v.vouchersEpochRootHash.fmt(),
                noticesEpochRootHash: v.noticesEpochRootHash.fmt(),
                machineStateHash: v.machineStateHash.fmt(),
                outputHashInOutputHashesSiblings: v
                    .outputHashInOutputHashesSiblings
                    .fmt(),
                outputHashesInEpochSiblings: v.outputHashesInEpochSiblings.fmt()
            });
    }

    function hash(string memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(s));
    }

    function toOutputEnum(string memory s) internal pure returns (OutputEnum) {
        bytes32 h = s.hash();
        if (h == hash("VOUCHER")) {
            return OutputEnum.VOUCHER;
        } else if (h == hash("NOTICE")) {
            return OutputEnum.NOTICE;
        } else {
            revert InvalidOutputEnum(s);
        }
    }

    function fmt(
        RawProof memory p,
        Vm vm
    ) internal pure returns (Proof memory) {
        return
            Proof({
                inputIndex: p.inputIndex.toUint(vm),
                outputIndex: p.outputIndex.toUint(vm),
                outputEnum: p.outputEnum.toOutputEnum(),
                validity: p.validity.fmt(vm)
            });
    }

    function fmt(
        RawProof[] memory rawps,
        Vm vm
    ) internal pure returns (Proof[] memory) {
        uint256 n = rawps.length;
        Proof[] memory ps = new Proof[](n);
        for (uint256 i; i < n; ++i) {
            ps[i] = rawps[i].fmt(vm);
        }
        return ps;
    }

    function fmt(
        RawFinishEpochResponse memory r,
        Vm vm
    ) internal pure returns (FinishEpochResponse memory) {
        return
            FinishEpochResponse({
                machineHash: r.machineHash.fmt(),
                vouchersEpochRootHash: r.vouchersEpochRootHash.fmt(),
                noticesEpochRootHash: r.noticesEpochRootHash.fmt(),
                proofs: r.proofs.fmt(vm)
            });
    }

    function getEpochHash(
        FinishEpochResponse memory r
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(r.noticesEpochRootHash, r.machineHash));
    }

    function getInputRange(
        Proof[] memory proofs
    ) internal pure returns (InputRange memory) {
        return
            InputRange({
                firstIndex: getFirstInputIndex(proofs).toUint64(),
                lastIndex: getLastInputIndex(proofs).toUint64()
            });
    }

    function getFirstInputIndex(
        Proof[] memory proofs
    ) internal pure returns (uint256) {
        uint256 first = type(uint64).max;
        for (uint256 i; i < proofs.length; ++i) {
            Proof memory proof = proofs[i];
            if (proof.inputIndex < first) {
                first = proof.inputIndex;
            }
        }
        return first;
    }

    function getLastInputIndex(
        Proof[] memory proofs
    ) internal pure returns (uint256) {
        uint256 last;
        for (uint256 i; i < proofs.length; ++i) {
            Proof memory proof = proofs[i];
            if (proof.inputIndex > last) {
                last = proof.inputIndex;
            }
        }
        return last;
    }

    function proves(
        Proof memory p,
        uint256 inputIndex,
        uint256 outputIndex
    ) internal pure returns (bool) {
        return
            p.inputIndex == inputIndex &&
            p.outputIndex == outputIndex &&
            p.outputEnum == OutputEnum.NOTICE;
    }
}

// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {EmulatorCompat} from "cartesi-machine-solidity-step-0.15.0/src/EmulatorCompat.sol";
import {EmulatorConstants} from "cartesi-machine-solidity-step-0.15.0/src/EmulatorConstants.sol";

import {CanonicalMachine} from "src/common/CanonicalMachine.sol";
import {LeafProof} from "src/common/LeafProof.sol";
import {MachineValidationErrors} from "src/common/MachineValidationErrors.sol";
import {MachineValidityProof} from "src/common/MachineValidityProof.sol";
import {IConsensus} from "src/consensus/IConsensus.sol";
import {IApplication} from "src/dapp/IApplication.sol";

import {ApplicationCheckerTestUtils} from "./ApplicationCheckerTestUtils.sol";
import {Claim} from "./Claim.sol";
import {LibConsensus} from "./LibConsensus.sol";
import {LibEmulator} from "./LibEmulator.sol";

contract ConsensusTestUtils is ApplicationCheckerTestUtils {
    using LibEmulator for LibEmulator.ProofComponents;
    using LibEmulator for LibEmulator.State;
    using LibConsensus for IConsensus;

    /// @notice A private emulator state for building in-memory
    /// proof components and then erasing the state afterwards.
    LibEmulator.State private _emulator;

    /// @notice An arbitrary size limit for outputs way lower than the theoretical
    /// limit of 2 MB (which is the size of the CMIO TX buffer) so that hashing the
    /// output does not lead to out-of-gas error in Forge.
    uint256 constant MAX_OUTPUT_SIZE = 1 << 10;

    /// @notice This function is used to simulate a foreclosure and a claim submission.
    /// If the claim submission succeeds, then the function reverts with error message "Successful claim submission".
    /// If the claim submission fails, then the function propagates the error from the app contract.
    /// @param consensus The consensus contract
    /// @param validator The validator that will submit the claim
    /// @param claim The claim to be submitted
    function simulateForeclosureAndClaimSubmission(
        IConsensus consensus,
        address validator,
        Claim calldata claim
    ) external {
        vm.prank(vm.randomAddress());
        IApplication(claim.appContract).foreclose();
        vm.prank(validator);
        consensus.submitClaim(claim);
        revert("Successful claim submission");
    }

    /// @notice This function is used to simulate a foreclosure and a claim acceptance.
    /// If the claim acceptance succeeds, then the function reverts with error message "Successful claim acceptance".
    /// If the claim acceptance fails, then the function propagates the error from the app contract.
    /// @param consensus The consensus contract
    /// @param claim The claim to be accepted
    function simulateForeclosureAndClaimAcceptance(
        IConsensus consensus,
        Claim calldata claim
    ) external {
        vm.prank(vm.randomAddress());
        IApplication(claim.appContract).foreclose();
        vm.prank(vm.randomAddress());
        consensus.acceptClaim(claim);
        revert("Successful claim acceptance");
    }

    function _encodeNotFirstClaim(Claim memory claim)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IConsensus.NotFirstClaim.selector,
            claim.appContract,
            claim.lastProcessedBlockNumber
        );
    }

    function _encodeNotPastBlock(uint256 lastProcessedBlockNumber)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IConsensus.NotPastBlock.selector,
            lastProcessedBlockNumber,
            vm.getBlockNumber()
        );
    }

    function _encodeNotEpochFinalBlock(
        uint256 lastProcessedBlockNumber,
        uint256 epochLength
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            IConsensus.NotEpochFinalBlock.selector, lastProcessedBlockNumber, epochLength
        );
    }

    function _encodeClaimNotStaged(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 machineMerkleRoot,
        IConsensus.ClaimStatus claimStatus
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            IConsensus.ClaimNotStaged.selector,
            appContract,
            lastProcessedBlockNumber,
            machineMerkleRoot,
            claimStatus
        );
    }

    function _encodeClaimNotStaged(Claim memory claim, IConsensus.ClaimStatus claimStatus)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IConsensus.ClaimNotStaged.selector,
            claim.appContract,
            claim.lastProcessedBlockNumber,
            claim.machineMerkleRoot,
            claimStatus
        );
    }

    function _encodeClaimNotStagedButUnstaged(Claim memory claim)
        internal
        pure
        returns (bytes memory)
    {
        return _encodeClaimNotStaged(claim, IConsensus.ClaimStatus.UNSTAGED);
    }

    function _encodeClaimNotStagedButAccepted(Claim memory claim)
        internal
        pure
        returns (bytes memory)
    {
        return _encodeClaimNotStaged(claim, IConsensus.ClaimStatus.ACCEPTED);
    }

    function _encodeClaimStagingPeriodNotOverYet(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 machineMerkleRoot,
        uint256 numberOfBlocksAfterStaging,
        uint256 claimStagingPeriod
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            IConsensus.ClaimStagingPeriodNotOverYet.selector,
            appContract,
            lastProcessedBlockNumber,
            machineMerkleRoot,
            numberOfBlocksAfterStaging,
            claimStagingPeriod
        );
    }

    function _encodeInvalidSiblingsArrayLength() internal pure returns (bytes4) {
        return MachineValidationErrors.InvalidSiblingsArrayLength.selector;
    }

    function _encodeInvalidMachineMerkleProof() internal pure returns (bytes4) {
        return MachineValidationErrors.InvalidMachineMerkleProof.selector;
    }

    function _encodeInvalidPostEpochMachineIflagsYRegister()
        internal
        pure
        returns (bytes4)
    {
        return MachineValidationErrors.InvalidPostEpochMachineIflagsYRegister.selector;
    }

    function _encodeInvalidPostEpochMachineHtifTohostRegister()
        internal
        pure
        returns (bytes4)
    {
        return MachineValidationErrors.InvalidPostEpochMachineHtifTohostRegister.selector;
    }

    function _epochIndexOfLastBlock(uint256 epochLength)
        internal
        pure
        returns (uint256 epochIndex)
    {
        return type(uint256).max / epochLength;
    }

    function _currentEpochIndex(uint256 epochLength)
        internal
        view
        returns (uint256 epochIndex)
    {
        return vm.getBlockNumber() / epochLength;
    }

    function _randomEpochIndex(uint256 epochLength)
        internal
        returns (uint256 epochIndex)
    {
        uint256 currentEpochIndex = _currentEpochIndex(epochLength);
        uint256 epochIndexOfLastBlock = _epochIndexOfLastBlock(epochLength);
        vm.assume(epochIndexOfLastBlock >= 1);
        uint256 maxEpochIndex = epochIndexOfLastBlock - 1;
        vm.assume(currentEpochIndex <= maxEpochIndex);
        return vm.randomUint(currentEpochIndex, maxEpochIndex);
    }

    function _randomEpochFinalBlockNumber(uint256 epochLength)
        internal
        returns (uint256 epochFinalBlock)
    {
        return _randomEpochIndex(epochLength) * epochLength + (epochLength - 1);
    }

    function _randomEpochFinalBlockNumbers(uint256 epochLength, uint256 n)
        internal
        returns (uint256[] memory epochFinalBlocks)
    {
        epochFinalBlocks = new uint256[](n);
        for (uint256 i; i < epochFinalBlocks.length; ++i) {
            epochFinalBlocks[i] = _randomEpochFinalBlockNumber(epochLength);
        }
    }

    function _randomEpochFinalBlockNumbers(uint256 epochLength)
        internal
        returns (uint256[] memory epochFinalBlocks)
    {
        return _randomEpochFinalBlockNumbers(epochLength, vm.randomUint(1, 3));
    }

    function _randomUintGt(uint256 n) internal returns (uint256) {
        vm.assume(n <= type(uint256).max - 1);
        return vm.randomUint(n + 1, type(uint256).max);
    }

    function _rollPast(uint256 blockNumber) internal {
        if (vm.getBlockNumber() <= blockNumber) {
            vm.roll(_randomUintGt(blockNumber));
        }
    }

    function _randomNonEpochFinalBlock(uint256 epochLength) internal returns (uint256) {
        // If epochLength == 1, then forall x, (x % epochLength) == (epochLength - 1).
        // That is, every block is an epoch final block, so we cannot sample a random
        // non-epoch-final block.
        vm.assume(epochLength >= 2);

        // Pick a random blockNumber that satisfies both
        // - blockNumber % epochLength != (epochLength - 1)
        // - blockNumber > currentBlockNumber
        uint256 blockNumber = _randomUintGt(vm.getBlockNumber());
        vm.assume(blockNumber % epochLength != (epochLength - 1));

        return blockNumber;
    }

    function _randomBytes32() internal returns (bytes32) {
        return bytes32(vm.randomUint());
    }

    function _randomBytes32NotEq(bytes32 b) internal returns (bytes32 a) {
        while (true) {
            a = _randomBytes32();
            if (a != b) {
                return a;
            }
        }
    }

    function _randomUint64() internal returns (uint64) {
        return uint64(vm.randomUint(0, type(uint64).max));
    }

    function _randomBytes32Array(uint256 length)
        internal
        returns (bytes32[] memory array)
    {
        array = new bytes32[](length);
        for (uint256 i; i < array.length; ++i) {
            array[i] = _randomBytes32();
        }
    }

    function _newProofComponents(function(LibEmulator.State storage) init)
        internal
        returns (LibEmulator.ProofComponents memory proofComponents)
    {
        delete _emulator;
        init(_emulator);
        proofComponents = _emulator.buildProofComponents();
    }

    function _addRandomAccount(LibEmulator.State storage emulator) internal {
        uint256 maxAccountSize = 1 << LibEmulator.getLog2MaxAccountSize();
        uint256 accountSize = vm.randomUint(0, maxAccountSize);
        bytes memory account = vm.randomBytes(accountSize);
        emulator.addAccount(account);
    }

    function _addRandomOutput(LibEmulator.State storage emulator) internal {
        uint256 outputSize = vm.randomUint(0, MAX_OUTPUT_SIZE);
        bytes memory output = vm.randomBytes(outputSize);
        emulator.addOutput(output);
    }

    function _setValidIflagsY(LibEmulator.State storage emulator) internal {
        emulator.setIflagsY(uint64(vm.randomUint(1, type(uint64).max)));
    }

    function _initRandom(LibEmulator.State storage emulator) internal {
        _setValidIflagsY(emulator);
        emulator.setHtifTohostRxAccepted();
        _addRandomAccount(emulator);
        _addRandomOutput(emulator);
    }

    function _initBadIflagsY(LibEmulator.State storage emulator) internal {
        emulator.setIflagsY(0);
        emulator.setHtifTohostRxAccepted();
        _addRandomAccount(emulator);
        _addRandomOutput(emulator);
    }

    function _initBadHtifTohost(LibEmulator.State storage emulator) internal {
        _setValidIflagsY(emulator);
        while (true) {
            uint64 htifTohost = _randomUint64();
            if (!_isYieldedManualWithRxAccepted(htifTohost)) {
                emulator.htifTohost = htifTohost;
                break;
            }
        }
        _addRandomAccount(emulator);
        _addRandomOutput(emulator);
    }

    function _isYieldedManualWithRxAccepted(uint64 htifTohost)
        internal
        pure
        returns (bool)
    {
        uint64 yieldReason = EmulatorConstants.HTIF_YIELD_MANUAL_REASON_RX_ACCEPTED;
        return EmulatorCompat.isYieldedManualWith(htifTohost, yieldReason);
    }

    function _randomClaim(uint256 epochLength) internal returns (Claim memory claim) {
        return _newClaim(epochLength, _initRandom);
    }

    function _newClaim(uint256 epochLength, function(LibEmulator.State storage) init)
        internal
        returns (Claim memory claim)
    {
        address appContract = _newActiveAppMock();
        uint256 lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        return _newClaim(appContract, lastProcessedBlockNumber, init);
    }

    function _randomClaim(address appContract, uint256 lastProcessedBlockNumber)
        internal
        returns (Claim memory claim)
    {
        return _newClaim(appContract, lastProcessedBlockNumber, _initRandom);
    }

    function _newClaim(
        address appContract,
        uint256 lastProcessedBlockNumber,
        function(LibEmulator.State storage) init
    ) internal returns (Claim memory claim) {
        LibEmulator.ProofComponents memory pc = _newProofComponents(init);
        return Claim({
            appContract: appContract,
            lastProcessedBlockNumber: lastProcessedBlockNumber,
            machineMerkleRoot: pc.getMachineMerkleRoot(),
            proof: pc.getMachineValidityProof()
        });
    }

    function _randomCompetingClaim(Claim memory claim)
        internal
        returns (Claim memory otherClaim)
    {
        while (true) {
            LibEmulator.ProofComponents memory pc = _newProofComponents(_initRandom);
            bytes32 machineMerkleRoot = pc.getMachineMerkleRoot();
            if (claim.machineMerkleRoot != machineMerkleRoot) {
                return Claim({
                    appContract: claim.appContract,
                    lastProcessedBlockNumber: claim.lastProcessedBlockNumber,
                    machineMerkleRoot: machineMerkleRoot,
                    proof: pc.getMachineValidityProof() // Only build if competing
                });
            }
        }
    }

    function _randomInvalidLeafProofSize() internal returns (uint256) {
        if (vm.randomUint() % 2 == 0) {
            return vm.randomUint(0, CanonicalMachine.MEMORY_TREE_HEIGHT - 1);
        } else {
            return vm.randomUint(
                CanonicalMachine.MEMORY_TREE_HEIGHT + 1,
                2 * CanonicalMachine.MEMORY_TREE_HEIGHT
            );
        }
    }

    function _randomInvalidLeafProofSiblingsArray()
        internal
        returns (bytes32[] memory invalidSiblingsArray)
    {
        return _randomBytes32Array(_randomInvalidLeafProofSize());
    }

    function _pickRandomLeafProofFrom(MachineValidityProof memory v)
        internal
        returns (LeafProof memory leafProof)
    {
        uint256 proofIndex = vm.randomUint(0, 2);
        if (proofIndex == 0) {
            return v.iflagsYProof;
        } else if (proofIndex == 1) {
            return v.htifTohostProof;
        } else {
            require(proofIndex == 2, "invalid proof index");
            return v.txBufferProof;
        }
    }

    function _invalidateSiblingsArray(LeafProof memory leafProof) internal {
        leafProof.siblings = _randomInvalidLeafProofSiblingsArray();
    }

    function _alterDataBlock(LeafProof memory leafProof) internal {
        leafProof.dataBlock = _randomBytes32NotEq(leafProof.dataBlock);
    }

    function _boundedSum(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b <= type(uint256).max - a) {
            return a + b;
        } else {
            return type(uint256).max;
        }
    }
}

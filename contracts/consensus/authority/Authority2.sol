// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IAuthority} from "./IAuthority2.sol";
import {IConsensus} from "../IConsensus2.sol";
import {IOwnable} from "../../access/IOwnable.sol";

/// @notice A consensus contract controlled by a single address, the owner.
/// @dev This contract inherits from OpenZeppelin's `Ownable` contract.
///      For more information on `Ownable`, please consult OpenZeppelin's official documentation.
contract Authority is IAuthority, Ownable {
    uint256 immutable _epochLength;

    struct EpochInfo {
        uint256 blockNumberLowerBound;
        bytes32 settledClaim;
    }

    struct AppInfo {
        uint256 numberOfSealedEpochs;
        uint256 numberOfSettledEpochs;
        uint256 minBlockNumberForSealing;
        mapping(uint256 => EpochInfo) epochInfos;
    }

    mapping(address => AppInfo) _appInfos;

    /// @param initialOwner The initial contract owner
    /// @param epochLength The epoch length
    constructor(
        address initialOwner,
        uint256 epochLength
    ) Ownable(initialOwner) {
        _epochLength = epochLength;
    }

    /// @inheritdoc IConsensus
    function getNumberOfSealedEpochs(
        address appContract
    ) external view override returns (uint256) {
        return _appInfos[appContract].numberOfSealedEpochs;
    }

    /// @inheritdoc IConsensus
    function canSealEpoch(
        address appContract
    ) external view override returns (bool) {
        AppInfo storage appInfo = _appInfos[appContract];
        return _canSealEpoch(appInfo);
    }

    /// @inheritdoc IConsensus
    function sealEpoch(address appContract) external override {
        AppInfo storage appInfo = _appInfos[appContract];
        require(_canSealEpoch(appInfo), CannotSealEpoch(appContract));
        uint256 epochIndex = appInfo.numberOfSealedEpochs;
        appInfo.epochInfos[epochIndex + 1].blockNumberLowerBound = block.number;
        appInfo.minBlockNumberForSealing = block.number + _epochLength;
        appInfo.numberOfSealedEpochs = epochIndex + 1;
        emit SealedEpoch(
            appContract,
            epochIndex,
            _getSealedEpochBlockRange(appInfo, epochIndex)
        );
    }

    /// @inheritdoc IConsensus
    function getEpochPhase(
        address appContract,
        uint256 epochIndex
    ) public view override returns (Phase) {
        AppInfo storage appInfo = _appInfos[appContract];
        return _getEpochPhase(appInfo, appContract, epochIndex);
    }

    /// @inheritdoc IConsensus
    function getSealedEpochBlockRange(
        address appContract,
        uint256 epochIndex
    ) external view override returns (BlockRange memory) {
        AppInfo storage appInfo = _appInfos[appContract];
        require(
            epochIndex < appInfo.numberOfSealedEpochs,
            InvalidEpochIndex(appContract, epochIndex)
        );
        return _getSealedEpochBlockRange(appInfo, epochIndex);
    }

    /// @inheritdoc IConsensus
    function submitClaim(
        address appContract,
        uint256 epochIndex,
        bytes32 claim
    ) external override onlyOwner {
        AppInfo storage appInfo = _appInfos[appContract];
        Phase phase = _getEpochPhase(appInfo, appContract, epochIndex);
        require(
            phase == Phase.WAITING_FOR_CLAIMS,
            InvalidEpochPhase(appContract, epochIndex)
        );
        emit ClaimSubmission(appContract, epochIndex, msg.sender, claim);
        appInfo.epochInfos[epochIndex].settledClaim = claim;
        ++appInfo.numberOfSettledEpochs;
        emit SettledEpoch(appContract, epochIndex, claim);
    }

    /// @inheritdoc IConsensus
    function getDisputeResolutionModule(
        address appContract,
        uint256 epochIndex
    ) external view override returns (IERC165) {
        AppInfo storage appInfo = _appInfos[appContract];
        if (epochIndex < appInfo.numberOfSealedEpochs) {
            revert InvalidEpochPhase(appContract, epochIndex);
        } else {
            revert InvalidEpochIndex(appContract, epochIndex);
        }
    }

    /// @inheritdoc IConsensus
    function getSettledEpochClaim(
        address appContract,
        uint256 epochIndex
    ) external view override returns (bytes32) {
        AppInfo storage appInfo = _appInfos[appContract];
        Phase phase = _getEpochPhase(appInfo, appContract, epochIndex);
        require(
            phase == Phase.SETTLED,
            InvalidEpochPhase(appContract, epochIndex)
        );
        return appInfo.epochInfos[epochIndex].settledClaim;
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
    function transferOwnership(
        address newOwner
    ) public override(IOwnable, Ownable) {
        super.transferOwnership(newOwner);
    }

    function _canSealEpoch(
        AppInfo storage appInfo
    ) internal view returns (bool) {
        return
            (appInfo.minBlockNumberForSealing <= block.number) &&
            (appInfo.numberOfSealedEpochs == appInfo.numberOfSettledEpochs);
    }

    function _getEpochPhase(
        AppInfo storage appInfo,
        address appContract,
        uint256 epochIndex
    ) internal view returns (Phase) {
        if (epochIndex < appInfo.numberOfSettledEpochs) {
            return Phase.SETTLED;
        } else if (epochIndex < appInfo.numberOfSealedEpochs) {
            return Phase.WAITING_FOR_CLAIMS;
        } else {
            revert InvalidEpochIndex(appContract, epochIndex);
        }
    }

    function _getSealedEpochBlockRange(
        AppInfo storage appInfo,
        uint256 epochIndex
    ) internal view returns (BlockRange memory) {
        return
            (BlockRange)({
                lowerBound: appInfo
                    .epochInfos[epochIndex]
                    .blockNumberLowerBound,
                upperBound: appInfo
                    .epochInfos[epochIndex + 1]
                    .blockNumberLowerBound
            });
    }
}

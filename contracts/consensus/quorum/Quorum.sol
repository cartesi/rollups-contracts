// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IQuorum} from "./IQuorum.sol";
import {IConsensus} from "../IConsensus.sol";

contract Quorum is IQuorum {
    using BitMaps for BitMaps.BitMap;

    /// @notice The total number of validators.
    /// @notice See the `numOfValidators` function.
    uint256 immutable _numOfValidators;

    /// @notice Minimum number of blocks before sealing a new epoch
    uint256 immutable _epochLength;

    /// @notice Validator IDs indexed by address.
    /// @notice See the `validatorId` function.
    /// @dev Non-validators are assigned to ID zero.
    /// @dev Validators have IDs greater than zero.
    mapping(address => uint256) _validatorId;

    /// @notice Validator addresses indexed by ID.
    /// @notice See the `validatorById` function.
    /// @dev Invalid IDs map to address zero.
    mapping(uint256 => address) _validatorById;

    struct SizedBitMap {
        uint256 size;
        BitMaps.BitMap bitmap;
    }

    struct EpochInfo {
        uint256 blockNumberLowerBound;
        BitMaps.BitMap submitters;
        mapping(bytes32 => SizedBitMap) submissions;
    }

    struct AppInfo {
        uint256 numberOfSealedEpochs;
        uint256 numberOfSettledEpochs;
        uint256 minBlockNumberForSealing;
        mapping(uint256 => EpochInfo) epochInfos;
        mapping(bytes32 => bool) settledClaims;
    }

    mapping(address => AppInfo) _appInfos;

    /// @param validators The array of validator addresses
    /// @param epochLength The epoch length
    /// @dev Duplicates in the `validators` array are ignored.
    constructor(address[] memory validators, uint256 epochLength) {
        uint256 n;
        for (uint256 i; i < validators.length; ++i) {
            address validator = validators[i];
            if (_validatorId[validator] == 0) {
                uint256 id = ++n;
                _validatorId[validator] = id;
                _validatorById[id] = validator;
            }
        }
        _numOfValidators = n;
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
    ) external override {
        uint256 id = _validatorId[msg.sender];
        require(id > 0, CallerIsNotValidator());

        AppInfo storage appInfo = _appInfos[appContract];
        Phase phase = _getEpochPhase(appInfo, appContract, epochIndex);

        require(
            phase == Phase.WAITING_FOR_CLAIMS,
            InvalidEpochPhase(appContract, epochIndex)
        );

        EpochInfo storage epochInfo = appInfo.epochInfos[epochIndex];
        BitMaps.BitMap storage submitters = epochInfo.submitters;
        SizedBitMap storage submissions = epochInfo.submissions[claim];

        if (!submitters.get(id)) {
            emit ClaimSubmission(appContract, epochIndex, msg.sender, claim);
            submitters.set(id);
            submissions.bitmap.set(id);
            if (++submissions.size == 1 + _numOfValidators / 2) {
                appInfo.settledClaims[claim] = true;
                ++appInfo.numberOfSettledEpochs;
                emit SettledEpoch(appContract, epochIndex, claim);
            }
        }
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
    function wasClaimSettled(
        address appContract,
        bytes32 claim
    ) external view override returns (bool) {
        AppInfo storage appInfo = _appInfos[appContract];
        return appInfo.settledClaims[claim];
    }

    /// @inheritdoc IQuorum
    function numOfValidators() external view override returns (uint256) {
        return _numOfValidators;
    }

    /// @inheritdoc IQuorum
    function validatorId(
        address validator
    ) external view override returns (uint256) {
        return _validatorId[validator];
    }

    /// @inheritdoc IQuorum
    function validatorById(
        uint256 id
    ) external view override returns (address) {
        return _validatorById[id];
    }

    /// @inheritdoc IQuorum
    function isValidatorInFavorOfSomeClaim(
        address appContract,
        uint256 epochIndex,
        uint256 id
    ) external view override returns (bool) {
        EpochInfo storage epochInfo = _getEpochInfo(appContract, epochIndex);
        return epochInfo.submitters.get(id);
    }

    /// @inheritdoc IQuorum
    function numOfValidatorsInFavorOf(
        address appContract,
        uint256 epochIndex,
        bytes32 claim
    ) external view override returns (uint256) {
        EpochInfo storage epochInfo = _getEpochInfo(appContract, epochIndex);
        return epochInfo.submissions[claim].size;
    }

    /// @inheritdoc IQuorum
    function isValidatorInFavorOf(
        address appContract,
        uint256 epochIndex,
        bytes32 claim,
        uint256 id
    ) external view override returns (bool) {
        EpochInfo storage epochInfo = _getEpochInfo(appContract, epochIndex);
        return epochInfo.submissions[claim].bitmap.get(id);
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

    function _getEpochInfo(
        address appContract,
        uint256 epochIndex
    ) internal view returns (EpochInfo storage) {
        return _appInfos[appContract].epochInfos[epochIndex];
    }
}

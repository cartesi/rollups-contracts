// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IOwnable} from "../access/IOwnable.sol";
import {OutputValidityProof} from "../common/OutputValidityProof.sol";
import {Outputs} from "../common/Outputs.sol";
import {WithdrawalConfig} from "../common/WithdrawalConfig.sol";
import {IOutputsMerkleRootValidator} from "../consensus/IOutputsMerkleRootValidator.sol";
import {LibAddress} from "../library/LibAddress.sol";
import {LibOutputValidityProof} from "../library/LibOutputValidityProof.sol";
import {LibWithdrawalConfig} from "../library/LibWithdrawalConfig.sol";
import {IWithdrawalOutputBuilder} from "../withdrawal/IWithdrawalOutputBuilder.sol";
import {IApplication} from "./IApplication.sol";

import {Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable.sol";
import {
    ERC1155Holder
} from "@openzeppelin-contracts-5.2.0/token/ERC1155/utils/ERC1155Holder.sol";
import {
    ERC721Holder
} from "@openzeppelin-contracts-5.2.0/token/ERC721/utils/ERC721Holder.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts-5.2.0/utils/ReentrancyGuard.sol";
import {BitMaps} from "@openzeppelin-contracts-5.2.0/utils/structs/BitMaps.sol";

contract Application is
    IApplication,
    Ownable,
    ERC721Holder,
    ERC1155Holder,
    ReentrancyGuard
{
    using BitMaps for BitMaps.BitMap;
    using LibAddress for address;
    using LibOutputValidityProof for OutputValidityProof;
    using LibWithdrawalConfig for WithdrawalConfig;

    /// @notice Deployment block number
    uint256 immutable DEPLOYMENT_BLOCK_NUMBER = block.number;

    /// @notice The initial machine state hash.
    /// @dev See the `getTemplateHash` function.
    bytes32 immutable TEMPLATE_HASH;

    /// @notice The guardian address.
    /// @dev See the `getGuardian` function.
    address immutable GUARDIAN;

    /// @notice The base-2 log of leaves per account.
    /// @dev See the `getLog2LeavesPerAccount` function.
    uint8 immutable LOG2_LEAVES_PER_ACCOUNT;

    /// @notice The base-2 log of max. num. of accounts.
    /// @dev See the `getLog2MaxNumOfAccounts` function.
    uint8 immutable LOG2_MAX_NUM_OF_ACCOUNTS;

    /// @notice The offset of the accounts drive.
    /// @dev See the `getAccountsDriveStartIndex` function.
    uint64 immutable ACCOUNTS_DRIVE_START_INDEX;

    /// @notice The withdrawal output builder contract.
    /// @dev See the `getWithdrawalOutputBuilder` function.
    IWithdrawalOutputBuilder immutable WITHDRAWAL_OUTPUT_BUILDER;

    /// @notice Keeps track of which outputs have been executed.
    /// @dev See the `wasOutputExecuted` function.
    BitMaps.BitMap internal _executed;

    /// @notice Keeps track of which accounts have been withdrawn.
    /// @dev See the `wereAccountFundsWithdrawn` function.
    BitMaps.BitMap internal _withdrawn;

    /// @notice The current outputs Merkle root validator contract.
    /// @dev See the `getOutputsMerkleRootValidator` and `migrateToOutputsMerkleRootValidator` functions.
    IOutputsMerkleRootValidator internal _outputsMerkleRootValidator;

    /// @notice The data availability solution.
    /// @dev See the `getDataAvailability` function.
    bytes internal _dataAvailability;

    /// @notice Whether the application has been foreclosed by the guardian.
    /// @dev See the `isForeclosed` function.
    bool internal _isForeclosed;

    /// @notice The number of outputs executed by the application.
    /// @dev See the `getNumberOfExecutedOutputs` function.
    uint256 _numOfExecutedOutputs;

    /// @notice The number of withdrawals from the application.
    /// @dev See the `getNumberOfWithdrawals` function.
    uint256 _numOfWithdrawals;

    /// @notice Creates an `Application` contract.
    /// @param outputsMerkleRootValidator The initial outputs Merkle root validator contract
    /// @param initialOwner The initial application owner
    /// @param templateHash The initial machine state hash
    /// @param dataAvailability The data availability solution
    /// @param withdrawalConfig The withdrawal configuration
    /// @dev Reverts if the initial application owner address is zero.
    constructor(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address initialOwner,
        bytes32 templateHash,
        bytes memory dataAvailability,
        WithdrawalConfig memory withdrawalConfig
    ) Ownable(initialOwner) {
        require(withdrawalConfig.isValid(), "Invalid withdrawal config");
        TEMPLATE_HASH = templateHash;
        GUARDIAN = withdrawalConfig.guardian;
        LOG2_LEAVES_PER_ACCOUNT = withdrawalConfig.log2LeavesPerAccount;
        LOG2_MAX_NUM_OF_ACCOUNTS = withdrawalConfig.log2MaxNumOfAccounts;
        ACCOUNTS_DRIVE_START_INDEX = withdrawalConfig.accountsDriveStartIndex;
        WITHDRAWAL_OUTPUT_BUILDER = withdrawalConfig.withdrawalOutputBuilder;
        _outputsMerkleRootValidator = outputsMerkleRootValidator;
        _dataAvailability = dataAvailability;
    }

    /// @notice Accept Ether transfers.
    /// @dev If you wish to transfer Ether to an application while informing
    ///      the backend of it, then please do so through the Ether portal contract.
    receive() external payable {}

    /// @inheritdoc IApplication
    function executeOutput(bytes calldata output, OutputValidityProof calldata proof)
        external
        override
        nonReentrant
    {
        validateOutput(output, proof);

        uint64 outputIndex = proof.outputIndex;

        if (output.length < 4) {
            revert OutputNotExecutable(output);
        }

        bytes4 selector = bytes4(output[:4]);
        bytes calldata arguments = output[4:];

        if (selector == Outputs.Voucher.selector) {
            if (_executed.get(outputIndex)) {
                revert OutputNotReexecutable(output);
            }
            _executeVoucher(arguments);
        } else if (selector == Outputs.DelegateCallVoucher.selector) {
            if (_executed.get(outputIndex)) {
                revert OutputNotReexecutable(output);
            }
            _executeDelegateCallVoucher(arguments);
        } else {
            revert OutputNotExecutable(output);
        }

        _executed.set(outputIndex);
        ++_numOfExecutedOutputs;
        emit OutputExecuted(outputIndex, output);
    }

    /// @inheritdoc IApplication
    function migrateToOutputsMerkleRootValidator(IOutputsMerkleRootValidator newOutputsMerkleRootValidator)
        external
        override
        onlyOwner
    {
        _outputsMerkleRootValidator = newOutputsMerkleRootValidator;
        emit OutputsMerkleRootValidatorChanged(newOutputsMerkleRootValidator);
    }

    function foreclose() external override onlyGuardian {
        _isForeclosed = true;
        emit Foreclosure();
    }

    /// @inheritdoc IApplication
    function wasOutputExecuted(uint256 outputIndex)
        external
        view
        override
        returns (bool)
    {
        return _executed.get(outputIndex);
    }

    function wereAccountFundsWithdrawn(uint256 accountIndex)
        external
        view
        returns (bool)
    {
        return _withdrawn.get(accountIndex);
    }

    /// @inheritdoc IApplication
    function validateOutput(bytes calldata output, OutputValidityProof calldata proof)
        public
        view
        override
    {
        validateOutputHash(keccak256(output), proof);
    }

    /// @inheritdoc IApplication
    function validateOutputHash(bytes32 outputHash, OutputValidityProof calldata proof)
        public
        view
        override
    {
        if (!proof.isSiblingsArrayLengthValid()) {
            revert InvalidOutputHashesSiblingsArrayLength();
        }

        bytes32 outputsMerkleRoot = proof.computeOutputsMerkleRoot(outputHash);

        if (!_isOutputsMerkleRootValid(outputsMerkleRoot)) {
            revert InvalidOutputsMerkleRoot(outputsMerkleRoot);
        }
    }

    /// @inheritdoc IApplication
    function getTemplateHash() external view override returns (bytes32) {
        return TEMPLATE_HASH;
    }

    /// @inheritdoc IApplication
    function getOutputsMerkleRootValidator()
        external
        view
        override
        returns (IOutputsMerkleRootValidator)
    {
        return _outputsMerkleRootValidator;
    }

    /// @inheritdoc IApplication
    function getDataAvailability() external view override returns (bytes memory) {
        return _dataAvailability;
    }

    /// @inheritdoc IApplication
    function getDeploymentBlockNumber() external view override returns (uint256) {
        return DEPLOYMENT_BLOCK_NUMBER;
    }

    /// @inheritdoc IApplication
    function getNumberOfExecutedOutputs() external view override returns (uint256) {
        return _numOfExecutedOutputs;
    }

    function getNumberOfWithdrawals() external view override returns (uint256) {
        return _numOfWithdrawals;
    }

    function getLog2LeavesPerAccount() external view override returns (uint8) {
        return LOG2_LEAVES_PER_ACCOUNT;
    }

    function getLog2MaxNumOfAccounts() external view override returns (uint8) {
        return LOG2_MAX_NUM_OF_ACCOUNTS;
    }

    function getAccountsDriveStartIndex() external view override returns (uint64) {
        return ACCOUNTS_DRIVE_START_INDEX;
    }

    function getGuardian() public view override returns (address) {
        return GUARDIAN;
    }

    function getWithdrawalOutputBuilder()
        external
        view
        override
        returns (IWithdrawalOutputBuilder)
    {
        return WITHDRAWAL_OUTPUT_BUILDER;
    }

    function isForeclosed() external view override returns (bool) {
        return _isForeclosed;
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
    function transferOwnership(address newOwner) public override(IOwnable, Ownable) {
        super.transferOwnership(newOwner);
    }

    modifier onlyGuardian() {
        _ensureMsgSenderIsGuardian();
        _;
    }

    /// @notice Check if an outputs Merkle root is valid,
    /// according to the current outputs Merkle root validator.
    /// @param outputsMerkleRoot The output Merkle root
    function _isOutputsMerkleRootValid(bytes32 outputsMerkleRoot)
        internal
        view
        returns (bool)
    {
        return _outputsMerkleRootValidator.isOutputsMerkleRootValid(
            address(this), outputsMerkleRoot
        );
    }

    /// @notice Executes a voucher
    /// @param arguments ABI-encoded arguments
    function _executeVoucher(bytes calldata arguments) internal {
        address destination;
        uint256 value;
        bytes memory payload;

        (destination, value, payload) = abi.decode(arguments, (address, uint256, bytes));

        bool enoughFunds;
        uint256 balance;

        (enoughFunds, balance) = destination.safeCall(value, payload);

        if (!enoughFunds) {
            revert InsufficientFunds(value, balance);
        }
    }

    /// @notice Executes a delegatecall voucher
    /// @param arguments ABI-encoded arguments
    function _executeDelegateCallVoucher(bytes calldata arguments) internal {
        address destination;
        bytes memory payload;

        (destination, payload) = abi.decode(arguments, (address, bytes));

        destination.safeDelegateCall(payload);
    }

    /// @notice Ensures the message sender is the guardian.
    function _ensureMsgSenderIsGuardian() internal view {
        require(msg.sender == getGuardian(), NotGuardian());
    }
}

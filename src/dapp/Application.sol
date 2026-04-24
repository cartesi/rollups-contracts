// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IOwnable} from "../access/IOwnable.sol";
import {AccountValidityProof} from "../common/AccountValidityProof.sol";
import {CanonicalMachine} from "../common/CanonicalMachine.sol";
import {OutputValidityProof} from "../common/OutputValidityProof.sol";
import {Outputs} from "../common/Outputs.sol";
import {RollupsContract} from "../common/RollupsContract.sol";
import {WithdrawalConfig} from "../common/WithdrawalConfig.sol";
import {IOutputsMerkleRootValidator} from "../consensus/IOutputsMerkleRootValidator.sol";
import {LibAccountValidityProof} from "../library/LibAccountValidityProof.sol";
import {LibAddress} from "../library/LibAddress.sol";
import {LibBinaryMerkleTree} from "../library/LibBinaryMerkleTree.sol";
import {LibBytes} from "../library/LibBytes.sol";
import {LibKeccak256} from "../library/LibKeccak256.sol";
import {LibOutputValidityProof} from "../library/LibOutputValidityProof.sol";
import {LibWithdrawalConfig} from "../library/LibWithdrawalConfig.sol";
import {IWithdrawalOutputBuilder} from "../withdrawal/IWithdrawalOutputBuilder.sol";
import {IApplication} from "./IApplication.sol";
import {IApplicationFactoryErrors} from "./IApplicationFactoryErrors.sol";

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
    ReentrancyGuard,
    RollupsContract
{
    using BitMaps for BitMaps.BitMap;
    using LibAccountValidityProof for AccountValidityProof;
    using LibAddress for address;
    using LibBinaryMerkleTree for bytes;
    using LibBinaryMerkleTree for bytes32[];
    using LibBytes for bytes;
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

    /// @notice Whether the accounts drive Merkle root was proved.
    /// @dev See the `getAccountsDriveMerkleRoot` and
    /// `proveAccountsDriveMerkleRoot` functions.
    bool internal _wasAccountsDriveMerkleRootProved;

    /// @notice The accounts drive Merkle root.
    /// @dev See the `getAccountsDriveMerkleRoot` and
    /// `proveAccountsDriveMerkleRoot` functions.
    bytes32 internal _accountsDriveMerkleRoot;

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
        require(
            withdrawalConfig.isValid(),
            IApplicationFactoryErrors.InvalidWithdrawalConfig(withdrawalConfig)
        );
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

        if (_executed.get(outputIndex)) {
            revert OutputNotReexecutable(output);
        }

        _executeOutput(output);

        _executed.set(outputIndex);

        ++_numOfExecutedOutputs;
        emit OutputExecuted(outputIndex, output);
    }

    function proveAccountsDriveMerkleRoot(
        bytes32 accountsDriveMerkleRoot,
        bytes32[] calldata proof
    ) external override onlyForeclosed {
        if (_wasAccountsDriveMerkleRootProved) {
            revert AccountsDriveMerkleRootAlreadyProved();
        }

        if (
            proof.length
                != (CanonicalMachine.LOG2_MEMORY_SIZE - _getLog2AccountsDriveSize())
        ) {
            revert InvalidAccountsDriveMerkleRootProofSize();
        }

        // The Merkle root computation below should not raise an InvalidNodeIndex error
        // because the LibWithdrawalConfig.isValid function run at the constructor
        // guarantees that
        // getAccountsDriveStartIndex() >> proof.length == 0.

        bytes32 machineMerkleRoot = proof.merkleRootAfterReplacement(
            getAccountsDriveStartIndex(), accountsDriveMerkleRoot, LibKeccak256.hashPair
        );

        // There is no risk of reentrancy attacks when retrieving the last-finalized
        // machine Merkle root from the outputs Merkle root validator because it is done
        // through a static call, which reverts on any state change.

        bytes32 lastFinalizedMachineMerkleRoot = _getLastFinalizedMachineMerkleRoot();

        if (machineMerkleRoot != lastFinalizedMachineMerkleRoot) {
            revert InvalidMachineMerkleRoot(machineMerkleRoot);
        }

        _accountsDriveMerkleRoot = accountsDriveMerkleRoot;
        _wasAccountsDriveMerkleRootProved = true;
    }

    function withdraw(bytes calldata account, AccountValidityProof calldata proof)
        external
        override
        nonReentrant
        onlyForeclosed
    {
        validateAccount(account, proof);

        bytes memory output = _buildWithdrawalOutput(account);

        uint64 accountIndex = proof.accountIndex;

        if (_withdrawn.get(accountIndex)) {
            revert AccountFundsAlreadyWithdrawn(accountIndex);
        }

        _executeOutput(output);

        _withdrawn.set(accountIndex);

        ++_numOfWithdrawals;
        emit Withdrawal(accountIndex, account, output);
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

    function validateAccount(bytes calldata account, AccountValidityProof calldata proof)
        public
        view
        override
    {
        bytes32 accountMerkleRoot = account.merkleRoot(
            CanonicalMachine.LOG2_DATA_BLOCK_SIZE + getLog2LeavesPerAccount(),
            CanonicalMachine.LOG2_DATA_BLOCK_SIZE,
            LibKeccak256.hashBlock,
            LibKeccak256.hashPair
        );

        validateAccountMerkleRoot(accountMerkleRoot, proof);
    }

    function validateAccountMerkleRoot(
        bytes32 accountMerkleRoot,
        AccountValidityProof calldata proof
    ) public view override {
        if (!proof.isSiblingsArrayLengthValid(getLog2MaxNumOfAccounts())) {
            revert InvalidAccountRootSiblingsArrayLength();
        }

        if (!_wasAccountsDriveMerkleRootProved) {
            revert AccountsDriveMerkleRootNotProved();
        }

        bytes32 accountsDriveMerkleRoot =
            proof.computeAccountsDriveMerkleRoot(accountMerkleRoot);

        if (accountsDriveMerkleRoot != _accountsDriveMerkleRoot) {
            revert InvalidAccountsDriveMerkleRoot(accountsDriveMerkleRoot);
        }
    }

    /// @inheritdoc IApplication
    function getTemplateHash() external view override returns (bytes32) {
        return TEMPLATE_HASH;
    }

    /// @inheritdoc IApplication
    function getOutputsMerkleRootValidator()
        public
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

    function getLog2LeavesPerAccount() public view override returns (uint8) {
        return LOG2_LEAVES_PER_ACCOUNT;
    }

    function getLog2MaxNumOfAccounts() public view override returns (uint8) {
        return LOG2_MAX_NUM_OF_ACCOUNTS;
    }

    function getAccountsDriveStartIndex() public view override returns (uint64) {
        return ACCOUNTS_DRIVE_START_INDEX;
    }

    function getGuardian() public view override returns (address) {
        return GUARDIAN;
    }

    function getWithdrawalOutputBuilder()
        public
        view
        override
        returns (IWithdrawalOutputBuilder)
    {
        return WITHDRAWAL_OUTPUT_BUILDER;
    }

    function isForeclosed() public view override returns (bool) {
        return _isForeclosed;
    }

    function getAccountsDriveMerkleRoot()
        external
        view
        override
        returns (bool wasAccountsDriveMerkleRootProved, bytes32 accountsDriveMerkleRoot)
    {
        wasAccountsDriveMerkleRootProved = _wasAccountsDriveMerkleRootProved;
        accountsDriveMerkleRoot = _accountsDriveMerkleRoot;
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

    modifier onlyForeclosed() {
        _ensureAppIsForeclosed();
        _;
    }

    /// @notice Get the log (base 2) of the number of bytes in the machine memory that are
    /// reserved for the accounts drive.
    function _getLog2AccountsDriveSize() internal view returns (uint8) {
        return getLog2MaxNumOfAccounts() + getLog2LeavesPerAccount()
            + CanonicalMachine.LOG2_DATA_BLOCK_SIZE;
    }

    /// @notice Check if an outputs Merkle root is valid,
    /// according to the current outputs Merkle root validator.
    /// @param outputsMerkleRoot The output Merkle root
    function _isOutputsMerkleRootValid(bytes32 outputsMerkleRoot)
        internal
        view
        returns (bool)
    {
        return getOutputsMerkleRootValidator()
            .isOutputsMerkleRootValid(address(this), outputsMerkleRoot);
    }

    /// @notice Get the last finalized machine Merkle root,
    /// according to the current outputs Merkle root validator.
    /// @return lastFinalizedMachineMerkleRoot The last finalized machine Merkle root
    function _getLastFinalizedMachineMerkleRoot()
        internal
        view
        returns (bytes32 lastFinalizedMachineMerkleRoot)
    {
        return getOutputsMerkleRootValidator()
            .getLastFinalizedMachineMerkleRoot(address(this));
    }

    /// @notice Build a withdrawal output from an account,
    /// using the withdrawal output builder contract.
    /// @param account The account
    /// @return output The withdrawal output
    function _buildWithdrawalOutput(bytes calldata account)
        internal
        view
        returns (bytes memory output)
    {
        return getWithdrawalOutputBuilder().buildWithdrawalOutput(account);
    }

    /// @notice Executes an output
    /// @param output The output
    function _executeOutput(bytes memory output) internal {
        bool isOutputExecutable;
        bytes4 selector;
        bytes memory arguments;

        (isOutputExecutable, selector, arguments) = output.consumeBytes4();

        require(isOutputExecutable, OutputNotExecutable(output));

        if (selector == Outputs.Voucher.selector) {
            _executeVoucher(arguments);
        } else if (selector == Outputs.DelegateCallVoucher.selector) {
            _executeDelegateCallVoucher(arguments);
        } else {
            revert OutputNotExecutable(output);
        }
    }

    /// @notice Executes a voucher
    /// @param arguments ABI-encoded arguments
    function _executeVoucher(bytes memory arguments) internal {
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
    function _executeDelegateCallVoucher(bytes memory arguments) internal {
        address destination;
        bytes memory payload;

        (destination, payload) = abi.decode(arguments, (address, bytes));

        destination.safeDelegateCall(payload);
    }

    /// @notice Ensures the message sender is the guardian.
    function _ensureMsgSenderIsGuardian() internal view {
        require(msg.sender == getGuardian(), NotGuardian());
    }

    /// @notice Ensures the application is foreclosed.
    function _ensureAppIsForeclosed() internal view {
        require(isForeclosed(), NotForeclosed());
    }
}

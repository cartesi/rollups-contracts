// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IOwnable} from "../access/IOwnable.sol";
import {AccountValidityProof} from "../common/AccountValidityProof.sol";
import {CanonicalMachine} from "../common/CanonicalMachine.sol";
import {Inputs} from "../common/Inputs.sol";
import {OutputValidityProof} from "../common/OutputValidityProof.sol";
import {Outputs} from "../common/Outputs.sol";
import {RollupsContract} from "../common/RollupsContract.sol";
import {WithdrawalConfig} from "../common/WithdrawalConfig.sol";
import {IOutputsMerkleRootValidator} from "../consensus/IOutputsMerkleRootValidator.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {LibAccountValidityProof} from "../library/LibAccountValidityProof.sol";
import {LibAddress} from "../library/LibAddress.sol";
import {LibBinaryMerkleTree} from "../library/LibBinaryMerkleTree.sol";
import {LibBytes} from "../library/LibBytes.sol";
import {LibKeccak256} from "../library/LibKeccak256.sol";
import {LibOutputValidityProof} from "../library/LibOutputValidityProof.sol";
import {LibWithdrawalConfig} from "../library/LibWithdrawalConfig.sol";
import {IRefundOutputBuilder} from "../refund/IRefundOutputBuilder.sol";
import {IWithdrawalOutputBuilder} from "../withdrawal/IWithdrawalOutputBuilder.sol";
import {IApplication} from "./IApplication.sol";
import {IApplicationFactoryErrors} from "./IApplicationFactoryErrors.sol";

import {Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable.sol";
import {ERC1155Holder} from "@openzeppelin-contracts-5.2.0/token/ERC1155/utils/ERC1155Holder.sol";
import {ERC721Holder} from "@openzeppelin-contracts-5.2.0/token/ERC721/utils/ERC721Holder.sol";
import {BitMaps} from "@openzeppelin-contracts-5.2.0/utils/structs/BitMaps.sol";

contract Application is
    IApplication,
    Ownable,
    ERC721Holder,
    ERC1155Holder,
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

    /// @notice The input box contract.
    /// @dev See the `getInputBox` function.
    IInputBox immutable INPUT_BOX;

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

    /// @notice The refund output builder contract.
    /// @dev See the `getRefundOutputBuilder` function.
    IRefundOutputBuilder immutable REFUND_OUTPUT_BUILDER;

    /// @notice The withdrawal output builder contract.
    /// @dev See the `getWithdrawalOutputBuilder` function.
    IWithdrawalOutputBuilder immutable WITHDRAWAL_OUTPUT_BUILDER;

    /// @notice Keeps track of which outputs have been executed.
    /// @dev See the `wasOutputExecuted` function.
    BitMaps.BitMap internal _executed;

    /// @notice Keeps track of which inputs have been refunded.
    /// @dev See the `wasRefundForInputIssued` function.
    BitMaps.BitMap internal _refunded;

    /// @notice Keeps track of which accounts have been withdrawn.
    /// @dev See the `wereAccountFundsWithdrawn` function.
    BitMaps.BitMap internal _withdrawn;

    /// @notice The current outputs Merkle root validator contract.
    /// @dev See the `getOutputsMerkleRootValidator` and `migrateToOutputsMerkleRootValidator` functions.
    IOutputsMerkleRootValidator internal _outputsMerkleRootValidator;

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

    /// @notice The number of refunds issued by the application.
    /// @dev See the `getNumberOfIssuedRefunds` function.
    uint256 _numOfIssuedRefunds;

    /// @notice The number of withdrawals from the application.
    /// @dev See the `getNumberOfWithdrawals` function.
    uint256 _numOfWithdrawals;

    /// @notice Creates an `Application` contract.
    /// @param outputsMerkleRootValidator The initial outputs Merkle root validator contract
    /// @param initialOwner The initial application owner
    /// @param templateHash The initial machine state hash
    /// @param inputBox The input box contract
    /// @param refundOutputBuilder The refund output builder
    /// @param withdrawalConfig The withdrawal configuration
    /// @dev Reverts if the initial application owner address is zero.
    constructor(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address initialOwner,
        bytes32 templateHash,
        IInputBox inputBox,
        IRefundOutputBuilder refundOutputBuilder,
        WithdrawalConfig memory withdrawalConfig
    ) Ownable(initialOwner) {
        require(
            withdrawalConfig.isValid(),
            IApplicationFactoryErrors.InvalidWithdrawalConfig(withdrawalConfig)
        );
        TEMPLATE_HASH = templateHash;
        INPUT_BOX = inputBox;
        GUARDIAN = withdrawalConfig.guardian;
        LOG2_LEAVES_PER_ACCOUNT = withdrawalConfig.log2LeavesPerAccount;
        LOG2_MAX_NUM_OF_ACCOUNTS = withdrawalConfig.log2MaxNumOfAccounts;
        ACCOUNTS_DRIVE_START_INDEX = withdrawalConfig.accountsDriveStartIndex;
        REFUND_OUTPUT_BUILDER = refundOutputBuilder;
        WITHDRAWAL_OUTPUT_BUILDER = withdrawalConfig.withdrawalOutputBuilder;
        _outputsMerkleRootValidator = outputsMerkleRootValidator;
    }

    /// @notice Accept Ether transfers.
    /// @dev If you wish to transfer Ether to an application while informing
    ///      the backend of it, then please do so through the Ether portal contract.
    receive() external payable {}

    /// @inheritdoc IApplication
    function executeOutput(bytes calldata output, OutputValidityProof calldata proof)
        external
        override
    {
        // Checks

        validateOutput(output, proof);

        if (_executed.get(proof.outputIndex)) {
            revert OutputNotReexecutable(output);
        }

        // Effects

        _executed.set(proof.outputIndex);
        ++_numOfExecutedOutputs;
        emit OutputExecuted(proof.outputIndex, output);

        // Interactions

        _executeOutput(output);
    }

    function issueRefund(uint256 inputIndex, bytes calldata input)
        external
        override
        onlyForeclosed
    {
        // Checks

        if (_refunded.get(inputIndex)) {
            revert RefundAlreadyIssued(inputIndex);
        }

        (uint256 blockNumber, address sender, bytes memory payload) =
            validateInput(inputIndex, input);

        if (_wasInputFinalized(inputIndex, blockNumber)) {
            revert CannotRefundFinalizedInput(inputIndex);
        }

        bytes memory output = _buildRefundOutput(sender, payload);

        // Effects

        _refunded.set(inputIndex);
        ++_numOfIssuedRefunds;
        emit RefundIssued(inputIndex, input, output);

        // Interactions

        _executeOutput(output);
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

        emit AccountsDriveMerkleRootProved(accountsDriveMerkleRoot);
    }

    function withdraw(bytes calldata account, AccountValidityProof calldata proof)
        external
        override
        onlyForeclosed
    {
        // Checks

        validateAccount(account, proof);

        if (_withdrawn.get(proof.accountIndex)) {
            revert AccountFundsAlreadyWithdrawn(proof.accountIndex);
        }

        bytes memory output = _buildWithdrawalOutput(account);

        // Effects

        _withdrawn.set(proof.accountIndex);
        ++_numOfWithdrawals;
        emit Withdrawal(proof.accountIndex, account, output);

        // Interactions

        _executeOutput(output);
    }

    /// @inheritdoc IApplication
    function migrateToOutputsMerkleRootValidator(IOutputsMerkleRootValidator newOutputsMerkleRootValidator)
        external
        override
        onlyOwner
        notForeclosed
        onDeploymentBlock
    {
        _outputsMerkleRootValidator = newOutputsMerkleRootValidator;
        emit OutputsMerkleRootValidatorChanged(newOutputsMerkleRootValidator);
    }

    function foreclose() external override onlyGuardian notForeclosed {
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

    function wasRefundForInputIssued(uint256 inputIndex)
        external
        view
        override
        returns (bool)
    {
        return _refunded.get(inputIndex);
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

    function validateInput(uint256 inputIndex, bytes calldata input)
        public
        view
        override
        returns (uint256 blockNumber, address inputSender, bytes memory inputPayload)
    {
        validateInputHash(inputIndex, keccak256(input));

        require(
            (input.length >= 4) && (bytes4(input[:4]) == Inputs.EvmAdvance.selector),
            IllFormedInput()
        );

        uint256 chainId;
        address appContract;
        uint256 blockTimestamp;
        uint256 index;

        (
            chainId,
            appContract,
            inputSender,
            blockNumber,
            blockTimestamp,/* prevRandao */,
            index,
            inputPayload
        ) =
            abi.decode(
                input[4:],
                (uint256, address, address, uint256, uint256, uint256, uint256, bytes)
            );

        require(
            (chainId == block.chainid) && (appContract == address(this))
                && (blockNumber <= block.number) && (blockTimestamp <= block.timestamp)
                && (index == inputIndex),
            IllFormedInput()
        );
    }

    function validateInputHash(uint256 inputIndex, bytes32 inputHash)
        public
        view
        override
    {
        IInputBox inputBox = getInputBox();
        uint256 numOfInputs = inputBox.getNumberOfInputs(address(this));
        require(inputIndex < numOfInputs, InvalidInputIndex(inputIndex, numOfInputs));
        bytes32 stInputHash = inputBox.getInputHash(address(this), inputIndex);
        require(stInputHash == inputHash, InvalidInputHash(stInputHash, inputHash));
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
    function getTemplateHash() public view override returns (bytes32) {
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

    function getInputBox() public view override returns (IInputBox) {
        return INPUT_BOX;
    }

    /// @inheritdoc IApplication
    function getDeploymentBlockNumber() external view override returns (uint256) {
        return DEPLOYMENT_BLOCK_NUMBER;
    }

    /// @inheritdoc IApplication
    function getNumberOfExecutedOutputs() external view override returns (uint256) {
        return _numOfExecutedOutputs;
    }

    function getNumberOfIssuedRefunds() external view override returns (uint256) {
        return _numOfIssuedRefunds;
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

    function getRefundOutputBuilder()
        public
        view
        override
        returns (IRefundOutputBuilder)
    {
        return REFUND_OUTPUT_BUILDER;
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

    function getWithdrawalConfig()
        external
        view
        override
        returns (WithdrawalConfig memory withdrawalConfig)
    {
        return WithdrawalConfig({
            guardian: getGuardian(),
            log2LeavesPerAccount: getLog2LeavesPerAccount(),
            log2MaxNumOfAccounts: getLog2MaxNumOfAccounts(),
            accountsDriveStartIndex: getAccountsDriveStartIndex(),
            withdrawalOutputBuilder: getWithdrawalOutputBuilder()
        });
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

    modifier notForeclosed() {
        _ensureAppIsNotForeclosed();
        _;
    }

    modifier onlyForeclosed() {
        _ensureAppIsForeclosed();
        _;
    }

    modifier onDeploymentBlock() {
        _ensureOnDeploymentBlock();
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
    /// @dev If the outputs Merkle root validator returns a zeroed bytes32 value,
    /// signaling that no machine Merkle root has been finalized yet, we instead use the
    /// immutable template hash value set at construction time.
    function _getLastFinalizedMachineMerkleRoot()
        internal
        view
        returns (bytes32 lastFinalizedMachineMerkleRoot)
    {
        lastFinalizedMachineMerkleRoot = getOutputsMerkleRootValidator()
            .getLastFinalizedMachineMerkleRoot(address(this));

        if (lastFinalizedMachineMerkleRoot == bytes32(0)) {
            lastFinalizedMachineMerkleRoot = getTemplateHash();
        }
    }

    /// @notice Check if an input was finalized,
    /// according to the current outputs Merkle root validator.
    /// @param inputIndex The index of the input in the application's input box
    /// @param blockNumber The number of the base-layer block in which the input was added
    function _wasInputFinalized(uint256 inputIndex, uint256 blockNumber)
        internal
        view
        returns (bool)
    {
        return getOutputsMerkleRootValidator()
            .wasInputFinalized(address(this), inputIndex, blockNumber);
    }

    /// @notice Build a refund output from an input,
    /// using the refund output builder contract.
    /// @param sender The input sender
    /// @param payload The input payload
    /// @return output The refund output
    function _buildRefundOutput(address sender, bytes memory payload)
        internal
        view
        returns (bytes memory output)
    {
        return getRefundOutputBuilder().buildRefundOutput(address(this), sender, payload);
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
        return getWithdrawalOutputBuilder().buildWithdrawalOutput(address(this), account);
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

        destination.safeCall(value, payload);
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

    /// @notice Ensures the application is not foreclosed.
    function _ensureAppIsNotForeclosed() internal view {
        require(!isForeclosed(), Foreclosed());
    }

    /// @notice Ensures the application is foreclosed.
    function _ensureAppIsForeclosed() internal view {
        require(isForeclosed(), NotForeclosed());
    }

    /// @notice Ensures the current block is the deployment block.
    function _ensureOnDeploymentBlock() internal view {
        require(block.number == DEPLOYMENT_BLOCK_NUMBER, NotDeploymentBlock());
    }
}

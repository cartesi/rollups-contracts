// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {AccountValidityProof} from "src/common/AccountValidityProof.sol";
import {BinaryMerkleTreeErrors} from "src/common/BinaryMerkleTreeErrors.sol";
import {CanonicalMachine} from "src/common/CanonicalMachine.sol";
import {DataAvailability} from "src/common/DataAvailability.sol";
import {OutputValidityProof} from "src/common/OutputValidityProof.sol";
import {Outputs} from "src/common/Outputs.sol";
import {WithdrawalConfig} from "src/common/WithdrawalConfig.sol";
import {IOutputsMerkleRootValidator} from "src/consensus/IOutputsMerkleRootValidator.sol";
import {Authority} from "src/consensus/authority/Authority.sol";
import {IAuthority} from "src/consensus/authority/IAuthority.sol";
import {Application} from "src/dapp/Application.sol";
import {IApplication} from "src/dapp/IApplication.sol";
import {IApplicationForeclosure} from "src/dapp/IApplicationForeclosure.sol";
import {IApplicationWithdrawal} from "src/dapp/IApplicationWithdrawal.sol";
import {ISafeERC20Transfer} from "src/delegatecall/ISafeERC20Transfer.sol";
import {SafeERC20Transfer} from "src/delegatecall/SafeERC20Transfer.sol";
import {IInputBox} from "src/inputs/IInputBox.sol";
import {InputBox} from "src/inputs/InputBox.sol";
import {LibUsdAccount} from "src/library/LibUsdAccount.sol";
import {UsdWithdrawalOutputBuilder} from "src/withdrawal/UsdWithdrawalOutputBuilder.sol";

import {
    IERC1155Errors,
    IERC20Errors,
    IERC721Errors
} from "@openzeppelin-contracts-5.2.0/interfaces/draft-IERC6093.sol";
import {IERC1155} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155.sol";
import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin-contracts-5.2.0/token/ERC721/IERC721.sol";
import {SafeCast} from "@openzeppelin-contracts-5.2.0/utils/math/SafeCast.sol";

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {ExternalLibBinaryMerkleTree} from "../library/LibBinaryMerkleTree.t.sol";
import {ExternalLibUsdAccount} from "../library/LibUsdAccount.t.sol";
import {AddressGenerator} from "../util/AddressGenerator.sol";
import {ConsensusTestUtils} from "../util/ConsensusTestUtils.sol";
import {EtherReceiver, IEtherReceiver} from "../util/EtherReceiver.sol";
import {LibBytes} from "../util/LibBytes.sol";
import {LibBytes32Array} from "../util/LibBytes32Array.sol";
import {LibEmulator} from "../util/LibEmulator.sol";
import {LibTopic} from "../util/LibTopic.sol";
import {OwnableTest} from "../util/OwnableTest.sol";
import {SimpleBatchERC1155, SimpleSingleERC1155} from "../util/SimpleERC1155.sol";
import {SimpleERC20} from "../util/SimpleERC20.sol";
import {SimpleERC721} from "../util/SimpleERC721.sol";

contract ApplicationTest is Test, OwnableTest, AddressGenerator, ConsensusTestUtils {
    using LibBytes for bytes;
    using LibTopic for address;
    using SafeCast for uint256;
    using LibBytes32Array for bytes32[];
    using LibEmulator for LibEmulator.State;
    using LibEmulator for LibEmulator.ProofComponents;
    using ExternalLibBinaryMerkleTree for bytes32[];

    IApplication _appContract;
    IEtherReceiver _etherReceiver;
    IAuthority _authority;
    IERC20 _erc20Token;
    IERC20 _usd;
    IERC721 _erc721Token;
    IERC1155 _erc1155SingleToken;
    IERC1155 _erc1155BatchToken;
    ISafeERC20Transfer _safeErc20Transfer;
    IInputBox _inputBox;

    LibEmulator.State _emulator;
    LibEmulator.ProofComponents _proofComponents;
    address _appOwner;
    address _authorityOwner;
    address _recipient;
    address _tokenOwner;
    bytes _dataAvailability;
    string[] _outputNames;
    string[] _accountNames;
    uint256[] _tokenIds;
    uint256[] _initialSupplies;
    uint256[] _transferAmounts;
    mapping(string => LibEmulator.OutputIndex) _outputIndexByName;
    mapping(string => LibEmulator.AccountIndex) _accountIndexByName;
    WithdrawalConfig _withdrawalConfig;

    uint256 constant EPOCH_LENGTH = 1;
    bytes32 constant TEMPLATE_HASH = keccak256("templateHash");
    uint256 constant INITIAL_SUPPLY = 1000000000000000000000000000000000000;
    uint256 constant TOKEN_ID = 88888888;
    uint256 constant TRANSFER_AMOUNT = 42;

    function setUp() public {
        _initVariables();
        _deployContracts();
        _addOutputs();
        _addAccounts();
        _submitClaim();
    }

    // ------------
    // ownable test
    // ------------

    function testRenounceOwnership(uint256) external {
        _testRenounceOwnership(_appContract);
    }

    function testUnauthorizedAccount(uint256) external {
        _testUnauthorizedAccount(_appContract);
    }

    function testInvalidOwner(uint256) external {
        _testInvalidOwner(_appContract);
    }

    function testTransferOwnership(uint256) external {
        _testTransferOwnership(_appContract);
    }

    // ---------------------------------------
    // outputs Merkle root validator migration
    // ---------------------------------------

    function testMigrateToOutputsMerkleRootValidatorRevertsUnauthorized(
        address caller,
        IOutputsMerkleRootValidator newOutputsMerkleRootValidator
    ) external {
        vm.assume(caller != _appOwner);
        vm.startPrank(caller);
        vm.expectRevert(_encodeOwnableUnauthorizedAccount(caller));
        _appContract.migrateToOutputsMerkleRootValidator(newOutputsMerkleRootValidator);
    }

    function testMigrateToOutputsMerkleRootValidator(IOutputsMerkleRootValidator newOutputsMerkleRootValidator)
        external
    {
        vm.prank(_appOwner);
        vm.expectEmit(false, false, false, true, address(_appContract));
        emit IApplication.OutputsMerkleRootValidatorChanged(newOutputsMerkleRootValidator);
        _appContract.migrateToOutputsMerkleRootValidator(newOutputsMerkleRootValidator);
        assertEq(
            address(_appContract.getOutputsMerkleRootValidator()),
            address(newOutputsMerkleRootValidator)
        );
    }

    // -----------
    // foreclosure
    // -----------

    function testForecloseRevertsNotGuardian(address caller) external {
        vm.assume(caller != _appContract.getGuardian());
        assertFalse(_appContract.isForeclosed());
        vm.expectRevert(IApplicationForeclosure.NotGuardian.selector);
        vm.prank(caller);
        _appContract.foreclose();
    }

    function testForeclose() external {
        assertFalse(_appContract.isForeclosed());

        // check the idempotence of the `foreclose()` function.
        for (uint256 i; i < 3; ++i) {
            vm.expectEmit(true, true, true, true, address(_appContract));
            emit IApplicationForeclosure.Foreclosure();
            vm.prank(_appContract.getGuardian());
            _appContract.foreclose();
            assertTrue(_appContract.isForeclosed());
        }
    }

    // -----------------
    // output validation
    // -----------------

    function testValidateOutputs() external view {
        _validateOutputs();
    }

    function testValidateOutputsAfterForeclosure() external {
        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();
        _validateOutputs();
    }

    function testRevertsInvalidOutputHashesSiblingsArrayLength(bytes32[] calldata invalidOutputHashesSiblings)
        external
    {
        string memory name = _getRandomOutputName();
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        // We assume the proof provided by the emulator library has the correct length,
        // and that the proof provided by the fuzzer has a different, incorrect length.
        vm.assume(invalidOutputHashesSiblings.length != proof.outputHashesSiblings.length);

        proof.outputHashesSiblings = invalidOutputHashesSiblings;

        vm.expectRevert(_encodeInvalidOutputHashesSiblingsArrayLength());
        _appContract.validateOutput(output, proof);

        vm.expectRevert(_encodeInvalidOutputHashesSiblingsArrayLength());
        _appContract.validateOutputHash(keccak256(output), proof);
    }

    function testRevertsInvalidOutputsMerkleRoot(bytes calldata invalidOutput) external {
        string memory name = _getRandomOutputName();
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        bytes32 invalidOutputHash = keccak256(invalidOutput);

        // assume the output provided by the fuzzer isn't
        // the output whose proof we will be using.
        vm.assume(keccak256(output) != invalidOutputHash);

        bytes32 invalidOutputsMerkleRoot =
            proof.outputHashesSiblings
                .merkleRootAfterReplacement(proof.outputIndex, invalidOutputHash);

        vm.expectRevert(_encodeInvalidOutputsMerkleRoot(invalidOutputsMerkleRoot));
        _appContract.validateOutput(invalidOutput, proof);

        vm.expectRevert(_encodeInvalidOutputsMerkleRoot(invalidOutputsMerkleRoot));
        _appContract.validateOutputHash(invalidOutputHash, proof);
    }

    function testRevertsInvalidOutputsMerkleRoot(uint256) external {
        string memory name = _getRandomOutputName();
        bytes memory output = _getOutput(name);
        bytes32 outputHash = keccak256(output);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        uint64 outputIndex = vm.randomUint(CanonicalMachine.LOG2_MAX_OUTPUTS).toUint64();

        // assume the output index provided by the fuzzer isn't
        // the actual output index provided by the emulator.
        // we assume that outputs are unique.
        vm.assume(outputIndex != proof.outputIndex);

        proof.outputIndex = outputIndex;

        bytes32 invalidOutputsMerkleRoot =
            proof.outputHashesSiblings
                .merkleRootAfterReplacement(proof.outputIndex, outputHash);

        vm.expectRevert(_encodeInvalidOutputsMerkleRoot(invalidOutputsMerkleRoot));
        _appContract.validateOutput(output, proof);

        vm.expectRevert(_encodeInvalidOutputsMerkleRoot(invalidOutputsMerkleRoot));
        _appContract.validateOutputHash(outputHash, proof);
    }

    function testRevertsInvalidNodeIndex(uint256) external {
        string memory name = _getRandomOutputName();
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        uint256 invalidOutputIndex =
            vm.randomUint(1 << CanonicalMachine.LOG2_MAX_OUTPUTS, type(uint64).max);

        assertNotEq(invalidOutputIndex, proof.outputIndex);

        proof.outputIndex = invalidOutputIndex.toUint64();

        vm.expectRevert(_encodeInvalidNodeIndex(invalidOutputIndex));
        _appContract.validateOutput(output, proof);

        vm.expectRevert(_encodeInvalidNodeIndex(invalidOutputIndex));
        _appContract.validateOutputHash(keccak256(output), proof);
    }

    // ----------------
    // output execution
    // ----------------

    function testWasOutputExecuted(uint256 outputIndex) external view {
        assertFalse(_appContract.wasOutputExecuted(outputIndex));
    }

    function testExecuteEtherTransferVoucher() external {
        string memory name = "EtherTransferVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        _testEtherTransfer(output, proof);
    }

    function testExecuteEtherMintVoucher() external {
        string memory name = "EtherMintVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        _testEtherMint(output, proof);
    }

    function testExecuteERC20TransferVoucher() external {
        string memory name = "ERC20TransferVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        assertLt(
            _erc20Token.balanceOf(address(_appContract)),
            TRANSFER_AMOUNT,
            "Application contract does not have enough ERC-20 tokens"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                address(_appContract),
                _erc20Token.balanceOf(address(_appContract)),
                TRANSFER_AMOUNT
            )
        );
        _appContract.executeOutput(output, proof);

        _testErc20Success(output, proof);
    }

    function testExecuteERC721TransferVoucher() external {
        string memory name = "ERC721TransferVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        _testErc721Transfer(output, proof);
    }

    function testExecuteERC1155SingleTransferVoucher() external {
        string memory name = "ERC1155SingleTransferVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        _testErc1155SingleTransfer(output, proof);
    }

    function testExecuteERC1155BatchTransferVoucher() external {
        string memory name = "ERC1155BatchTransferVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        _testErc1155BatchTransfer(output, proof);
    }

    function testExecuteEmptyOutput() external {
        string memory name = "EmptyOutput";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        vm.expectRevert(_encodeOutputNotExecutable(output));
        _appContract.executeOutput(output, proof);
    }

    function testExecuteMyOutput() external {
        string memory name = "MyOutput";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        vm.expectRevert(_encodeOutputNotExecutable(output));
        _appContract.executeOutput(output, proof);
    }

    function testExecuteNotice() external {
        string memory name = "HelloWorldNotice";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        vm.expectRevert(_encodeOutputNotExecutable(output));
        _appContract.executeOutput(output, proof);
    }

    function testExecuteERC20TransferDelegateCallVoucherFail() external {
        string memory name = "ERC20DelegateCallVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        _testErc20Fail(output, proof);
    }

    function testExecuteERC20TransferDelegateCallVoucherSuccess() external {
        string memory name = "ERC20DelegateCallVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        _testErc20Success(output, proof);
    }

    // ------------------
    // account validation
    // ------------------

    function testValidateAccounts() external view {
        _validateAccounts();
    }

    function testValidateAccountsAfterForeclosure() external {
        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();
        _validateAccounts();
    }

    function testRevertsInvalidAccountRootSiblingsArrayLength(bytes32[] calldata invalidAccountRootSiblings)
        external
    {
        string memory name = _getRandomAccountName();
        bytes memory account = _getAccount(name);
        bytes32 accountMerkleRoot = LibEmulator.getAccountMerkleRoot(account);
        AccountValidityProof memory proof = _getAccountValidityProof(name);

        // We assume the proof provided by the emulator library has the correct length,
        // and that the proof provided by the fuzzer has a different, incorrect length.
        vm.assume(invalidAccountRootSiblings.length != proof.accountRootSiblings.length);

        proof.accountRootSiblings = invalidAccountRootSiblings;

        vm.expectRevert(_encodeInvalidAccountRootSiblingsArrayLength());
        _appContract.validateAccount(account, proof);

        vm.expectRevert(_encodeInvalidAccountRootSiblingsArrayLength());
        _appContract.validateAccountMerkleRoot(accountMerkleRoot, proof);
    }

    function testRevertsInvalidAccountIndex(uint256) external {
        string memory name = _getRandomAccountName();
        bytes memory account = _getAccount(name);
        bytes32 accountMerkleRoot = LibEmulator.getAccountMerkleRoot(account);
        AccountValidityProof memory proof = _getAccountValidityProof(name);

        uint256 numOfAccounts = 1 << LibEmulator.getAccountsDriveRootNodeHeight();
        uint256 invalidAccountIndex = vm.randomUint(numOfAccounts, type(uint64).max);

        assertNotEq(invalidAccountIndex, proof.accountIndex);

        proof.accountIndex = invalidAccountIndex.toUint64();

        vm.expectRevert(_encodeInvalidAccountIndex());
        _appContract.validateAccount(account, proof);

        vm.expectRevert(_encodeInvalidAccountIndex());
        _appContract.validateAccountMerkleRoot(accountMerkleRoot, proof);
    }

    function testRevertsInvalidMachineMerkleRoot(uint256) external {
        string memory name = _getRandomAccountName();
        bytes memory account = _getAccount(name);
        AccountValidityProof memory proof = _getAccountValidityProof(name);

        bytes memory invalidAccount = _generateAccount();

        bytes32 invalidAccountMerkleRoot =
            LibEmulator.getAccountMerkleRoot(invalidAccount);

        // assume the account provided by the fuzzer isn't
        // the account whose proof we will be using.
        vm.assume(LibEmulator.getAccountMerkleRoot(account) != invalidAccountMerkleRoot);

        (bytes32[] memory siblings1, bytes32[] memory siblings2) =
            proof.accountRootSiblings.split(LibEmulator.LOG2_MAX_NUM_OF_ACCOUNTS);

        bytes32 invalidAccountsDriveMerkleRoot =
            ExternalLibBinaryMerkleTree.merkleRootAfterReplacement(
                siblings1, proof.accountIndex, invalidAccountMerkleRoot
            );

        bytes32 invalidMachineMerkleRoot =
            ExternalLibBinaryMerkleTree.merkleRootAfterReplacement(
                siblings2,
                LibEmulator.ACCOUNTS_DRIVE_START_INDEX,
                invalidAccountsDriveMerkleRoot
            );

        vm.expectRevert(_encodeInvalidMachineMerkleRoot(invalidMachineMerkleRoot));
        _appContract.validateAccount(invalidAccount, proof);

        vm.expectRevert(_encodeInvalidMachineMerkleRoot(invalidMachineMerkleRoot));
        _appContract.validateAccountMerkleRoot(invalidAccountMerkleRoot, proof);
    }

    function testRevertsDriveSmallerThanData(uint256) external {
        string memory name = _getRandomAccountName();
        AccountValidityProof memory proof = _getAccountValidityProof(name);

        bytes memory invalidAccount = _generateIllSizedAccount();

        vm.expectRevert(_encodeDriveSmallerThanData(invalidAccount.length));
        _appContract.validateAccount(invalidAccount, proof);
    }

    // ----------
    // withdrawal
    // ----------

    function testWithdrawalRevertsNotForeclosed(uint256) external {
        string memory name = "Alice";
        bytes memory account = _getAccount(name);
        (, uint256 amount) = ExternalLibUsdAccount.decode(account);
        AccountValidityProof memory proof = _getAccountValidityProof(name);

        uint256 balance = vm.randomUint(amount, _usd.balanceOf(_tokenOwner));

        vm.prank(_tokenOwner);
        assertTrue(_usd.transfer(address(_appContract), balance));

        vm.expectRevert(IApplicationWithdrawal.NotForeclosed.selector);

        vm.prank(vm.randomAddress());
        _appContract.withdraw(account, proof);
    }

    function testWithdrawalRevertsERC20InsufficientBalance(uint256) external {
        string memory name = "Alice";
        bytes memory account = _getAccount(name);
        (, uint256 amount) = ExternalLibUsdAccount.decode(account);
        AccountValidityProof memory proof = _getAccountValidityProof(name);

        uint256 balance = vm.randomUint(0, amount - 1);

        vm.prank(_tokenOwner);
        assertTrue(_usd.transfer(address(_appContract), balance));

        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();

        vm.expectRevert(_encodeErc20InsufficientBalance(_usd, amount));

        vm.prank(vm.randomAddress());
        _appContract.withdraw(account, proof);
    }

    function testWithdrawalRevertsBubbleUp(bytes calldata error) external {
        string memory name = "Alice";
        bytes memory account = _getAccount(name);
        (address user, uint256 amount) = ExternalLibUsdAccount.decode(account);
        AccountValidityProof memory proof = _getAccountValidityProof(name);

        uint256 balance = vm.randomUint(amount, _usd.balanceOf(_tokenOwner));

        vm.prank(_tokenOwner);
        assertTrue(_usd.transfer(address(_appContract), balance));

        vm.mockCallRevert(
            address(_usd), abi.encodeCall(IERC20.transfer, (user, amount)), error
        );

        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();

        vm.expectRevert(error);

        vm.prank(vm.randomAddress());
        _appContract.withdraw(account, proof);
    }

    function testWithdrawalRevertsSafeERC20FailedOperation(uint256 returnValue) external {
        vm.assume(returnValue != 1);

        string memory name = "Alice";
        bytes memory account = _getAccount(name);
        (address user, uint256 amount) = ExternalLibUsdAccount.decode(account);
        AccountValidityProof memory proof = _getAccountValidityProof(name);

        uint256 balance = vm.randomUint(amount, _usd.balanceOf(_tokenOwner));

        vm.prank(_tokenOwner);
        assertTrue(_usd.transfer(address(_appContract), balance));

        vm.mockCall(
            address(_usd),
            abi.encodeCall(IERC20.transfer, (user, amount)),
            abi.encode(returnValue)
        );

        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();

        vm.expectRevert(_encodeSafeErc20FailedOperation(address(_usd)));

        vm.prank(vm.randomAddress());
        _appContract.withdraw(account, proof);
    }

    function testWithdrawalRevertsSafeERC20FailedOperation() external {
        string memory name = "Alice";
        bytes memory account = _getAccount(name);
        AccountValidityProof memory proof = _getAccountValidityProof(name);

        vm.etch(address(_usd), abi.encode());

        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();

        vm.expectRevert(_encodeSafeErc20FailedOperation(address(_usd)));

        vm.prank(vm.randomAddress());
        _appContract.withdraw(account, proof);
    }

    function testWithdrawalRevertsAccountIsTooShort(uint256) external {
        uint256 accountSize = vm.randomUint(0, 27);
        string memory name = string.concat("RandomBytes", vm.toString(accountSize));
        bytes memory account = _getAccount(name);
        AccountValidityProof memory proof = _getAccountValidityProof(name);

        // Give the app a random ERC-20 token balance
        uint256 appBalance = vm.randomUint(0, _usd.balanceOf(_tokenOwner));
        vm.prank(_tokenOwner);
        assertTrue(_usd.transfer(address(_appContract), appBalance));

        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();

        vm.expectRevert("Account is too short");
        vm.prank(vm.randomAddress());
        _appContract.withdraw(account, proof);
    }

    function testWithdrawal(uint256) external {
        string[] memory names = new string[](8);
        names[0] = "Alice";
        names[1] = "Bob";
        names[2] = "Charles";
        names[3] = "RandomBytes28";
        names[4] = "RandomBytes29";
        names[5] = "RandomBytes30";
        names[6] = "RandomBytes31";
        names[7] = "RandomBytes32";

        string memory name = names[vm.randomUint(0, names.length - 1)];
        bytes memory account = _getAccount(name);
        (address user, uint256 amount) = ExternalLibUsdAccount.decode(account);
        AccountValidityProof memory proof = _getAccountValidityProof(name);

        uint256 appBalance = vm.randomUint(amount, _usd.balanceOf(_tokenOwner));
        vm.prank(_tokenOwner);
        assertTrue(_usd.transfer(address(_appContract), appBalance));

        uint256 userBalance = vm.randomUint(0, _usd.balanceOf(_tokenOwner));
        vm.prank(_tokenOwner);
        assertTrue(_usd.transfer(user, userBalance));

        uint256 numOfWithdrawalsBefore = _appContract.getNumberOfWithdrawals();

        assertFalse(_appContract.wereAccountFundsWithdrawn(proof.accountIndex));

        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();

        vm.recordLogs();

        vm.prank(vm.randomAddress());
        _appContract.withdraw(account, proof);

        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 numOfWithdrawalEventsInTx;
        uint256 numOfTransferEventsInTx;

        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];
            if (log.emitter == address(_appContract)) {
                assertGe(log.topics.length, 1);
                bytes32 topic0 = log.topics[0];
                if (topic0 == IApplicationWithdrawal.Withdrawal.selector) {
                    ++numOfWithdrawalEventsInTx;

                    // decode log data
                    (uint64 arg1, bytes memory arg2, bytes memory arg3) =
                        abi.decode(log.data, (uint64, bytes, bytes));
                    assertEq(arg1, proof.accountIndex);
                    assertEq(arg2, account);

                    // decode output
                    (bytes4 funcsel1, bytes memory callargs1) = arg3.consumeBytes4();
                    assertEq(funcsel1, Outputs.DelegateCallVoucher.selector);
                    (address destination, bytes memory payload) =
                        abi.decode(callargs1, (address, bytes));
                    assertEq(destination, address(_safeErc20Transfer));

                    // decode delegatecall payload
                    (bytes4 funcsel2, bytes memory callargs2) = payload.consumeBytes4();
                    assertEq(funcsel2, ISafeERC20Transfer.safeTransfer.selector);
                    (address token, address to, uint256 value) =
                        abi.decode(callargs2, (address, address, uint256));
                    assertEq(token, address(_usd));
                    assertEq(to, user);
                    assertEq(value, amount);
                } else {
                    revert("unexpected event from app contract");
                }
            } else if (log.emitter == address(_usd)) {
                assertGe(log.topics.length, 1);
                bytes32 topic0 = log.topics[0];
                if (topic0 == IERC20.Transfer.selector) {
                    ++numOfTransferEventsInTx;

                    assertEq(log.topics[1], address(_appContract).asTopic());
                    assertEq(log.topics[2], user.asTopic());
                    assertEq(abi.decode(log.data, (uint256)), amount);
                } else {
                    revert("unexpected event from ERC-20 token contract");
                }
            } else {
                revert("unexpected log emitter");
            }
        }

        assertEq(numOfWithdrawalEventsInTx, 1);
        assertEq(numOfTransferEventsInTx, 1);
        assertEq(_appContract.getNumberOfWithdrawals(), numOfWithdrawalsBefore + 1);
        assertTrue(_appContract.wereAccountFundsWithdrawn(proof.accountIndex));
        assertEq(_usd.balanceOf(address(_appContract)), appBalance - amount);
        assertEq(_usd.balanceOf(user), userBalance + amount);

        {
            uint64 otherAccountIndex;
            while (true) {
                otherAccountIndex = uint64(vm.randomUint(64));
                if (otherAccountIndex != proof.accountIndex) {
                    break;
                }
            }

            // Check that other accounts haven't been withdrawn yet.
            assertFalse(_appContract.wereAccountFundsWithdrawn(otherAccountIndex));
        }

        // Check that an extra withdrawal attempt fails.
        vm.expectRevert(_encodeAccountFundsAlreadyWithdrawn(proof.accountIndex));
        vm.prank(vm.randomAddress());
        _appContract.withdraw(account, proof);

        // Check that the account (and its Merkle roots) can still be validated.
        bytes32 accountMerkleRoot = LibEmulator.getAccountMerkleRoot(account);
        vm.startPrank(vm.randomAddress());
        _appContract.validateAccount(account, proof);
        _appContract.validateAccountMerkleRoot(accountMerkleRoot, proof);
        vm.stopPrank();
    }

    // ------------------
    // internal functions
    // ------------------

    function _initVariables() internal {
        _authorityOwner = _nextAddress();
        _appOwner = _nextAddress();
        _recipient = _nextAddress();
        _tokenOwner = _nextAddress();
        _withdrawalConfig.guardian = _nextAddress();
        _withdrawalConfig.log2LeavesPerAccount = LibEmulator.LOG2_LEAVES_PER_ACCOUNT;
        _withdrawalConfig.log2MaxNumOfAccounts = LibEmulator.LOG2_MAX_NUM_OF_ACCOUNTS;
        _withdrawalConfig.accountsDriveStartIndex = LibEmulator.ACCOUNTS_DRIVE_START_INDEX;
        for (uint256 i; i < 7; ++i) {
            _tokenIds.push(i);
            _initialSupplies.push(INITIAL_SUPPLY);
            _transferAmounts.push(vm.randomUint(1, INITIAL_SUPPLY));
        }
    }

    function _deployContracts() internal {
        _etherReceiver = new EtherReceiver();
        _erc20Token = new SimpleERC20(_tokenOwner, INITIAL_SUPPLY);
        _erc721Token = new SimpleERC721(_tokenOwner, TOKEN_ID);
        _erc1155SingleToken =
            new SimpleSingleERC1155(_tokenOwner, TOKEN_ID, INITIAL_SUPPLY);
        _erc1155BatchToken =
            new SimpleBatchERC1155(_tokenOwner, _tokenIds, _initialSupplies);
        _inputBox = new InputBox();
        _authority = new Authority(_authorityOwner, EPOCH_LENGTH);
        _dataAvailability = abi.encodeCall(DataAvailability.InputBox, (_inputBox));
        _safeErc20Transfer = new SafeERC20Transfer();
        _usd = new SimpleERC20(_tokenOwner, type(uint64).max);
        _withdrawalConfig.withdrawalOutputBuilder =
            new UsdWithdrawalOutputBuilder(_safeErc20Transfer, _usd);
        _appContract = new Application(
            _authority, _appOwner, TEMPLATE_HASH, _dataAvailability, _withdrawalConfig
        );
    }

    function _addOutputs() internal {
        _nameOutput("EmptyOutput", _addOutput(abi.encode()));
        _nameOutput("HelloWorldNotice", _addOutput(_encodeNotice("Hello, world!")));
        _nameOutput("MyOutput", _addOutput(abi.encodeWithSignature("MyOutput()")));
        _nameOutput(
            "EtherTransferVoucher",
            _addOutput(_encodeVoucher(_recipient, TRANSFER_AMOUNT, abi.encode()))
        );
        _nameOutput(
            "EtherMintVoucher",
            _addOutput(
                _encodeVoucher(
                    address(_etherReceiver),
                    TRANSFER_AMOUNT,
                    abi.encodeCall(EtherReceiver.mint, ())
                )
            )
        );
        _nameOutput(
            "ERC20TransferVoucher",
            _addOutput(
                _encodeVoucher(
                    address(_erc20Token),
                    0,
                    abi.encodeCall(IERC20.transfer, (_recipient, TRANSFER_AMOUNT))
                )
            )
        );
        _nameOutput(
            "ERC721TransferVoucher",
            _addOutput(
                _encodeVoucher(
                    address(_erc721Token),
                    0,
                    abi.encodeWithSignature(
                        "safeTransferFrom(address,address,uint256)",
                        address(_appContract),
                        _recipient,
                        TOKEN_ID
                    )
                )
            )
        );
        _nameOutput(
            "ERC1155SingleTransferVoucher",
            _addOutput(
                _encodeVoucher(
                    address(_erc1155SingleToken),
                    0,
                    abi.encodeCall(
                        IERC1155.safeTransferFrom,
                        (address(_appContract), _recipient, TOKEN_ID, TRANSFER_AMOUNT, "")
                    )
                )
            )
        );
        _nameOutput(
            "ERC1155BatchTransferVoucher",
            _addOutput(
                _encodeVoucher(
                    address(_erc1155BatchToken),
                    0,
                    abi.encodeCall(
                        IERC1155.safeBatchTransferFrom,
                        (
                            address(_appContract),
                            _recipient,
                            _tokenIds,
                            _transferAmounts,
                            ""
                        )
                    )
                )
            )
        );
        _nameOutput(
            "ERC20DelegateCallVoucher",
            _addOutput(
                _encodeDelegateCallVoucher(
                    address(_safeErc20Transfer),
                    abi.encodeCall(
                        SafeERC20Transfer.safeTransfer,
                        (_erc20Token, _recipient, TRANSFER_AMOUNT)
                    )
                )
            )
        );
    }

    function _encodeNotice(bytes memory payload) internal pure returns (bytes memory) {
        return abi.encodeCall(Outputs.Notice, (payload));
    }

    function _encodeVoucher(address destination, uint256 value, bytes memory payload)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(Outputs.Voucher, (destination, value, payload));
    }

    function _encodeDelegateCallVoucher(address destination, bytes memory payload)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(Outputs.DelegateCallVoucher, (destination, payload));
    }

    function _addOutput(bytes memory output) internal returns (LibEmulator.OutputIndex) {
        return _emulator.addOutput(output);
    }

    function _nameOutput(string memory name, LibEmulator.OutputIndex outputIndex)
        internal
    {
        _outputIndexByName[name] = outputIndex;
        _outputNames.push(name);
    }

    function _getOutput(string memory name) internal view returns (bytes storage) {
        return _emulator.getOutput(_outputIndexByName[name]);
    }

    function _getRandomOutputName() internal returns (string memory) {
        assertGt(_outputNames.length, 0, "No outputs to choose from");
        return _outputNames[vm.randomUint(0, _outputNames.length - 1)];
    }

    function _getOutputValidityProof(string memory name)
        internal
        view
        returns (OutputValidityProof memory)
    {
        return _emulator.getOutputValidityProof(_outputIndexByName[name]);
    }

    function _addAccounts() internal {
        _nameAccount("Alice", _addAccount(_encodeUsdAccount(_nextAddress(), 100000000)));
        _nameAccount("Bob", _addAccount(_encodeUsdAccount(_nextAddress(), 9000000001)));
        _nameAccount("Charles", _addAccount(_encodeUsdAccount(_nextAddress(), 0)));

        uint256 maxAccountSize = 1 << LibEmulator.getLog2MaxAccountSize();
        for (uint256 accountSize; accountSize <= maxAccountSize; ++accountSize) {
            string memory name = string.concat("RandomBytes", vm.toString(accountSize));
            bytes memory account = vm.randomBytes(accountSize);
            _nameAccount(name, _addAccount(account));
        }
    }

    function _encodeUsdAccount(address user, uint64 balance)
        internal
        pure
        returns (bytes memory)
    {
        return LibUsdAccount.encode(user, balance);
    }

    function _addAccount(bytes memory account)
        internal
        returns (LibEmulator.AccountIndex)
    {
        return _emulator.addAccount(account);
    }

    function _nameAccount(string memory name, LibEmulator.AccountIndex accountIndex)
        internal
    {
        _accountIndexByName[name] = accountIndex;
        _accountNames.push(name);
    }

    function _getAccount(string memory name) internal view returns (bytes storage) {
        return _emulator.getAccount(_accountIndexByName[name]);
    }

    function _getRandomAccountName() internal returns (string memory) {
        assertGt(_accountNames.length, 0, "No accounts to choose from");
        return _accountNames[vm.randomUint(0, _accountNames.length - 1)];
    }

    function _generateAccount() internal view returns (bytes memory) {
        uint256 log2MaxAccountSize = LibEmulator.getLog2MaxAccountSize();
        uint256 accountSize = vm.randomUint(log2MaxAccountSize);
        return vm.randomBytes(accountSize);
    }

    function _generateIllSizedAccount() internal returns (bytes memory) {
        uint256 log2MaxAccountSize = LibEmulator.getLog2MaxAccountSize();
        uint256 accountSize = vm.randomUint(1 << log2MaxAccountSize, 1 << 16);
        return vm.randomBytes(accountSize);
    }

    function _getAccountValidityProof(string memory name)
        internal
        view
        returns (AccountValidityProof memory)
    {
        return _emulator.getAccountValidityProof(
            _proofComponents, _accountIndexByName[name]
        );
    }

    /// @notice This function is used to simulate a foreclosure and a withdrawal.
    /// If the withdrawal succeeds, then the function reverts with error message "Successful withdrawal".
    /// If the withdrawal fails, then the function propagates the error from the app contract.
    function simulateForeclosureAndWithdrawal(
        bytes calldata account,
        AccountValidityProof calldata proof
    ) external {
        assertEq(msg.sender, address(this), "called by external account");
        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();
        vm.prank(vm.randomAddress());
        _appContract.withdraw(account, proof);
        revert("Successful withdrawal");
    }

    function _submitClaim() internal {
        _proofComponents = _emulator.buildProofComponents();
        bytes32 outputsMerkleRoot = _proofComponents.outputsMerkleRoot;
        bytes32 machineMerkleRoot = _proofComponents.getMachineMerkleRoot();

        // attempt to validate and execute outputs
        {
            bytes memory error = _encodeInvalidOutputsMerkleRoot(outputsMerkleRoot);
            for (uint256 i; i < _outputNames.length; ++i) {
                string memory name = _outputNames[i];
                bytes memory output = _getOutput(name);
                OutputValidityProof memory proof = _getOutputValidityProof(name);
                vm.expectRevert(error);
                _appContract.validateOutputHash(keccak256(output), proof);
                vm.expectRevert(error);
                _appContract.validateOutput(output, proof);
                vm.expectRevert(error);
                _appContract.executeOutput(output, proof);
            }
        }

        // attempt to validate/withdraw accounts
        {
            bytes memory error = _encodeInvalidMachineMerkleRoot(machineMerkleRoot);
            for (uint256 i; i < _accountNames.length; ++i) {
                string memory name = _accountNames[i];
                bytes memory account = _getAccount(name);
                bytes32 accountMerkleRoot = LibEmulator.getAccountMerkleRoot(account);
                AccountValidityProof memory proof = _getAccountValidityProof(name);
                vm.expectRevert(error);
                _appContract.validateAccountMerkleRoot(accountMerkleRoot, proof);
                vm.expectRevert(error);
                _appContract.validateAccount(account, proof);
                vm.expectRevert(error);
                this.simulateForeclosureAndWithdrawal(account, proof);
            }
        }

        vm.prank(_authorityOwner);
        _authority.submitClaim(
            address(_appContract),
            0,
            outputsMerkleRoot,
            _proofComponents.getOutputsMerkleRootProof()
        );

        assertEq(
            _authority.getLastFinalizedMachineMerkleRoot(address(_appContract)),
            machineMerkleRoot,
            "last finalized machine Merkle root"
        );
    }

    function _expectEmitOutputExecuted(
        bytes memory output,
        OutputValidityProof memory proof
    ) internal {
        vm.expectEmit(false, false, false, true, address(_appContract));
        emit IApplication.OutputExecuted(proof.outputIndex, output);
    }

    function _encodeOutputNotExecutable(bytes memory output)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(IApplication.OutputNotExecutable.selector, output);
    }

    function _encodeOutputNotReexecutable(bytes memory output)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(IApplication.OutputNotReexecutable.selector, output);
    }

    function _expectIncrementInNumberOfExecutedOutputs(uint256 before) internal view {
        assertEq(
            _appContract.getNumberOfExecutedOutputs(),
            before + 1,
            "Should increment number of executed outputs on success"
        );
    }

    function _expectNoChangeInNumberOfExecutedOutputs(uint256 before) internal view {
        assertEq(
            _appContract.getNumberOfExecutedOutputs(),
            before,
            "Should not increment number of executed outputs on revert"
        );
    }

    function _encodeInvalidOutputsMerkleRoot(bytes32 outputsMerkleRoot)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IApplication.InvalidOutputsMerkleRoot.selector, outputsMerkleRoot
        );
    }

    function _encodeInvalidNodeIndex(uint256 nodeIndex)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            BinaryMerkleTreeErrors.InvalidNodeIndex.selector,
            nodeIndex,
            CanonicalMachine.LOG2_MAX_OUTPUTS
        );
    }

    function _encodeInvalidAccountRootSiblingsArrayLength()
        internal
        pure
        returns (bytes4)
    {
        return IApplicationWithdrawal.InvalidAccountRootSiblingsArrayLength.selector;
    }

    function _encodeInvalidAccountIndex() internal pure returns (bytes4) {
        return IApplicationWithdrawal.InvalidAccountIndex.selector;
    }

    function _encodeInvalidOutputHashesSiblingsArrayLength()
        internal
        pure
        returns (bytes4)
    {
        return IApplication.InvalidOutputHashesSiblingsArrayLength.selector;
    }

    function _encodeInvalidMachineMerkleRoot(bytes32 machineMerkleRoot)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IApplicationWithdrawal.InvalidMachineMerkleRoot.selector, machineMerkleRoot
        );
    }

    function _encodeDriveSmallerThanData(uint256 dataSize)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            BinaryMerkleTreeErrors.DriveSmallerThanData.selector,
            1 << LibEmulator.getLog2MaxAccountSize(),
            dataSize
        );
    }

    function _encodeErc20InsufficientBalance(IERC20 token, uint256 needed)
        internal
        view
        returns (bytes memory)
    {
        address sender = address(_appContract);
        return abi.encodeWithSelector(
            IERC20Errors.ERC20InsufficientBalance.selector,
            sender,
            token.balanceOf(sender),
            needed
        );
    }

    function _encodeAccountFundsAlreadyWithdrawn(uint64 accountIndex)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IApplicationWithdrawal.AccountFundsAlreadyWithdrawn.selector, accountIndex
        );
    }

    function _encodeSafeErc20FailedOperation(address token)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, token);
    }

    function _wasOutputExecuted(OutputValidityProof memory proof)
        internal
        view
        returns (bool)
    {
        return _appContract.wasOutputExecuted(proof.outputIndex);
    }

    function _testEtherTransfer(bytes memory output, OutputValidityProof memory proof)
        internal
    {
        uint256 numberOfExecutedOutputsBefore = _appContract.getNumberOfExecutedOutputs();
        assertLt(
            address(_appContract).balance,
            TRANSFER_AMOUNT,
            "Application contract does not have enough Ether"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IApplication.InsufficientFunds.selector, TRANSFER_AMOUNT, 0
            )
        );
        _appContract.executeOutput(output, proof);
        _expectNoChangeInNumberOfExecutedOutputs(numberOfExecutedOutputsBefore);
        vm.deal(address(_appContract), TRANSFER_AMOUNT);

        uint256 recipientBalance = _recipient.balance;
        uint256 appBalance = address(_appContract).balance;

        _expectEmitOutputExecuted(output, proof);

        _appContract.executeOutput(output, proof);

        assertEq(
            _recipient.balance,
            recipientBalance + TRANSFER_AMOUNT,
            "Recipient should have received the transfer amount"
        );

        assertEq(
            address(_appContract).balance,
            appBalance - TRANSFER_AMOUNT,
            "Application contract should have the transfer amount deducted"
        );

        assertTrue(_wasOutputExecuted(proof), "Output should be marked as executed");
        _expectIncrementInNumberOfExecutedOutputs(numberOfExecutedOutputsBefore);
        vm.expectRevert(_encodeOutputNotReexecutable(output));
        _appContract.executeOutput(output, proof);
    }

    function _testEtherMint(bytes memory output, OutputValidityProof memory proof)
        internal
    {
        uint256 numberOfExecutedOutputsBefore = _appContract.getNumberOfExecutedOutputs();
        assertLt(
            address(_appContract).balance,
            TRANSFER_AMOUNT,
            "Application contract does not have enough Ether"
        );

        vm.expectRevert();
        _appContract.executeOutput(output, proof);

        _expectNoChangeInNumberOfExecutedOutputs(numberOfExecutedOutputsBefore);
        vm.deal(address(_appContract), TRANSFER_AMOUNT);

        uint256 recipientBalance = address(_etherReceiver).balance;
        uint256 appBalance = address(_appContract).balance;
        uint256 balanceOf = _etherReceiver.balanceOf(address(_appContract));

        _expectEmitOutputExecuted(output, proof);
        _appContract.executeOutput(output, proof);

        assertEq(
            address(_etherReceiver).balance,
            recipientBalance + TRANSFER_AMOUNT,
            "Recipient should have received the transfer amount"
        );

        assertEq(
            address(_appContract).balance,
            appBalance - TRANSFER_AMOUNT,
            "Application contract should have the transfer amount deducted"
        );

        assertEq(
            _etherReceiver.balanceOf(address(_appContract)),
            balanceOf + TRANSFER_AMOUNT,
            "Application contract should have the transfer amount minted"
        );

        assertTrue(_wasOutputExecuted(proof), "Output should be marked as executed");
        _expectIncrementInNumberOfExecutedOutputs(numberOfExecutedOutputsBefore);

        vm.expectRevert(_encodeOutputNotReexecutable(output));
        _appContract.executeOutput(output, proof);
    }

    function _testErc721Transfer(bytes memory output, OutputValidityProof memory proof)
        internal
    {
        uint256 numberOfExecutedOutputsBefore = _appContract.getNumberOfExecutedOutputs();
        assertEq(
            _erc721Token.ownerOf(TOKEN_ID),
            _tokenOwner,
            "The NFT is initially owned by `_tokenOwner`"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721Errors.ERC721InsufficientApproval.selector,
                address(_appContract),
                TOKEN_ID
            )
        );
        _appContract.executeOutput(output, proof);
        _expectNoChangeInNumberOfExecutedOutputs(numberOfExecutedOutputsBefore);

        vm.prank(_tokenOwner);
        _erc721Token.safeTransferFrom(_tokenOwner, address(_appContract), TOKEN_ID);

        _expectEmitOutputExecuted(output, proof);
        _appContract.executeOutput(output, proof);

        assertEq(
            _erc721Token.ownerOf(TOKEN_ID),
            _recipient,
            "The NFT is then transferred to the recipient"
        );

        assertTrue(_wasOutputExecuted(proof), "Output should be marked as executed");
        _expectIncrementInNumberOfExecutedOutputs(numberOfExecutedOutputsBefore);

        vm.expectRevert(_encodeOutputNotReexecutable(output));
        _appContract.executeOutput(output, proof);
    }

    function _testErc20Fail(bytes memory output, OutputValidityProof memory proof)
        internal
    {
        uint256 numberOfExecutedOutputsBefore = _appContract.getNumberOfExecutedOutputs();
        // test revert

        assertLt(
            _erc20Token.balanceOf(address(_appContract)),
            TRANSFER_AMOUNT,
            "Application contract does not have enough ERC-20 tokens"
        );

        vm.expectRevert(_encodeErc20InsufficientBalance(_erc20Token, TRANSFER_AMOUNT));
        _appContract.executeOutput(output, proof);
        _expectNoChangeInNumberOfExecutedOutputs(numberOfExecutedOutputsBefore);

        // test return false

        vm.mockCall(
            address(_erc20Token),
            abi.encodeCall(IERC20.transfer, (_recipient, TRANSFER_AMOUNT)),
            abi.encode(false)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeERC20.SafeERC20FailedOperation.selector, address(_erc20Token)
            )
        );
        _appContract.executeOutput(output, proof);
        _expectNoChangeInNumberOfExecutedOutputs(numberOfExecutedOutputsBefore);
        vm.clearMockedCalls();
    }

    function _testErc20Success(bytes memory output, OutputValidityProof memory proof)
        internal
    {
        uint256 numberOfExecutedOutputsBefore = _appContract.getNumberOfExecutedOutputs();
        vm.prank(_tokenOwner);
        bool success = _erc20Token.transfer(address(_appContract), TRANSFER_AMOUNT);
        assertTrue(success, "");

        uint256 recipientBalance = _erc20Token.balanceOf(address(_recipient));
        uint256 appBalance = _erc20Token.balanceOf(address(_appContract));

        _expectEmitOutputExecuted(output, proof);
        _appContract.executeOutput(output, proof);

        assertEq(
            _erc20Token.balanceOf(address(_recipient)),
            recipientBalance + TRANSFER_AMOUNT,
            "Recipient should have received the transfer amount"
        );

        assertEq(
            _erc20Token.balanceOf(address(_appContract)),
            appBalance - TRANSFER_AMOUNT,
            "Application contract should have the transfer amount deducted"
        );

        assertTrue(_wasOutputExecuted(proof), "Output should be marked as executed");
        _expectIncrementInNumberOfExecutedOutputs(numberOfExecutedOutputsBefore);

        vm.expectRevert(_encodeOutputNotReexecutable(output));
        _appContract.executeOutput(output, proof);
    }

    function _testErc1155SingleTransfer(
        bytes memory output,
        OutputValidityProof memory proof
    ) internal {
        uint256 numberOfExecutedOutputsBefore = _appContract.getNumberOfExecutedOutputs();
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Errors.ERC1155InsufficientBalance.selector,
                address(_appContract),
                0,
                TRANSFER_AMOUNT,
                TOKEN_ID
            )
        );
        _appContract.executeOutput(output, proof);
        _expectNoChangeInNumberOfExecutedOutputs(numberOfExecutedOutputsBefore);

        vm.prank(_tokenOwner);
        _erc1155SingleToken.safeTransferFrom(
            _tokenOwner, address(_appContract), TOKEN_ID, INITIAL_SUPPLY, ""
        );

        uint256 recipientBalance = _erc1155SingleToken.balanceOf(_recipient, TOKEN_ID);
        uint256 appBalance =
            _erc1155SingleToken.balanceOf(address(_appContract), TOKEN_ID);

        _expectEmitOutputExecuted(output, proof);
        _appContract.executeOutput(output, proof);

        assertEq(
            _erc1155SingleToken.balanceOf(address(_appContract), TOKEN_ID),
            appBalance - TRANSFER_AMOUNT,
            "Application contract should have the transfer amount deducted"
        );
        assertEq(
            _erc1155SingleToken.balanceOf(_recipient, TOKEN_ID),
            recipientBalance + TRANSFER_AMOUNT,
            "Recipient should have received the transfer amount"
        );

        assertTrue(_wasOutputExecuted(proof), "Output should be marked as executed");
        _expectIncrementInNumberOfExecutedOutputs(numberOfExecutedOutputsBefore);

        vm.expectRevert(_encodeOutputNotReexecutable(output));
        _appContract.executeOutput(output, proof);
    }

    function _testErc1155BatchTransfer(
        bytes memory output,
        OutputValidityProof memory proof
    ) internal {
        uint256 numberOfExecutedOutputsBefore = _appContract.getNumberOfExecutedOutputs();
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Errors.ERC1155InsufficientBalance.selector,
                address(_appContract),
                0,
                _transferAmounts[0],
                _tokenIds[0]
            )
        );
        _appContract.executeOutput(output, proof);
        _expectNoChangeInNumberOfExecutedOutputs(numberOfExecutedOutputsBefore);

        vm.prank(_tokenOwner);
        _erc1155BatchToken.safeBatchTransferFrom(
            _tokenOwner, address(_appContract), _tokenIds, _initialSupplies, ""
        );

        uint256 batchLength = _initialSupplies.length;
        uint256[] memory appBalances = new uint256[](batchLength);
        uint256[] memory recipientBalances = new uint256[](batchLength);
        for (uint256 i; i < batchLength; ++i) {
            appBalances[i] =
                _erc1155BatchToken.balanceOf(address(_appContract), _tokenIds[i]);
            recipientBalances[i] = _erc1155BatchToken.balanceOf(_recipient, _tokenIds[i]);
        }

        _expectEmitOutputExecuted(output, proof);
        _appContract.executeOutput(output, proof);

        for (uint256 i; i < _tokenIds.length; ++i) {
            assertEq(
                _erc1155BatchToken.balanceOf(address(_appContract), _tokenIds[i]),
                appBalances[i] - _transferAmounts[i],
                "Application contract should have the transfer amount deducted"
            );
            assertEq(
                _erc1155BatchToken.balanceOf(_recipient, _tokenIds[i]),
                recipientBalances[i] + _transferAmounts[i],
                "Recipient should have received the transfer amount"
            );
        }

        assertTrue(_wasOutputExecuted(proof), "Output should be marked as executed");
        _expectIncrementInNumberOfExecutedOutputs(numberOfExecutedOutputsBefore);

        vm.expectRevert(_encodeOutputNotReexecutable(output));
        _appContract.executeOutput(output, proof);
    }

    function _validateOutputs() internal view {
        for (uint256 i; i < _outputNames.length; ++i) {
            string memory name = _outputNames[i];
            bytes memory output = _getOutput(name);
            OutputValidityProof memory proof = _getOutputValidityProof(name);
            _appContract.validateOutput(output, proof);
            _appContract.validateOutputHash(keccak256(output), proof);
        }
    }

    function _validateAccounts() internal view {
        for (uint256 i; i < _accountNames.length; ++i) {
            string memory name = _accountNames[i];
            bytes memory account = _getAccount(name);
            bytes32 accountMerkleRoot = LibEmulator.getAccountMerkleRoot(account);
            AccountValidityProof memory proof = _getAccountValidityProof(name);
            _appContract.validateAccountMerkleRoot(accountMerkleRoot, proof);
            _appContract.validateAccount(account, proof);
        }
    }
}

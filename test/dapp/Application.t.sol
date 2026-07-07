// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {AccountValidityProof} from "src/common/AccountValidityProof.sol";
import {BinaryMerkleTreeErrors} from "src/common/BinaryMerkleTreeErrors.sol";
import {CanonicalMachine} from "src/common/CanonicalMachine.sol";
import {OutputValidityProof} from "src/common/OutputValidityProof.sol";
import {Outputs} from "src/common/Outputs.sol";
import {WithdrawalConfig} from "src/common/WithdrawalConfig.sol";
import {IAuthority} from "src/consensus/authority/IAuthority.sol";
import {IApplication} from "src/dapp/IApplication.sol";
import {ISafeERC20Transfer} from "src/delegatecall/ISafeERC20Transfer.sol";
import {LibUsdAccount} from "src/library/LibUsdAccount.sol";
import {IRefundOutputBuilderErrors} from "src/refund/IRefundOutputBuilderErrors.sol";
import {IWithdrawalOutputBuilder} from "src/withdrawal/IWithdrawalOutputBuilder.sol";
import {IWithdrawalOutputBuilderErrors} from "src/withdrawal/IWithdrawalOutputBuilderErrors.sol";

import {IERC20Errors} from "@openzeppelin-contracts-5.2.0/interfaces/draft-IERC6093.sol";
import {IERC1155Errors} from "@openzeppelin-contracts-5.2.0/interfaces/draft-IERC6093.sol";
import {IERC721Errors} from "@openzeppelin-contracts-5.2.0/interfaces/draft-IERC6093.sol";
import {IERC1155} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155.sol";
import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin-contracts-5.2.0/token/ERC721/IERC721.sol";
import {SafeCast} from "@openzeppelin-contracts-5.2.0/utils/math/SafeCast.sol";

import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {ExternalLibBinaryMerkleTree} from "../library/LibBinaryMerkleTree.t.sol";
import {ExternalLibUsdAccount} from "../library/LibUsdAccount.t.sol";
import {AddressGenerator} from "../util/AddressGenerator.sol";
import {AssetReceiver} from "../util/AssetReceiver.sol";
import {ConsensusTestUtils} from "../util/ConsensusTestUtils.sol";
import {EtherReceiver, IEtherReceiver} from "../util/EtherReceiver.sol";
import {InputBoxTestUtils} from "../util/InputBoxTestUtils.sol";
import {LibAddressArray} from "../util/LibAddressArray.sol";
import {LibBytes} from "../util/LibBytes.sol";
import {LibBytes32Array} from "../util/LibBytes32Array.sol";
import {LibEmulator} from "../util/LibEmulator.sol";
import {LibTopic} from "../util/LibTopic.sol";
import {LibUint256Array} from "../util/LibUint256Array.sol";
import {OwnableTest} from "../util/OwnableTest.sol";
import {RollupsTest} from "../util/RollupsTest.sol";

contract ApplicationTest is
    RollupsTest,
    OwnableTest,
    AddressGenerator,
    InputBoxTestUtils,
    ConsensusTestUtils
{
    using LibBytes for bytes;
    using LibTopic for address;
    using SafeCast for uint256;
    using LibUint256Array for Vm;
    using LibUint256Array for uint256[];
    using LibBytes32Array for bytes32[];
    using LibAddressArray for address;
    using LibEmulator for LibEmulator.State;
    using LibEmulator for LibEmulator.ProofComponents;
    using ExternalLibBinaryMerkleTree for bytes32[];

    enum DepositType {
        ETHER,
        ERC20,
        ERC721,
        ERC1155_SINGLE,
        ERC1155_BATCH
    }

    IApplication _appContract;
    IEtherReceiver _etherReceiver;
    IAuthority _authority;
    IERC20 _erc20Token;
    IERC721 _erc721Token;
    IERC1155 _erc1155Token;
    ISafeERC20Transfer _safeErc20Transfer;
    AssetReceiver _assetReceiver;

    LibEmulator.State _emulator;
    LibEmulator.ProofComponents _proofComponents;
    string[] _outputNames;
    string[] _accountNames;
    uint256[] _tokenIds;
    uint256[] _initialSupplies;
    uint256[] _transferAmounts;
    mapping(string => LibEmulator.OutputIndex) _outputIndexByName;
    mapping(string => LibEmulator.AccountIndex) _accountIndexByName;

    uint256 constant INITIAL_SUPPLY = type(uint64).max;
    uint256 constant TOKEN_ID = 88888888;
    uint256 constant TRANSFER_AMOUNT = 42;

    function setUp() public {
        _initVariables();

        _addAccounts();
        _proofComponents = _buildProofComponents();

        (_appContract, _authority) =
            _contracts.core.selfHostedApplicationFactory
                .deployContracts(
                    _nextAddress(), // authorityOwner
                    1, // epochLength
                    0, // claimStagingPeriod
                    _proofComponents.getMachineMerkleRoot(), // templateHash
                    _contracts.core.inputBox,
                    WithdrawalConfig({
                        guardian: _nextAddress(),
                        log2LeavesPerAccount: LibEmulator.LOG2_LEAVES_PER_ACCOUNT,
                        log2MaxNumOfAccounts: LibEmulator.LOG2_MAX_NUM_OF_ACCOUNTS,
                        accountsDriveStartIndex: LibEmulator.ACCOUNTS_DRIVE_START_INDEX,
                        withdrawalOutputBuilder: _contracts.dev
                        .testUsdWithdrawalOutputBuilder
                    }),
                    bytes32(0) // salt
                );

        _addOutputs();
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

    // -----------
    // foreclosure
    // -----------

    function testForecloseRevertsNotGuardian(address caller) external {
        vm.assume(caller != _appContract.getGuardian());
        assertFalse(_appContract.isForeclosed());
        vm.expectRevert(IApplication.NotGuardian.selector);
        vm.prank(caller);
        _appContract.foreclose();
    }

    function testForeclose(address caller) external {
        address guardian = _appContract.getGuardian();
        vm.assume(caller != guardian);

        assertFalse(_appContract.isForeclosed());

        vm.expectEmit(true, true, true, true, address(_appContract));
        emit IApplication.Foreclosure();
        vm.prank(guardian);
        _appContract.foreclose();
        assertTrue(_appContract.isForeclosed());

        vm.expectRevert(IApplication.Foreclosed.selector);
        vm.prank(guardian);
        _appContract.foreclose();

        vm.expectRevert(IApplication.NotGuardian.selector);
        vm.prank(caller);
        _appContract.foreclose();
    }

    // -----------------
    // output validation
    // -----------------

    function testValidateOutputs() external {
        bytes32 outputsMerkleRoot = _emulator.getOutputsMerkleRoot();
        bytes memory errorData = _encodeInvalidOutputsMerkleRoot(outputsMerkleRoot);
        for (uint256 i; i < _outputNames.length; ++i) {
            string memory name = _outputNames[i];
            bytes memory output = _getOutput(name);
            OutputValidityProof memory proof = _getOutputValidityProof(name);
            vm.expectRevert(errorData);
            _appContract.validateOutputHash(keccak256(output), proof);
            vm.expectRevert(errorData);
            _appContract.validateOutput(output, proof);
            vm.expectRevert(errorData);
            _appContract.executeOutput(output, proof);
        }

        _submitAndAcceptClaim();
        _validateOutputs();

        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();
        _validateOutputs();

        _proveAccountsDriveMerkleRoot();
        _validateOutputs();
    }

    function testRevertsInvalidOutputHashesSiblingsArrayLength(bytes32[] calldata invalidOutputHashesSiblings)
        external
    {
        _submitAndAcceptClaim();

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
        _submitAndAcceptClaim();

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
        _submitAndAcceptClaim();

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

    function testValidateOutputRevertsInvalidNodeIndex(uint256) external {
        _submitAndAcceptClaim();

        string memory name = _getRandomOutputName();
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        uint256 log2MaxNumOfOutputs = CanonicalMachine.LOG2_MAX_OUTPUTS;
        uint256 maxNumOfOutputs = 1 << log2MaxNumOfOutputs;
        uint256 invalidOutputIndex = vm.randomUint(maxNumOfOutputs, type(uint64).max);

        assertNotEq(invalidOutputIndex, proof.outputIndex);

        proof.outputIndex = invalidOutputIndex.toUint64();

        vm.expectRevert(_encodeInvalidNodeIndex(invalidOutputIndex, log2MaxNumOfOutputs));
        _appContract.validateOutput(output, proof);

        vm.expectRevert(_encodeInvalidNodeIndex(invalidOutputIndex, log2MaxNumOfOutputs));
        _appContract.validateOutputHash(keccak256(output), proof);
    }

    // ----------------
    // output execution
    // ----------------

    function testExecuteEtherTransferVoucher() external {
        string memory name = "EtherTransferVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        _submitAndAcceptClaim();
        _testEtherTransfer(output, proof);
    }

    function testExecuteEtherMintVoucher() external {
        string memory name = "EtherMintVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        _submitAndAcceptClaim();
        _testEtherMint(output, proof);
    }

    function testExecuteERC20TransferVoucher() external {
        string memory name = "ERC20TransferVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        _submitAndAcceptClaim();

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

        _submitAndAcceptClaim();
        _testErc721Transfer(output, proof);
    }

    function testExecuteERC1155SingleTransferVoucher() external {
        string memory name = "ERC1155SingleTransferVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        _submitAndAcceptClaim();
        _testErc1155SingleTransfer(output, proof);
    }

    function testExecuteERC1155BatchTransferVoucher() external {
        string memory name = "ERC1155BatchTransferVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        _submitAndAcceptClaim();
        _testErc1155BatchTransfer(output, proof);
    }

    function testExecuteEmptyOutput() external {
        string memory name = "EmptyOutput";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        _submitAndAcceptClaim();

        vm.expectRevert(_encodeOutputNotExecutable(output));
        _appContract.executeOutput(output, proof);
    }

    function testExecuteMyOutput() external {
        string memory name = "MyOutput";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        _submitAndAcceptClaim();

        vm.expectRevert(_encodeOutputNotExecutable(output));
        _appContract.executeOutput(output, proof);
    }

    function testExecuteNotice() external {
        string memory name = "HelloWorldNotice";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        _submitAndAcceptClaim();

        vm.expectRevert(_encodeOutputNotExecutable(output));
        _appContract.executeOutput(output, proof);
    }

    function testExecuteERC20TransferDelegateCallVoucherFail() external {
        string memory name = "ERC20DelegateCallVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        _submitAndAcceptClaim();
        _testErc20Fail(output, proof);
    }

    function testExecuteERC20TransferDelegateCallVoucherSuccess() external {
        string memory name = "ERC20DelegateCallVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getOutputValidityProof(name);

        _submitAndAcceptClaim();
        _testErc20Success(output, proof);
    }

    // ----------------------------------
    // accounts drive Merkle root proving
    // ----------------------------------

    function testRevertsInvalidAccountsDriveMerkleRootProofSize(bytes32[] calldata invalidProof)
        external
    {
        if (vm.randomBool()) _submitAndAcceptClaim();

        // We assume the proof provided by the emulator library has the correct length,
        // and that the proof provided by the fuzzer has a different, incorrect length.
        vm.assume(invalidProof.length != _getAccountsDriveMerkleRootProof().length);

        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();

        bytes32 accountsDriveMerkleRoot = _getAccountsDriveMerkleRoot();

        vm.expectRevert(_encodeInvalidAccountsDriveMerkleRootProofSize());
        vm.prank(vm.randomAddress());
        _appContract.proveAccountsDriveMerkleRoot(accountsDriveMerkleRoot, invalidProof);
    }

    function testRevertsInvalidMachineMerkleRoot(bytes32 invalidAccountsDriveMerkleRoot)
        external
    {
        if (vm.randomBool()) _submitAndAcceptClaim();

        vm.assume(invalidAccountsDriveMerkleRoot != _getAccountsDriveMerkleRoot());

        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();

        bytes32[] memory proof = _getAccountsDriveMerkleRootProof();

        bytes32 invalidMachineMerkleRoot = proof.merkleRootAfterReplacement(
            LibEmulator.ACCOUNTS_DRIVE_START_INDEX, invalidAccountsDriveMerkleRoot
        );

        vm.expectRevert(_encodeInvalidMachineMerkleRoot(invalidMachineMerkleRoot));
        vm.prank(vm.randomAddress());
        _appContract.proveAccountsDriveMerkleRoot(invalidAccountsDriveMerkleRoot, proof);
    }

    function testProveAccountsDriveMerkleRoot() external {
        if (vm.randomBool()) _submitAndAcceptClaim();

        bytes32 accountsDriveMerkleRoot = _getAccountsDriveMerkleRoot();
        bytes32[] memory proof = _getAccountsDriveMerkleRootProof();

        vm.expectRevert(IApplication.NotForeclosed.selector);
        vm.prank(vm.randomAddress());
        _appContract.proveAccountsDriveMerkleRoot(accountsDriveMerkleRoot, proof);

        {
            bool wasValueProved;
            (wasValueProved,) = _appContract.getAccountsDriveMerkleRoot();
            assertFalse(wasValueProved);
        }

        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();

        {
            bool wasValueProved;
            (wasValueProved,) = _appContract.getAccountsDriveMerkleRoot();
            assertFalse(wasValueProved);
        }

        vm.recordLogs();

        vm.prank(vm.randomAddress());
        _appContract.proveAccountsDriveMerkleRoot(accountsDriveMerkleRoot, proof);

        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 numOfAccountsDriveMerkleRootProvedEvents;

        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];
            if (log.emitter == address(_appContract)) {
                assertGe(log.topics.length, 1);
                if (log.topics[0] == IApplication.AccountsDriveMerkleRootProved.selector)
                {
                    bytes32 arg1 = abi.decode(log.data, (bytes32));
                    assertEq(arg1, accountsDriveMerkleRoot);
                    ++numOfAccountsDriveMerkleRootProvedEvents;
                } else {
                    revert("unexpected event from app contract");
                }
            } else {
                revert("unexpected log emitter");
            }
        }

        assertEq(numOfAccountsDriveMerkleRootProvedEvents, 1);

        {
            bool wasValueProved;
            bytes32 value;
            (wasValueProved, value) = _appContract.getAccountsDriveMerkleRoot();
            assertTrue(wasValueProved);
            assertEq(value, accountsDriveMerkleRoot);
        }

        vm.expectRevert(_encodeAccountsDriveMerkleRootAlreadyProved());
        vm.prank(vm.randomAddress());
        _appContract.proveAccountsDriveMerkleRoot(accountsDriveMerkleRoot, proof);
    }

    // ------------------
    // account validation
    // ------------------

    struct UsdAccount {
        address user;
        uint64 balance;
    }

    function testValidateAccounts(bool addAccounts, UsdAccount[10] calldata newAccounts)
        external
    {
        // Even if we do not add new accounts, we can still validate the accounts present
        // in the template machine, in which case, the application contract uses the
        // template hash when validating the accounts drive Merkle root proof.
        // We limit the array of accounts to 10 to avoid OOG errors in Forge.
        if (addAccounts) {
            for (uint256 i; i < newAccounts.length; ++i) {
                UsdAccount calldata account = newAccounts[i];
                _nameAccount(
                    string.concat("NewAccount", vm.toString(i + 1)),
                    _addAccount(_encodeUsdAccount(account.user, account.balance))
                );
            }
            _submitAndAcceptClaim();
        }

        _validateAccounts(_encodeAccountsDriveMerkleRootNotProved());

        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();
        _validateAccounts(_encodeAccountsDriveMerkleRootNotProved());

        _proveAccountsDriveMerkleRoot();
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

    function testValidateAccountRevertsInvalidNodeIndex(uint256) external {
        string memory name = _getRandomAccountName();
        bytes memory account = _getAccount(name);
        bytes32 accountMerkleRoot = LibEmulator.getAccountMerkleRoot(account);
        AccountValidityProof memory proof = _getAccountValidityProof(name);

        uint256 log2MaxNumOfAccounts = LibEmulator.LOG2_MAX_NUM_OF_ACCOUNTS;
        uint256 maxNumOfAccounts = 1 << log2MaxNumOfAccounts;
        uint256 invalidAccountIndex = vm.randomUint(maxNumOfAccounts, type(uint64).max);

        assertNotEq(invalidAccountIndex, proof.accountIndex);

        proof.accountIndex = invalidAccountIndex.toUint64();

        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();
        _proveAccountsDriveMerkleRoot();

        vm.expectRevert(_encodeInvalidNodeIndex(proof.accountIndex, log2MaxNumOfAccounts));
        _appContract.validateAccount(account, proof);

        vm.expectRevert(_encodeInvalidNodeIndex(proof.accountIndex, log2MaxNumOfAccounts));
        _appContract.validateAccountMerkleRoot(accountMerkleRoot, proof);
    }

    function testRevertsInvalidAccountsDriveMerkleRoot(uint256) external {
        string memory name = _getRandomAccountName();
        bytes memory account = _getAccount(name);
        AccountValidityProof memory proof = _getAccountValidityProof(name);

        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();
        _proveAccountsDriveMerkleRoot();

        bytes memory invalidAccount = _generateAccount();

        bytes32 invalidAccountMerkleRoot =
            LibEmulator.getAccountMerkleRoot(invalidAccount);

        // assume the account provided by the fuzzer isn't
        // the account whose proof we will be using.
        vm.assume(LibEmulator.getAccountMerkleRoot(account) != invalidAccountMerkleRoot);

        bytes32 invalidAccountsDriveMerkleRoot =
            proof.accountRootSiblings
                .merkleRootAfterReplacement(proof.accountIndex, invalidAccountMerkleRoot);

        bytes memory invalidAccountsDriveMerkleRootError =
            _encodeInvalidAccountsDriveMerkleRoot(invalidAccountsDriveMerkleRoot);

        vm.expectRevert(invalidAccountsDriveMerkleRootError);
        _appContract.validateAccount(invalidAccount, proof);

        vm.expectRevert(invalidAccountsDriveMerkleRootError);
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

        uint256 balance = vm.randomUint(amount, type(uint256).max);
        _contracts.dev.testFungibleToken.mint(address(_appContract), balance);

        vm.expectRevert(IApplication.NotForeclosed.selector);

        vm.prank(vm.randomAddress());
        _appContract.withdraw(account, proof);
    }

    function testWithdrawalRevertsERC20InsufficientBalance(uint256) external {
        string memory name = "Alice";
        bytes memory account = _getAccount(name);
        (, uint256 amount) = ExternalLibUsdAccount.decode(account);
        AccountValidityProof memory proof = _getAccountValidityProof(name);

        uint256 balance = vm.randomUint(0, amount - 1);
        _contracts.dev.testFungibleToken.mint(address(_appContract), balance);

        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();
        _proveAccountsDriveMerkleRoot();

        vm.expectRevert(_encodeErc20InsufficientBalance(_erc20Token, amount));

        vm.prank(vm.randomAddress());
        _appContract.withdraw(account, proof);
    }

    function testWithdrawalRevertsBubbleUp(bytes calldata error) external {
        string memory name = "Alice";
        bytes memory account = _getAccount(name);
        (address user, uint256 amount) = ExternalLibUsdAccount.decode(account);
        AccountValidityProof memory proof = _getAccountValidityProof(name);

        uint256 balance = vm.randomUint(amount, type(uint256).max);
        _contracts.dev.testFungibleToken.mint(address(_appContract), balance);

        vm.mockCallRevert(
            address(_erc20Token), abi.encodeCall(IERC20.transfer, (user, amount)), error
        );

        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();
        _proveAccountsDriveMerkleRoot();

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

        uint256 balance = vm.randomUint(amount, type(uint256).max);
        _contracts.dev.testFungibleToken.mint(address(_appContract), balance);

        vm.mockCall(
            address(_erc20Token),
            abi.encodeCall(IERC20.transfer, (user, amount)),
            abi.encode(returnValue)
        );

        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();
        _proveAccountsDriveMerkleRoot();

        vm.expectRevert(_encodeSafeErc20FailedOperation(address(_erc20Token)));

        vm.prank(vm.randomAddress());
        _appContract.withdraw(account, proof);
    }

    function testWithdrawalRevertsSafeERC20FailedOperation() external {
        string memory name = "Alice";
        bytes memory account = _getAccount(name);
        AccountValidityProof memory proof = _getAccountValidityProof(name);

        vm.etch(address(_erc20Token), abi.encode());

        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();
        _proveAccountsDriveMerkleRoot();

        vm.expectRevert(_encodeSafeErc20FailedOperation(address(_erc20Token)));

        vm.prank(vm.randomAddress());
        _appContract.withdraw(account, proof);
    }

    function testWithdrawalRevertsAccountIsTooShort(uint256) external {
        uint64 accountSize = uint64(vm.randomUint(0, 27));
        string memory name = string.concat("RandomBytes", vm.toString(accountSize));
        bytes memory account = _getAccount(name);
        AccountValidityProof memory proof = _getAccountValidityProof(name);

        // Give the app a random ERC-20 token balance
        _contracts.dev.testFungibleToken.mint(address(_appContract), vm.randomUint());

        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();
        _proveAccountsDriveMerkleRoot();

        vm.expectRevert(_encodeAccountTooShort(accountSize));
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

        uint256 appBalance = vm.randomUint(amount, type(uint256).max);
        _contracts.dev.testFungibleToken.mint(address(_appContract), appBalance);

        uint256 userBalance = vm.randomUint(0, type(uint256).max - appBalance);
        _contracts.dev.testFungibleToken.mint(user, userBalance);

        uint256 numOfWithdrawalsBefore = _appContract.getNumberOfWithdrawals();

        assertFalse(_appContract.wereAccountFundsWithdrawn(proof.accountIndex));

        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();
        _proveAccountsDriveMerkleRoot();

        vm.expectCall(
            address(_appContract.getWithdrawalOutputBuilder()),
            abi.encodeCall(
                IWithdrawalOutputBuilder.buildWithdrawalOutput,
                (address(_appContract), account)
            )
        );

        vm.recordLogs();

        vm.prank(vm.randomAddress());
        _appContract.withdraw(account, proof);

        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 numOfWithdrawalEventsInTx;
        uint256 numOfTransferEventsInTx;
        bytes memory withdrawalOutput;

        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];
            if (log.emitter == address(_appContract)) {
                assertGe(log.topics.length, 1);
                bytes32 topic0 = log.topics[0];
                if (topic0 == IApplication.Withdrawal.selector) {
                    ++numOfWithdrawalEventsInTx;

                    // decode log data
                    (uint64 arg1, bytes memory arg2, bytes memory arg3) =
                        abi.decode(log.data, (uint64, bytes, bytes));
                    assertEq(arg1, proof.accountIndex);
                    assertEq(arg2, account);

                    withdrawalOutput = arg3;
                } else {
                    revert("unexpected event from app contract");
                }
            } else if (log.emitter == address(_erc20Token)) {
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

        {
            // decode output
            (bytes4 funcsel1, bytes memory callargs1) = withdrawalOutput.consumeBytes4();
            assertEq(funcsel1, Outputs.DelegateCallVoucher.selector);
            (address destination, bytes memory payload) =
                abi.decode(callargs1, (address, bytes));
            assertEq(destination, address(_safeErc20Transfer));

            // decode delegatecall payload
            (bytes4 funcsel2, bytes memory callargs2) = payload.consumeBytes4();
            assertEq(funcsel2, ISafeERC20Transfer.safeTransfer.selector);
            (address token, address to, uint256 value) =
                abi.decode(callargs2, (address, address, uint256));
            assertEq(token, address(_erc20Token));
            assertEq(to, user);
            assertEq(value, amount);
        }

        assertEq(_appContract.getNumberOfWithdrawals(), numOfWithdrawalsBefore + 1);
        assertTrue(_appContract.wereAccountFundsWithdrawn(proof.accountIndex));
        assertEq(_erc20Token.balanceOf(address(_appContract)), appBalance - amount);
        assertEq(_erc20Token.balanceOf(user), userBalance + amount);

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

    // ------------------------------------
    // input validation and deposit refunds
    // ------------------------------------

    function testValidateInputAndAttemptRefund(
        bytes[] calldata payloads,
        bytes calldata randomBytes
    ) external {
        // 0. Randomize chain ID
        vm.chainId(vm.randomUint(64));

        bytes[] memory inputs = new bytes[](payloads.length);
        uint256[] memory blockNumbers = new uint256[](payloads.length);
        address[] memory inputSenders = new address[](payloads.length);

        // 1. Send all inputs to the application's input box from random EOA senders,
        // at random (but chronologically consistent) block numbers and timestamps,
        // and with random block prevrandao values.
        for (uint256 i; i < payloads.length; ++i) {
            bytes memory payload = payloads[i];
            address appContract = address(_appContract);
            uint256 blockNumber = vm.randomUint(vm.getBlockNumber(), type(uint256).max);
            blockNumbers[i] = blockNumber;
            vm.roll(blockNumber);
            vm.warp(vm.randomUint(vm.getBlockTimestamp(), type(uint256).max));
            vm.prevrandao(vm.randomUint());
            address inputSender = vm.addr(boundPrivateKey(vm.randomUint()));
            vm.assume(inputSender.code.length == 0);
            inputSenders[i] = inputSender;
            vm.recordLogs();
            vm.prank(inputSender);
            bytes32 inputHash = _contracts.core.inputBox.addInput(appContract, payload);
            Vm.Log[] memory logs = vm.getRecordedLogs();
            uint256 numOfInputAdded;
            for (uint256 j; j < logs.length; ++j) {
                Vm.Log memory log = logs[j];
                if (log.emitter == address(_contracts.core.inputBox)) {
                    (bytes memory decodedInput, bytes memory decodedPayload) =
                        _decodeInputAdded(log, appContract, inputSender, i);
                    assertEq(decodedPayload, payload);
                    assertEq(keccak256(decodedInput), inputHash);
                    inputs[i] = decodedInput;
                    ++numOfInputAdded;
                } else {
                    revert("unexpected log emitter");
                }
            }
            assertEq(numOfInputAdded, 1);
            assertEq(_contracts.core.inputBox.getInputHash(appContract, i), inputHash);
            assertEq(_contracts.core.inputBox.getNumberOfInputs(appContract), i + 1);
        }

        // 2. Validate each input that was sent
        for (uint256 i; i < inputs.length; ++i) {
            _appContract.validateInputHash(i, keccak256(inputs[i]));

            (uint256 blockNumber, address inputSender, bytes memory inputPayload) =
                _appContract.validateInput(i, inputs[i]);

            assertEq(blockNumber, blockNumbers[i]);
            assertEq(inputSender, inputSenders[i]);
            assertEq(inputPayload, payloads[i]);
        }

        // 3. Attempt to validate an input with an invalid index and random bytes
        uint256 invalidInputIndex = vm.randomUint(inputs.length, type(uint256).max);
        vm.expectRevert(_encodeInvalidInputIndex(invalidInputIndex, inputs.length));
        _appContract.validateInput(invalidInputIndex, randomBytes);
        vm.expectRevert(_encodeInvalidInputIndex(invalidInputIndex, inputs.length));
        _appContract.validateInputHash(invalidInputIndex, bytes32(vm.randomUint()));

        // 4. Attempt to validate an input with a different hash (if an input was sent)
        if (inputs.length >= 1) {
            uint256 inputIndex = vm.randomUint(0, inputs.length - 1);
            bytes32 inputHash = keccak256(inputs[inputIndex]);
            bytes memory invalidInput;
            bytes32 invalidInputHash;
            while (true) {
                invalidInput = vm.randomBytes(vm.randomUint(0, (1 << 10)));
                invalidInputHash = keccak256(invalidInput);
                if (inputHash != invalidInputHash) {
                    break; // Found input with different hash
                }
            }
            vm.expectRevert(_encodeInvalidInputHash(inputHash, invalidInputHash));
            _appContract.validateInput(inputIndex, invalidInput);
            vm.expectRevert(_encodeInvalidInputHash(inputHash, invalidInputHash));
            _appContract.validateInputHash(inputIndex, invalidInputHash);
        }

        // 5. Make guardian foreclose the application
        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();

        // 6. Attempt to issue refunds for non-deposit inputs
        for (uint256 i; i < inputs.length; ++i) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IRefundOutputBuilderErrors.UnknownInputSender.selector,
                    inputSenders[i]
                )
            );
            vm.prank(vm.randomAddress());
            _appContract.issueRefund(i, inputs[i]);
        }
    }

    function testIssueRefund(
        bytes[] calldata payloads,
        uint256 tokenId,
        uint256 value,
        uint256[] calldata values,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        bytes memory input;
        bytes memory payload;
        address appContract = address(_appContract);
        address depositor = address(_assetReceiver);
        uint256 balance = vm.randomUint(value, type(uint256).max);
        uint256 blockNumber = vm.randomUint(vm.getBlockNumber(), type(uint256).max);

        // 0. Randomize environment
        vm.chainId(vm.randomUint(64));

        // 1. Add some prior inputs
        _addInputs(_contracts.core.inputBox, appContract, payloads);
        uint256 inputIndex = _contracts.core.inputBox.getNumberOfInputs(appContract);

        // 1.1. Randomly submit and accept claim
        if (vm.randomBool()) _submitAndAcceptClaim();

        // 2. Randomize deposit environment
        vm.roll(blockNumber);
        vm.warp(vm.randomUint(vm.getBlockTimestamp(), type(uint256).max));
        vm.prevrandao(vm.randomUint());

        DepositType depositType =
            DepositType(vm.randomUint(0, uint256(type(DepositType).max)));

        // 3. Deposit funds
        address portalAddress;
        uint256[] memory tokenIds;
        uint256[] memory balances;
        if (depositType == DepositType.ETHER) {
            portalAddress = address(_contracts.core.etherPortal);
            vm.deal(depositor, balance);
            vm.recordLogs();
            vm.prank(depositor);
            _contracts.core.etherPortal.depositEther{value: value}(
                appContract, execLayerData
            );
        } else if (depositType == DepositType.ERC20) {
            portalAddress = address(_contracts.core.erc20Portal);
            vm.startPrank(depositor);
            _contracts.dev.testFungibleToken.mint(balance);
            _contracts.dev.testFungibleToken
                .approve(portalAddress, vm.randomUint(value, balance));
            vm.recordLogs();
            _contracts.core.erc20Portal
                .depositERC20Tokens(
                    _contracts.dev.testFungibleToken, appContract, value, execLayerData
                );
            vm.stopPrank();
        } else if (depositType == DepositType.ERC721) {
            portalAddress = address(_contracts.core.erc721Portal);
            vm.startPrank(depositor);
            _contracts.dev.testNonFungibleToken.mint(tokenId);
            _contracts.dev.testNonFungibleToken.approve(portalAddress, tokenId);
            vm.recordLogs();
            _contracts.core.erc721Portal
                .depositERC721Token(
                    _contracts.dev.testNonFungibleToken,
                    appContract,
                    tokenId,
                    baseLayerData,
                    execLayerData
                );
            vm.stopPrank();
        } else if (depositType == DepositType.ERC1155_SINGLE) {
            portalAddress = address(_contracts.core.erc1155SinglePortal);
            vm.startPrank(depositor);
            _contracts.dev.testMultiToken.mint(tokenId, balance);
            _contracts.dev.testMultiToken.setApprovalForAll(portalAddress, true);
            vm.recordLogs();
            _contracts.core.erc1155SinglePortal
                .depositSingleERC1155Token(
                    _contracts.dev.testMultiToken,
                    appContract,
                    tokenId,
                    value,
                    baseLayerData,
                    execLayerData
                );
            vm.stopPrank();
        } else if (depositType == DepositType.ERC1155_BATCH) {
            portalAddress = address(_contracts.core.erc1155BatchPortal);
            tokenIds = vm.randomUniqueUint256Array(values.length);
            balances = vm.randomUintGe(values);
            vm.startPrank(depositor);
            _contracts.dev.testMultiToken.mintBatch(tokenIds, balances);
            _contracts.dev.testMultiToken.setApprovalForAll(portalAddress, true);
            vm.recordLogs();
            _contracts.core.erc1155BatchPortal
                .depositBatchERC1155Token(
                    _contracts.dev.testMultiToken,
                    appContract,
                    tokenIds,
                    values,
                    baseLayerData,
                    execLayerData
                );
            vm.stopPrank();
        } else {
            revert("unexpected deposit type");
        }

        // 3.1. Parse deposit tx logs
        {
            Vm.Log[] memory logs = vm.getRecordedLogs();

            uint256 numOfInputAdded;
            uint256 numOfErc20Transfers;
            uint256 numOfErc721Transfers;
            uint256 numOfErc1155SingleTransfers;
            uint256 numOfErc1155BatchTransfers;

            for (uint256 i; i < logs.length; ++i) {
                Vm.Log memory log = logs[i];
                if (log.emitter == address(_contracts.core.inputBox)) {
                    (input, payload) =
                        _decodeInputAdded(log, appContract, portalAddress, inputIndex);
                    ++numOfInputAdded;
                } else if (log.emitter == address(_contracts.dev.testFungibleToken)) {
                    assertGe(log.topics.length, 1);
                    if (log.topics[0] == IERC20.Transfer.selector) {
                        assertEq(log.topics[1], depositor.asTopic());
                        assertEq(log.topics[2], address(_appContract).asTopic());
                        assertEq(abi.decode(log.data, (uint256)), value);
                        ++numOfErc20Transfers;
                    } else {
                        revert("unexpected event from ERC-20 token contract");
                    }
                } else if (log.emitter == address(_contracts.dev.testNonFungibleToken)) {
                    assertGe(log.topics.length, 1);
                    if (log.topics[0] == IERC721.Transfer.selector) {
                        assertEq(log.topics[1], depositor.asTopic());
                        assertEq(log.topics[2], address(_appContract).asTopic());
                        assertEq(log.topics[3], bytes32(tokenId));
                        ++numOfErc721Transfers;
                    } else {
                        revert("unexpected event from ERC-721 token contract");
                    }
                } else if (log.emitter == address(_contracts.dev.testMultiToken)) {
                    assertGe(log.topics.length, 1);
                    if (log.topics[0] == IERC1155.TransferSingle.selector) {
                        assertEq(log.topics[2], depositor.asTopic());
                        assertEq(log.topics[3], address(_appContract).asTopic());

                        (uint256 arg1, uint256 arg2) =
                            abi.decode(log.data, (uint256, uint256));

                        if (depositType == DepositType.ERC1155_SINGLE) {
                            assertEq(
                                log.topics[1],
                                address(_contracts.core.erc1155SinglePortal).asTopic()
                            );
                            assertEq(arg1, tokenId);
                            assertEq(arg2, value);
                        } else if (depositType == DepositType.ERC1155_BATCH) {
                            assertEq(
                                log.topics[1],
                                address(_contracts.core.erc1155BatchPortal).asTopic()
                            );
                            assertEq(tokenIds.length, 1);
                            assertEq(arg1, tokenIds[0]);
                            assertEq(arg2, values[0]);
                        } else {
                            revert("unexpected deposit type");
                        }

                        ++numOfErc1155SingleTransfers;
                    } else if (log.topics[0] == IERC1155.TransferBatch.selector) {
                        assertEq(
                            log.topics[1],
                            address(_contracts.core.erc1155BatchPortal).asTopic()
                        );
                        assertEq(log.topics[2], depositor.asTopic());
                        assertEq(log.topics[3], address(_appContract).asTopic());

                        (uint256[] memory arg1, uint256[] memory arg2) =
                            abi.decode(log.data, (uint256[], uint256[]));

                        assertEq(arg1, tokenIds);
                        assertEq(arg2, values);

                        ++numOfErc1155BatchTransfers;
                    } else {
                        revert("unexpected event from ERC-1155 token contract");
                    }
                } else {
                    revert("unexpected log emitter");
                }
            }

            assertEq(numOfInputAdded, 1);
            assertEq(numOfErc20Transfers, (depositType == DepositType.ERC20) ? 1 : 0);
            assertEq(numOfErc721Transfers, (depositType == DepositType.ERC721) ? 1 : 0);
            assertEq(
                numOfErc1155SingleTransfers,
                ((depositType == DepositType.ERC1155_SINGLE)
                        || ((depositType == DepositType.ERC1155_BATCH)
                            && (tokenIds.length == 1)))
                    ? 1
                    : 0
            );
            assertEq(
                numOfErc1155BatchTransfers,
                ((depositType == DepositType.ERC1155_BATCH) && (tokenIds.length != 1))
                    ? 1
                    : 0
            );
        }

        // 3.2. Check deposit effects
        if (depositType == DepositType.ETHER) {
            assertEq(depositor.balance, balance - value);
        } else if (depositType == DepositType.ERC20) {
            assertEq(
                _contracts.dev.testFungibleToken.balanceOf(depositor), balance - value
            );
        } else if (depositType == DepositType.ERC721) {
            assertEq(
                _contracts.dev.testNonFungibleToken.ownerOf(tokenId),
                address(_appContract)
            );
        } else if (depositType == DepositType.ERC1155_SINGLE) {
            assertEq(
                _contracts.dev.testMultiToken.balanceOf(depositor, tokenId),
                balance - value
            );
        } else if (depositType == DepositType.ERC1155_BATCH) {
            assertEq(
                _contracts.dev.testMultiToken
                    .balanceOfBatch(depositor.repeat(tokenIds.length), tokenIds),
                balances.sub(values)
            );
        } else {
            revert("unexpected deposit type");
        }

        // 4. Randomize validation environment
        vm.roll(vm.randomUint(vm.getBlockNumber(), type(uint256).max));
        vm.warp(vm.randomUint(vm.getBlockTimestamp(), type(uint256).max));

        // 5. Validate deposit input on input box
        vm.prank(vm.randomAddress());
        assertEq(_contracts.core.inputBox.getNumberOfInputs(appContract), 1 + inputIndex);
        vm.prank(vm.randomAddress());
        assertEq(
            _contracts.core.inputBox.getInputHash(appContract, inputIndex),
            keccak256(input)
        );

        // 6. Validate deposit input hash on application
        vm.prank(vm.randomAddress());
        _appContract.validateInputHash(inputIndex, keccak256(input));

        // 7. Validate deposit input on application
        {
            uint256 decodedBlockNumber;
            address decodedInputSender;
            bytes memory decodedInputPayload;

            vm.prank(vm.randomAddress());
            (decodedBlockNumber, decodedInputSender, decodedInputPayload) =
                _appContract.validateInput(inputIndex, input);

            assertEq(decodedBlockNumber, blockNumber);
            assertEq(decodedInputSender, portalAddress);
            assertEq(decodedInputPayload, payload);
        }

        // 8. Try issuing refund before foreclosure
        vm.expectRevert(IApplication.NotForeclosed.selector);
        vm.prank(vm.randomAddress());
        _appContract.issueRefund(inputIndex, input);

        // 8.1 Try issuing refund of finalized input after foreclosure
        vm.expectRevert(_encodeCannotRefundFinalizedInput(inputIndex));
        this.simulateClaimSubmissionAcceptanceForeclosureAndRefund(inputIndex, input);

        // 9. Make guardian foreclose the application
        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();

        // 9.1. Try issuing refund for rejecting receiver contract for some assets
        {
            bool isRevertExpected;
            bytes memory errorData;

            if (depositType == DepositType.ETHER) {
                isRevertExpected = true;
                errorData = abi.encodeWithSelector(
                    AssetReceiver.EtherRejected.selector, _appContract, value
                );
            } else if (depositType == DepositType.ERC721) {
                isRevertExpected = true;
                errorData = abi.encodeWithSelector(
                    AssetReceiver.Erc721Rejected.selector,
                    _erc721Token,
                    _appContract,
                    _appContract,
                    tokenId,
                    new bytes(0)
                );
            } else if (depositType == DepositType.ERC1155_SINGLE) {
                isRevertExpected = true;
                errorData = abi.encodeWithSelector(
                    AssetReceiver.Erc1155Rejected.selector,
                    _erc1155Token,
                    _appContract,
                    _appContract,
                    tokenId,
                    value,
                    new bytes(0)
                );
            } else if (depositType == DepositType.ERC1155_BATCH) {
                isRevertExpected = true;
                errorData = (tokenIds.length == 1)
                    ? abi.encodeWithSelector(
                        AssetReceiver.Erc1155Rejected.selector,
                        _erc1155Token,
                        _appContract,
                        _appContract,
                        tokenIds[0],
                        values[0],
                        new bytes(0)
                    )
                    : abi.encodeWithSelector(
                        AssetReceiver.Erc1155BatchRejected.selector,
                        _erc1155Token,
                        _appContract,
                        _appContract,
                        tokenIds,
                        values,
                        new bytes(0)
                    );
            }

            if (isRevertExpected) {
                _assetReceiver.setRejecting(true);
                vm.prank(vm.randomAddress());
                vm.expectRevert(errorData);
                _appContract.issueRefund(inputIndex, input);
                _assetReceiver.setRejecting(false);
            }
        }

        // 10. Issue refund for deposit
        vm.prank(vm.randomAddress());
        vm.recordLogs();
        _appContract.issueRefund(inputIndex, input);

        {
            Vm.Log[] memory logs = vm.getRecordedLogs();

            uint256 numOfRefundsIssued;
            bytes4 refundOutputSelector;
            bytes memory refundOutputArgs;

            uint256 numOfErc20Transfers;
            uint256 numOfErc721Transfers;
            uint256 numOfErc1155SingleTransfers;
            uint256 numOfErc1155BatchTransfers;

            for (uint256 i; i < logs.length; ++i) {
                Vm.Log memory log = logs[i];
                if (log.emitter == address(_appContract)) {
                    assertEq(log.topics[0], IApplication.RefundIssued.selector);
                    ++numOfRefundsIssued;

                    (uint256 arg1, bytes memory arg2, bytes memory arg3) =
                        abi.decode(log.data, (uint256, bytes, bytes));

                    assertEq(arg1, inputIndex);
                    assertEq(arg2, input);

                    (refundOutputSelector, refundOutputArgs) = arg3.consumeBytes4();
                } else if (log.emitter == address(_contracts.dev.testFungibleToken)) {
                    assertGe(log.topics.length, 1);
                    if (log.topics[0] == IERC20.Transfer.selector) {
                        assertEq(log.topics[1], address(_appContract).asTopic());
                        assertEq(log.topics[2], depositor.asTopic());
                        assertEq(abi.decode(log.data, (uint256)), value);
                        ++numOfErc20Transfers;
                    } else {
                        revert("unexpected event from ERC-20 token contract");
                    }
                } else if (log.emitter == address(_contracts.dev.testNonFungibleToken)) {
                    assertGe(log.topics.length, 1);
                    if (log.topics[0] == IERC721.Transfer.selector) {
                        assertEq(log.topics[1], address(_appContract).asTopic());
                        assertEq(log.topics[2], depositor.asTopic());
                        assertEq(log.topics[3], bytes32(tokenId));
                        ++numOfErc721Transfers;
                    } else {
                        revert("unexpected event from ERC-721 token contract");
                    }
                } else if (log.emitter == address(_contracts.dev.testMultiToken)) {
                    assertGe(log.topics.length, 1);
                    if (log.topics[0] == IERC1155.TransferSingle.selector) {
                        assertEq(log.topics[1], address(_appContract).asTopic());
                        assertEq(log.topics[2], address(_appContract).asTopic());
                        assertEq(log.topics[3], depositor.asTopic());

                        (uint256 arg1, uint256 arg2) =
                            abi.decode(log.data, (uint256, uint256));

                        if (depositType == DepositType.ERC1155_SINGLE) {
                            assertEq(arg1, tokenId);
                            assertEq(arg2, value);
                        } else if (depositType == DepositType.ERC1155_BATCH) {
                            assertEq(tokenIds.length, 1);
                            assertEq(arg1, tokenIds[0]);
                            assertEq(arg2, values[0]);
                        } else {
                            revert("unexpected deposit type");
                        }

                        ++numOfErc1155SingleTransfers;
                    } else if (log.topics[0] == IERC1155.TransferBatch.selector) {
                        assertEq(log.topics[1], address(_appContract).asTopic());
                        assertEq(log.topics[2], address(_appContract).asTopic());
                        assertEq(log.topics[3], depositor.asTopic());

                        (uint256[] memory arg1, uint256[] memory arg2) =
                            abi.decode(log.data, (uint256[], uint256[]));

                        assertEq(arg1, tokenIds);
                        assertEq(arg2, values);

                        ++numOfErc1155BatchTransfers;
                    } else {
                        revert("unexpected event from ERC-1155 token contract");
                    }
                } else {
                    revert("unexpected log emitter");
                }
            }

            assertEq(numOfRefundsIssued, 1);
            assertEq(numOfErc20Transfers, (depositType == DepositType.ERC20) ? 1 : 0);
            assertEq(numOfErc721Transfers, (depositType == DepositType.ERC721) ? 1 : 0);
            assertEq(
                numOfErc1155SingleTransfers,
                ((depositType == DepositType.ERC1155_SINGLE)
                        || ((depositType == DepositType.ERC1155_BATCH)
                            && (tokenIds.length == 1)))
                    ? 1
                    : 0
            );
            assertEq(
                numOfErc1155BatchTransfers,
                ((depositType == DepositType.ERC1155_BATCH) && (tokenIds.length != 1))
                    ? 1
                    : 0
            );

            if (depositType == DepositType.ETHER) {
                assertEq(refundOutputSelector, Outputs.Voucher.selector);

                address voucherDestination;
                uint256 voucherValue;
                bytes memory voucherPayload;

                (voucherDestination, voucherValue, voucherPayload) =
                    abi.decode(refundOutputArgs, (address, uint256, bytes));

                assertEq(voucherDestination, depositor);
                assertEq(voucherValue, value);
                assertEq(voucherPayload, new bytes(0));

                assertEq(depositor.balance, balance);
            } else if (depositType == DepositType.ERC20) {
                assertEq(refundOutputSelector, Outputs.DelegateCallVoucher.selector);

                address voucherDestination;
                bytes memory voucherPayload;

                (voucherDestination, voucherPayload) =
                    abi.decode(refundOutputArgs, (address, bytes));

                assertEq(voucherDestination, address(_safeErc20Transfer));

                bytes4 selector;
                bytes memory arguments;

                (selector, arguments) = voucherPayload.consumeBytes4();
                assertEq(selector, ISafeERC20Transfer.safeTransfer.selector);

                (address refundToken, address refundRecipient, uint256 refundAmount) =
                    abi.decode(arguments, (address, address, uint256));

                assertEq(refundToken, address(_contracts.dev.testFungibleToken));
                assertEq(refundRecipient, depositor);
                assertEq(refundAmount, value);

                assertEq(_contracts.dev.testFungibleToken.balanceOf(depositor), balance);
            } else if (depositType == DepositType.ERC721) {
                assertEq(refundOutputSelector, Outputs.Voucher.selector);

                address voucherDestination;
                uint256 voucherValue;
                bytes memory voucherPayload;

                (voucherDestination, voucherValue, voucherPayload) =
                    abi.decode(refundOutputArgs, (address, uint256, bytes));

                assertEq(voucherDestination, address(_contracts.dev.testNonFungibleToken));
                assertEq(voucherValue, 0);

                bytes4 selector;
                bytes memory arguments;

                (selector, arguments) = voucherPayload.consumeBytes4();
                assertEq(
                    selector,
                    bytes4(keccak256("safeTransferFrom(address,address,uint256)"))
                );

                address refundFrom;
                address refundTo;
                uint256 refundTokenId;

                (refundFrom, refundTo, refundTokenId) =
                    abi.decode(arguments, (address, address, uint256));

                assertEq(refundFrom, address(_appContract));
                assertEq(refundTo, depositor);
                assertEq(refundTokenId, tokenId);

                assertEq(_contracts.dev.testNonFungibleToken.ownerOf(tokenId), depositor);
            } else if (depositType == DepositType.ERC1155_SINGLE) {
                assertEq(refundOutputSelector, Outputs.Voucher.selector);

                address voucherDestination;
                uint256 voucherValue;
                bytes memory voucherPayload;

                (voucherDestination, voucherValue, voucherPayload) =
                    abi.decode(refundOutputArgs, (address, uint256, bytes));

                assertEq(voucherDestination, address(_contracts.dev.testMultiToken));
                assertEq(voucherValue, 0);

                bytes4 selector;
                bytes memory arguments;

                (selector, arguments) = voucherPayload.consumeBytes4();
                assertEq(selector, IERC1155.safeTransferFrom.selector);

                address refundFrom;
                address refundTo;
                uint256 refundTokenId;
                uint256 refundValue;

                (refundFrom, refundTo, refundTokenId, refundValue,) =
                    abi.decode(arguments, (address, address, uint256, uint256, bytes));

                assertEq(refundFrom, address(_appContract));
                assertEq(refundTo, depositor);
                assertEq(refundTokenId, tokenId);
                assertEq(refundValue, value);

                assertEq(
                    _contracts.dev.testMultiToken.balanceOf(depositor, tokenId), balance
                );
            } else if (depositType == DepositType.ERC1155_BATCH) {
                assertEq(refundOutputSelector, Outputs.Voucher.selector);

                address voucherDestination;
                uint256 voucherValue;
                bytes memory voucherPayload;

                (voucherDestination, voucherValue, voucherPayload) =
                    abi.decode(refundOutputArgs, (address, uint256, bytes));

                assertEq(voucherDestination, address(_contracts.dev.testMultiToken));
                assertEq(voucherValue, 0);

                bytes4 selector;
                bytes memory arguments;

                (selector, arguments) = voucherPayload.consumeBytes4();
                assertEq(selector, IERC1155.safeBatchTransferFrom.selector);

                address refundFrom;
                address refundTo;
                uint256[] memory refundTokenIds;
                uint256[] memory refundValues;

                (refundFrom, refundTo, refundTokenIds, refundValues,) = abi.decode(
                    arguments, (address, address, uint256[], uint256[], bytes)
                );

                assertEq(refundFrom, address(_appContract));
                assertEq(refundTo, depositor);
                assertEq(refundTokenIds, tokenIds);
                assertEq(refundValues, values);

                assertEq(
                    _contracts.dev.testMultiToken
                        .balanceOfBatch(depositor.repeat(tokenIds.length), tokenIds),
                    balances
                );
            } else {
                revert("unexpected deposit type");
            }
        }

        assertEq(_appContract.getNumberOfIssuedRefunds(), 1);
        assertTrue(_appContract.wasRefundForInputIssued(inputIndex));

        // 11. Re-validate deposit input hash on application
        vm.prank(vm.randomAddress());
        _appContract.validateInputHash(inputIndex, keccak256(input));

        // 12. Re-validate deposit input on application
        {
            uint256 decodedBlockNumber;
            address decodedInputSender;
            bytes memory decodedInputPayload;

            vm.prank(vm.randomAddress());
            (decodedBlockNumber, decodedInputSender, decodedInputPayload) =
                _appContract.validateInput(inputIndex, input);

            assertEq(decodedBlockNumber, blockNumber);
            assertEq(decodedInputSender, portalAddress);
            assertEq(decodedInputPayload, payload);
        }

        // 13. Try re-issuing refund for the same deposit
        vm.prank(vm.randomAddress());
        vm.expectRevert(_encodeRefundAlreadyIssued(inputIndex));
        _appContract.issueRefund(inputIndex, input);
    }

    // ------------------
    // internal functions
    // ------------------

    function _initVariables() internal {
        for (uint256 i; i < 7; ++i) {
            _tokenIds.push(i);
            _initialSupplies.push(INITIAL_SUPPLY);
            _transferAmounts.push(vm.randomUint(1, INITIAL_SUPPLY));
        }
        _erc20Token = _contracts.dev.testFungibleToken;
        _erc721Token = _contracts.dev.testNonFungibleToken;
        _erc1155Token = _contracts.dev.testMultiToken;
        _safeErc20Transfer = _contracts.core.safeErc20Transfer;
        _etherReceiver = new EtherReceiver();
        _assetReceiver = new AssetReceiver();
    }

    function _addOutputs() internal {
        _nameOutput("EmptyOutput", _addOutput(abi.encode()));
        _nameOutput("HelloWorldNotice", _addOutput(_encodeNotice("Hello, world!")));
        _nameOutput("MyOutput", _addOutput(abi.encodeWithSignature("MyOutput()")));
        _nameOutput(
            "EtherTransferVoucher",
            _addOutput(
                _encodeVoucher(address(_assetReceiver), TRANSFER_AMOUNT, abi.encode())
            )
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
                    abi.encodeCall(
                        IERC20.transfer, (address(_assetReceiver), TRANSFER_AMOUNT)
                    )
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
                        address(_assetReceiver),
                        TOKEN_ID
                    )
                )
            )
        );
        _nameOutput(
            "ERC1155SingleTransferVoucher",
            _addOutput(
                _encodeVoucher(
                    address(_erc1155Token),
                    0,
                    abi.encodeCall(
                        IERC1155.safeTransferFrom,
                        (
                            address(_appContract),
                            address(_assetReceiver),
                            TOKEN_ID,
                            TRANSFER_AMOUNT,
                            ""
                        )
                    )
                )
            )
        );
        _nameOutput(
            "ERC1155BatchTransferVoucher",
            _addOutput(
                _encodeVoucher(
                    address(_erc1155Token),
                    0,
                    abi.encodeCall(
                        IERC1155.safeBatchTransferFrom,
                        (
                            address(_appContract),
                            address(_assetReceiver),
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
                        ISafeERC20Transfer.safeTransfer,
                        (_erc20Token, address(_assetReceiver), TRANSFER_AMOUNT)
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

    function _getAccountsDriveMerkleRoot()
        internal
        view
        returns (bytes32 accountsDriveMerkleRoot)
    {
        return _emulator.getAccountsDriveMerkleRoot();
    }

    function _buildProofComponents()
        internal
        view
        returns (LibEmulator.ProofComponents memory)
    {
        return _emulator.buildProofComponents();
    }

    function _getAccountsDriveMerkleRootProof()
        internal
        view
        returns (bytes32[] memory accountsDriveMerkleRootSiblings)
    {
        return _proofComponents.getAccountsDriveMerkleRootProof();
    }

    function _getAccountValidityProof(string memory name)
        internal
        view
        returns (AccountValidityProof memory)
    {
        return _emulator.getAccountValidityProof(_accountIndexByName[name]);
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

    /// @notice This function is used to simulate a claim acceptance, a foreclosure and
    /// a refund issuance. If the proof succeeds, then the function reverts with
    /// error message "Successful refund". If the proof fails, then the function propagates
    /// the error from the app contract.
    function simulateClaimSubmissionAcceptanceForeclosureAndRefund(
        uint256 inputIndex,
        bytes calldata input
    ) external {
        assertEq(msg.sender, address(this), "called by external account");
        uint256 lastProcessedBlockNumber = vm.getBlockNumber();
        vm.roll(vm.randomUint(lastProcessedBlockNumber + 1, type(uint256).max));
        vm.prank(_authority.owner());
        _authority.submitClaim(
            address(_appContract),
            lastProcessedBlockNumber,
            _proofComponents.outputsMerkleRoot,
            _proofComponents.getOutputsMerkleRootProof()
        );
        vm.prank(vm.randomAddress());
        _authority.acceptClaim(
            address(_appContract),
            lastProcessedBlockNumber,
            _proofComponents.getMachineMerkleRoot()
        );
        vm.prank(_appContract.getGuardian());
        _appContract.foreclose();
        vm.prank(vm.randomAddress());
        _appContract.issueRefund(inputIndex, input);
        revert("Successful proof");
    }

    function _submitAndAcceptClaim() internal {
        _proofComponents = _buildProofComponents();
        bytes32 machineMerkleRoot = _proofComponents.getMachineMerkleRoot();

        vm.prank(_authority.owner());
        _authority.submitClaim(
            address(_appContract),
            0,
            _proofComponents.outputsMerkleRoot,
            _proofComponents.getOutputsMerkleRootProof()
        );

        vm.prank(vm.randomAddress());
        _authority.acceptClaim(address(_appContract), 0, machineMerkleRoot);

        assertEq(
            _authority.getLastFinalizedMachineMerkleRoot(address(_appContract)),
            machineMerkleRoot,
            "last finalized machine Merkle root"
        );
    }

    function _proveAccountsDriveMerkleRoot() internal {
        bytes32 accountsDriveMerkleRoot = _getAccountsDriveMerkleRoot();
        bytes32[] memory proof = _getAccountsDriveMerkleRootProof();
        vm.prank(vm.randomAddress());
        _appContract.proveAccountsDriveMerkleRoot(accountsDriveMerkleRoot, proof);
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

    function _encodeInvalidInputIndex(uint256 invalidInputIndex, uint256 numOfInputs)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IApplication.InvalidInputIndex.selector, invalidInputIndex, numOfInputs
        );
    }

    function _encodeInvalidInputHash(bytes32 storedInputHash, bytes32 invalidInputHash)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IApplication.InvalidInputHash.selector, storedInputHash, invalidInputHash
        );
    }

    function _encodeRefundAlreadyIssued(uint256 inputIndex)
        internal
        pure
        returns (bytes memory)
    {
        return
            abi.encodeWithSelector(IApplication.RefundAlreadyIssued.selector, inputIndex);
    }

    function _encodeCannotRefundFinalizedInput(uint256 inputIndex)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IApplication.CannotRefundFinalizedInput.selector, inputIndex
        );
    }

    function _expectIncrementInNumberOfExecutedOutputs(uint256 before) internal view {
        assertEq(
            _appContract.getNumberOfExecutedOutputs(),
            before + 1,
            "Should increment number of executed outputs on success"
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

    function _encodeInvalidNodeIndex(uint256 nodeIndex, uint256 height)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            BinaryMerkleTreeErrors.InvalidNodeIndex.selector, nodeIndex, height
        );
    }

    function _encodeInvalidAccountRootSiblingsArrayLength()
        internal
        pure
        returns (bytes4)
    {
        return IApplication.InvalidAccountRootSiblingsArrayLength.selector;
    }

    function _encodeInvalidAccountsDriveMerkleRootProofSize()
        internal
        pure
        returns (bytes4)
    {
        return IApplication.InvalidAccountsDriveMerkleRootProofSize.selector;
    }

    function _encodeInvalidOutputHashesSiblingsArrayLength()
        internal
        pure
        returns (bytes4)
    {
        return IApplication.InvalidOutputHashesSiblingsArrayLength.selector;
    }

    function _encodeAccountsDriveMerkleRootAlreadyProved()
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IApplication.AccountsDriveMerkleRootAlreadyProved.selector
        );
    }

    function _encodeAccountsDriveMerkleRootNotProved()
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IApplication.AccountsDriveMerkleRootNotProved.selector
        );
    }

    function _encodeInvalidMachineMerkleRoot(bytes32 machineMerkleRoot)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IApplication.InvalidMachineMerkleRoot.selector, machineMerkleRoot
        );
    }

    function _encodeInvalidAccountsDriveMerkleRoot(bytes32 accountsDriveMerkleRoot)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IApplication.InvalidAccountsDriveMerkleRoot.selector, accountsDriveMerkleRoot
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
            IApplication.AccountFundsAlreadyWithdrawn.selector, accountIndex
        );
    }

    function _encodeSafeErc20FailedOperation(address token)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, token);
    }

    function _encodeAccountTooShort(uint64 attemptedAccountSize)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IWithdrawalOutputBuilderErrors.AccountTooShort.selector,
            attemptedAccountSize,
            28
        );
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
        vm.deal(address(_appContract), TRANSFER_AMOUNT);

        _assetReceiver.setRejecting(true);

        vm.expectRevert(
            abi.encodeWithSelector(
                AssetReceiver.EtherRejected.selector, _appContract, TRANSFER_AMOUNT
            )
        );
        _appContract.executeOutput(output, proof);

        _assetReceiver.setRejecting(false);

        uint256 recipientBalance = address(_assetReceiver).balance;
        uint256 appBalance = address(_appContract).balance;

        _expectEmitOutputExecuted(output, proof);

        _appContract.executeOutput(output, proof);

        assertEq(
            address(_assetReceiver).balance,
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

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721Errors.ERC721NonexistentToken.selector, TOKEN_ID
            )
        );
        _appContract.executeOutput(output, proof);

        _contracts.dev.testNonFungibleToken.mint(address(_appContract), TOKEN_ID);

        _assetReceiver.setRejecting(true);
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetReceiver.Erc721Rejected.selector,
                _erc721Token,
                _appContract,
                _appContract,
                TOKEN_ID,
                new bytes(0)
            )
        );
        _appContract.executeOutput(output, proof);
        _assetReceiver.setRejecting(false);

        _expectEmitOutputExecuted(output, proof);
        _appContract.executeOutput(output, proof);

        assertEq(
            _erc721Token.ownerOf(TOKEN_ID),
            address(_assetReceiver),
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
        // test revert

        assertLt(
            _erc20Token.balanceOf(address(_appContract)),
            TRANSFER_AMOUNT,
            "Application contract does not have enough ERC-20 tokens"
        );

        vm.expectRevert(_encodeErc20InsufficientBalance(_erc20Token, TRANSFER_AMOUNT));
        _appContract.executeOutput(output, proof);

        // test return false

        vm.mockCall(
            address(_erc20Token),
            abi.encodeCall(IERC20.transfer, (address(_assetReceiver), TRANSFER_AMOUNT)),
            abi.encode(false)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeERC20.SafeERC20FailedOperation.selector, address(_erc20Token)
            )
        );
        _appContract.executeOutput(output, proof);
        vm.clearMockedCalls();
    }

    function _testErc20Success(bytes memory output, OutputValidityProof memory proof)
        internal
    {
        uint256 numberOfExecutedOutputsBefore = _appContract.getNumberOfExecutedOutputs();
        _contracts.dev.testFungibleToken.mint(address(_appContract), TRANSFER_AMOUNT);

        uint256 recipientBalance = _erc20Token.balanceOf(address(_assetReceiver));
        uint256 appBalance = _erc20Token.balanceOf(address(_appContract));

        _expectEmitOutputExecuted(output, proof);
        _appContract.executeOutput(output, proof);

        assertEq(
            _erc20Token.balanceOf(address(_assetReceiver)),
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

        _contracts.dev.testMultiToken
            .mint(address(_appContract), TOKEN_ID, INITIAL_SUPPLY);

        _assetReceiver.setRejecting(true);
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetReceiver.Erc1155Rejected.selector,
                _erc1155Token,
                _appContract,
                _appContract,
                TOKEN_ID,
                TRANSFER_AMOUNT,
                new bytes(0)
            )
        );
        _appContract.executeOutput(output, proof);
        _assetReceiver.setRejecting(false);

        uint256 recipientBalance =
            _erc1155Token.balanceOf(address(_assetReceiver), TOKEN_ID);
        uint256 appBalance = _erc1155Token.balanceOf(address(_appContract), TOKEN_ID);

        _expectEmitOutputExecuted(output, proof);
        _appContract.executeOutput(output, proof);

        assertEq(
            _erc1155Token.balanceOf(address(_appContract), TOKEN_ID),
            appBalance - TRANSFER_AMOUNT,
            "Application contract should have the transfer amount deducted"
        );
        assertEq(
            _erc1155Token.balanceOf(address(_assetReceiver), TOKEN_ID),
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

        _contracts.dev.testMultiToken
            .mintBatch(address(_appContract), _tokenIds, _initialSupplies);

        _assetReceiver.setRejecting(true);
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetReceiver.Erc1155BatchRejected.selector,
                _erc1155Token,
                _appContract,
                _appContract,
                _tokenIds,
                _transferAmounts,
                new bytes(0)
            )
        );
        _appContract.executeOutput(output, proof);
        _assetReceiver.setRejecting(false);

        uint256 batchLength = _initialSupplies.length;
        uint256[] memory appBalances = new uint256[](batchLength);
        uint256[] memory recipientBalances = new uint256[](batchLength);
        for (uint256 i; i < batchLength; ++i) {
            appBalances[i] = _erc1155Token.balanceOf(address(_appContract), _tokenIds[i]);
            recipientBalances[i] =
                _erc1155Token.balanceOf(address(_assetReceiver), _tokenIds[i]);
        }

        _expectEmitOutputExecuted(output, proof);
        _appContract.executeOutput(output, proof);

        for (uint256 i; i < _tokenIds.length; ++i) {
            assertEq(
                _erc1155Token.balanceOf(address(_appContract), _tokenIds[i]),
                appBalances[i] - _transferAmounts[i],
                "Application contract should have the transfer amount deducted"
            );
            assertEq(
                _erc1155Token.balanceOf(address(_assetReceiver), _tokenIds[i]),
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

    function _validateAccounts(bool expectError, bytes memory expectedError) internal {
        for (uint256 i; i < _accountNames.length; ++i) {
            string memory name = _accountNames[i];
            bytes memory account = _getAccount(name);
            bytes32 accountMerkleRoot = LibEmulator.getAccountMerkleRoot(account);
            AccountValidityProof memory proof = _getAccountValidityProof(name);
            if (expectError) vm.expectRevert(expectedError);
            _appContract.validateAccountMerkleRoot(accountMerkleRoot, proof);
            if (expectError) vm.expectRevert(expectedError);
            _appContract.validateAccount(account, proof);
        }
    }

    function _validateAccounts(bytes memory expectedError) internal {
        _validateAccounts(true, expectedError);
    }

    function _validateAccounts() internal {
        bytes memory expectedError;
        _validateAccounts(false, expectedError);
    }
}

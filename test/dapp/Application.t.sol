// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Application} from "src/dapp/Application.sol";
import {Authority} from "src/consensus/authority/Authority.sol";
import {CanonicalMachine} from "src/common/CanonicalMachine.sol";
import {IApplication} from "src/dapp/IApplication.sol";
import {IOutputsMerkleRootValidator} from "src/consensus/IOutputsMerkleRootValidator.sol";
import {OutputValidityProof} from "src/common/OutputValidityProof.sol";
import {Outputs} from "src/common/Outputs.sol";
import {SafeERC20Transfer} from "src/delegatecall/SafeERC20Transfer.sol";
import {IOwnable} from "src/access/IOwnable.sol";
import {LibAddress} from "src/library/LibAddress.sol";
import {InputBox} from "src/inputs/InputBox.sol";
import {IInputBox} from "src/inputs/IInputBox.sol";
import {DataAvailability} from "src/common/DataAvailability.sol";

import {IERC1155} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155.sol";
import {
    IERC20Errors,
    IERC721Errors,
    IERC1155Errors
} from "@openzeppelin-contracts-5.2.0/interfaces/draft-IERC6093.sol";
import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin-contracts-5.2.0/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/utils/SafeERC20.sol";

import {Vm} from "forge-std-1.9.6/src/Vm.sol";
import {Test} from "forge-std-1.9.6/src/Test.sol";

import {OwnableTest} from "../util/OwnableTest.sol";
import {EtherReceiver} from "../util/EtherReceiver.sol";
import {ExternalLibMerkle32} from "../library/LibMerkle32.t.sol";
import {LibAddressArray} from "../util/LibAddressArray.sol";
import {LibEmulator} from "../util/LibEmulator.sol";
import {SimpleERC20} from "../util/SimpleERC20.sol";
import {SimpleERC721} from "../util/SimpleERC721.sol";
import {SimpleSingleERC1155, SimpleBatchERC1155} from "../util/SimpleERC1155.sol";

contract ApplicationTest is Test, OwnableTest {
    using LibEmulator for LibEmulator.State;
    using ExternalLibMerkle32 for bytes32[];
    using LibAddressArray for Vm;

    IApplication _appContract;
    EtherReceiver _etherReceiver;
    Authority _authority;
    IERC20 _erc20Token;
    IERC721 _erc721Token;
    IERC1155 _erc1155SingleToken;
    IERC1155 _erc1155BatchToken;
    SafeERC20Transfer _safeERC20Transfer;
    IInputBox _inputBox;

    LibEmulator.State _emulator;
    address _appOwner;
    address _authorityOwner;
    address _recipient;
    address _tokenOwner;
    bytes _dataAvailability;
    string[] _outputNames;
    uint256[] _tokenIds;
    uint256[] _initialSupplies;
    uint256[] _transferAmounts;
    mapping(string => LibEmulator.OutputIndex) _outputIndexByName;

    uint256 constant _epochLength = 1;
    bytes32 constant _templateHash = keccak256("templateHash");
    uint256 constant _initialSupply = 1000000000000000000000000000000000000;
    uint256 constant _tokenId = 88888888;
    uint256 constant _transferAmount = 42;

    function setUp() public {
        _initVariables();
        _deployContracts();
        _addOutputs();
        _submitClaim();
    }

    // ------------
    // ownable test
    // ------------

    function _getOwnableContract() internal view override returns (IOwnable) {
        return _appContract;
    }

    // -----------
    // constructor
    // -----------

    function testConstructorRevertsInvalidOwner() external {
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0))
        );
        new Application(_authority, address(0), _templateHash, new bytes(0));
    }

    function testConstructor(
        uint256 blockNumber,
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address owner,
        bytes32 templateHash,
        bytes calldata dataAvailability
    ) external {
        vm.assume(owner != address(0));

        vm.roll(blockNumber);

        vm.expectEmit(true, true, false, false);
        emit Ownable.OwnershipTransferred(address(0), owner);

        IApplication appContract = new Application(
            outputsMerkleRootValidator, owner, templateHash, dataAvailability
        );

        assertEq(
            address(appContract.getOutputsMerkleRootValidator()),
            address(outputsMerkleRootValidator)
        );
        assertEq(appContract.owner(), owner);
        assertEq(appContract.getTemplateHash(), templateHash);
        assertEq(appContract.getDataAvailability(), dataAvailability);
        assertEq(appContract.getDeploymentBlockNumber(), blockNumber);
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
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller)
        );
        _appContract.migrateToOutputsMerkleRootValidator(newOutputsMerkleRootValidator);
    }

    function testMigrateToOutputsMerkleRootValidator(
        IOutputsMerkleRootValidator newOutputsMerkleRootValidator
    ) external {
        vm.prank(_appOwner);
        vm.expectEmit(false, false, false, true, address(_appContract));
        emit IApplication.OutputsMerkleRootValidatorChanged(newOutputsMerkleRootValidator);
        _appContract.migrateToOutputsMerkleRootValidator(newOutputsMerkleRootValidator);
        assertEq(
            address(_appContract.getOutputsMerkleRootValidator()),
            address(newOutputsMerkleRootValidator)
        );
    }

    // -----------------
    // output validation
    // -----------------

    function testValidateOutputAndOutputHash() external view {
        for (uint256 i; i < _outputNames.length; ++i) {
            string memory name = _outputNames[i];
            bytes memory output = _getOutput(name);
            OutputValidityProof memory proof = _getProof(name);
            _appContract.validateOutput(output, proof);
            _appContract.validateOutputHash(keccak256(output), proof);
        }
    }

    function testRevertsInvalidOutputHashesSiblingsArrayLength() external {
        string memory name = "HelloWorldNotice";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getProof(name);

        proof.outputHashesSiblings = new bytes32[](0);

        _expectRevertInvalidOutputHashesSiblingsArrayLength();
        _appContract.validateOutput(output, proof);

        _expectRevertInvalidOutputHashesSiblingsArrayLength();
        _appContract.validateOutputHash(keccak256(output), proof);
    }

    function testRevertsClaimNotAccepted() external {
        string memory name = "HelloWorldNotice";
        OutputValidityProof memory proof = _getProof(name);

        bytes memory fakeOutput = _encodeNotice("Goodbye, World!");
        bytes32 fakeClaim = proof.outputHashesSiblings.merkleRootAfterReplacement(
            proof.outputIndex, keccak256(fakeOutput)
        );

        _expectRevertClaimNotAccepted(fakeClaim);
        _appContract.validateOutput(fakeOutput, proof);

        _expectRevertClaimNotAccepted(fakeClaim);
        _appContract.validateOutputHash(keccak256(fakeOutput), proof);
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
        OutputValidityProof memory proof = _getProof(name);

        _testEtherTransfer(output, proof);
    }

    function testExecuteEtherMintVoucher() external {
        string memory name = "EtherMintVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getProof(name);

        _testEtherMint(output, proof);
    }

    function testExecuteERC20TransferVoucher() external {
        string memory name = "ERC20TransferVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getProof(name);

        assertLt(
            _erc20Token.balanceOf(address(_appContract)),
            _transferAmount,
            "Application contract does not have enough ERC-20 tokens"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                address(_appContract),
                _erc20Token.balanceOf(address(_appContract)),
                _transferAmount
            )
        );
        _appContract.executeOutput(output, proof);

        _testERC20Success(output, proof);
    }

    function testExecuteERC721TransferVoucher() external {
        string memory name = "ERC721TransferVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getProof(name);

        _testERC721Transfer(output, proof);
    }

    function testExecuteERC1155SingleTransferVoucher() external {
        string memory name = "ERC1155SingleTransferVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getProof(name);

        _testERC1155SingleTransfer(output, proof);
    }

    function testExecuteERC1155BatchTransferVoucher() external {
        string memory name = "ERC1155BatchTransferVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getProof(name);

        _testERC1155BatchTransfer(output, proof);
    }

    function testExecuteEmptyOutput() external {
        string memory name = "EmptyOutput";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getProof(name);

        _expectRevertOutputNotExecutable(output);
        _appContract.executeOutput(output, proof);
    }

    function testExecuteMyOutput() external {
        string memory name = "MyOutput";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getProof(name);

        _expectRevertOutputNotExecutable(output);
        _appContract.executeOutput(output, proof);
    }

    function testExecuteNotice() external {
        string memory name = "HelloWorldNotice";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getProof(name);

        _expectRevertOutputNotExecutable(output);
        _appContract.executeOutput(output, proof);
    }

    function testExecuteERC20TransferDelegateCallVoucherFail() external {
        string memory name = "ERC20DelegateCallVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getProof(name);

        _testERC20Fail(output, proof);
    }

    function testExecuteERC20TransferDelegateCallVoucherSuccess() external {
        string memory name = "ERC20DelegateCallVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getProof(name);

        _testERC20Success(output, proof);
    }

    // ------------------
    // internal functions
    // ------------------

    function _initVariables() internal {
        address[] memory addresses = vm.addrs(4);
        _authorityOwner = addresses[0];
        _appOwner = addresses[1];
        _recipient = addresses[2];
        _tokenOwner = addresses[3];
        for (uint256 i; i < 7; ++i) {
            _tokenIds.push(i);
            _initialSupplies.push(_initialSupply);
            _transferAmounts.push(
                1 + (uint256(keccak256(abi.encode(i))) % _initialSupply)
            );
        }
    }

    function _deployContracts() internal {
        _etherReceiver = new EtherReceiver();
        _erc20Token = new SimpleERC20(_tokenOwner, _initialSupply);
        _erc721Token = new SimpleERC721(_tokenOwner, _tokenId);
        _erc1155SingleToken =
            new SimpleSingleERC1155(_tokenOwner, _tokenId, _initialSupply);
        _erc1155BatchToken =
            new SimpleBatchERC1155(_tokenOwner, _tokenIds, _initialSupplies);
        _inputBox = new InputBox();
        _authority = new Authority(_authorityOwner, _epochLength);
        _dataAvailability = abi.encodeCall(DataAvailability.InputBox, (_inputBox));
        _appContract =
            new Application(_authority, _appOwner, _templateHash, _dataAvailability);
        _safeERC20Transfer = new SafeERC20Transfer();
    }

    function _addOutputs() internal {
        _nameOutput("EmptyOutput", _addOutput(abi.encode()));
        _nameOutput("HelloWorldNotice", _addOutput(_encodeNotice("Hello, world!")));
        _nameOutput("MyOutput", _addOutput(abi.encodeWithSignature("MyOutput()")));
        _nameOutput(
            "EtherTransferVoucher",
            _addOutput(_encodeVoucher(_recipient, _transferAmount, abi.encode()))
        );
        _nameOutput(
            "EtherMintVoucher",
            _addOutput(
                _encodeVoucher(
                    address(_etherReceiver),
                    _transferAmount,
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
                    abi.encodeCall(IERC20.transfer, (_recipient, _transferAmount))
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
                        _tokenId
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
                        (address(_appContract), _recipient, _tokenId, _transferAmount, "")
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
                    address(_safeERC20Transfer),
                    abi.encodeCall(
                        SafeERC20Transfer.safeTransfer,
                        (_erc20Token, _recipient, _transferAmount)
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

    function _getProof(string memory name)
        internal
        view
        returns (OutputValidityProof memory)
    {
        return _emulator.getOutputValidityProof(_outputIndexByName[name]);
    }

    function _submitClaim() internal {
        bytes32 outputsMerkleRoot = _emulator.getOutputsMerkleRoot();
        vm.prank(_authorityOwner);
        _authority.submitClaim(address(_appContract), 0, outputsMerkleRoot);
    }

    function _expectEmitOutputExecuted(
        bytes memory output,
        OutputValidityProof memory proof
    ) internal {
        vm.expectEmit(false, false, false, true, address(_appContract));
        emit IApplication.OutputExecuted(proof.outputIndex, output);
    }

    function _expectRevertOutputNotExecutable(bytes memory output) internal {
        vm.expectRevert(
            abi.encodeWithSelector(IApplication.OutputNotExecutable.selector, output)
        );
    }

    function _expectRevertOutputNotReexecutable(bytes memory output) internal {
        vm.expectRevert(
            abi.encodeWithSelector(IApplication.OutputNotReexecutable.selector, output)
        );
    }

    function _expectNumberOfExecutedOutputsIncrement(uint256 before) internal view {
        assertEq(
            _appContract.getNumberOfExecutedOutputs(),
            before + 1,
            "Should increment number of executed outputs on revert"
        );
    }

    function _expectNumberOfExecutedOutputsSame(uint256 before) internal view {
        assertEq(
            _appContract.getNumberOfExecutedOutputs(),
            before,
            "Should not increment number of executed outputs on revert"
        );
    }

    function _expectRevertInvalidOutputHashesSiblingsArrayLength() internal {
        vm.expectRevert(IApplication.InvalidOutputHashesSiblingsArrayLength.selector);
    }

    function _expectRevertClaimNotAccepted(bytes32 outputsMerkleRoot) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                IApplication.InvalidOutputsMerkleRoot.selector, outputsMerkleRoot
            )
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
            _transferAmount,
            "Application contract does not have enough Ether"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IApplication.InsufficientFunds.selector, _transferAmount, 0
            )
        );
        _appContract.executeOutput(output, proof);
        _expectNumberOfExecutedOutputsSame(numberOfExecutedOutputsBefore);
        vm.deal(address(_appContract), _transferAmount);

        uint256 recipientBalance = _recipient.balance;
        uint256 appBalance = address(_appContract).balance;

        _expectEmitOutputExecuted(output, proof);

        _appContract.executeOutput(output, proof);

        assertEq(
            _recipient.balance,
            recipientBalance + _transferAmount,
            "Recipient should have received the transfer amount"
        );

        assertEq(
            address(_appContract).balance,
            appBalance - _transferAmount,
            "Application contract should have the transfer amount deducted"
        );

        assertTrue(_wasOutputExecuted(proof), "Output should be marked as executed");
        _expectNumberOfExecutedOutputsIncrement(numberOfExecutedOutputsBefore);
        _expectRevertOutputNotReexecutable(output);
        _appContract.executeOutput(output, proof);
    }

    function _testEtherMint(bytes memory output, OutputValidityProof memory proof)
        internal
    {
        uint256 numberOfExecutedOutputsBefore = _appContract.getNumberOfExecutedOutputs();
        assertLt(
            address(_appContract).balance,
            _transferAmount,
            "Application contract does not have enough Ether"
        );

        vm.expectRevert();
        _appContract.executeOutput(output, proof);

        _expectNumberOfExecutedOutputsSame(numberOfExecutedOutputsBefore);
        vm.deal(address(_appContract), _transferAmount);

        uint256 recipientBalance = address(_etherReceiver).balance;
        uint256 appBalance = address(_appContract).balance;
        uint256 balanceOf = _etherReceiver.balanceOf(address(_appContract));

        _expectEmitOutputExecuted(output, proof);
        _appContract.executeOutput(output, proof);

        assertEq(
            address(_etherReceiver).balance,
            recipientBalance + _transferAmount,
            "Recipient should have received the transfer amount"
        );

        assertEq(
            address(_appContract).balance,
            appBalance - _transferAmount,
            "Application contract should have the transfer amount deducted"
        );

        assertEq(
            _etherReceiver.balanceOf(address(_appContract)),
            balanceOf + _transferAmount,
            "Application contract should have the transfer amount minted"
        );

        assertTrue(_wasOutputExecuted(proof), "Output should be marked as executed");
        _expectNumberOfExecutedOutputsIncrement(numberOfExecutedOutputsBefore);

        _expectRevertOutputNotReexecutable(output);
        _appContract.executeOutput(output, proof);
    }

    function _testERC721Transfer(bytes memory output, OutputValidityProof memory proof)
        internal
    {
        uint256 numberOfExecutedOutputsBefore = _appContract.getNumberOfExecutedOutputs();
        assertEq(
            _erc721Token.ownerOf(_tokenId),
            _tokenOwner,
            "The NFT is initially owned by `_tokenOwner`"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721Errors.ERC721InsufficientApproval.selector,
                address(_appContract),
                _tokenId
            )
        );
        _appContract.executeOutput(output, proof);
        _expectNumberOfExecutedOutputsSame(numberOfExecutedOutputsBefore);

        vm.prank(_tokenOwner);
        _erc721Token.safeTransferFrom(_tokenOwner, address(_appContract), _tokenId);

        _expectEmitOutputExecuted(output, proof);
        _appContract.executeOutput(output, proof);

        assertEq(
            _erc721Token.ownerOf(_tokenId),
            _recipient,
            "The NFT is then transferred to the recipient"
        );

        assertTrue(_wasOutputExecuted(proof), "Output should be marked as executed");
        _expectNumberOfExecutedOutputsIncrement(numberOfExecutedOutputsBefore);

        _expectRevertOutputNotReexecutable(output);
        _appContract.executeOutput(output, proof);
    }

    function _testERC20Fail(bytes memory output, OutputValidityProof memory proof)
        internal
    {
        uint256 numberOfExecutedOutputsBefore = _appContract.getNumberOfExecutedOutputs();
        // test revert

        assertLt(
            _erc20Token.balanceOf(address(_appContract)),
            _transferAmount,
            "Application contract does not have enough ERC-20 tokens"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                address(_appContract),
                _erc20Token.balanceOf(address(_appContract)),
                _transferAmount
            )
        );
        _appContract.executeOutput(output, proof);
        _expectNumberOfExecutedOutputsSame(numberOfExecutedOutputsBefore);

        // test return false

        vm.mockCall(
            address(_erc20Token),
            abi.encodeCall(_erc20Token.transfer, (_recipient, _transferAmount)),
            abi.encode(false)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeERC20.SafeERC20FailedOperation.selector, address(_erc20Token)
            )
        );
        _appContract.executeOutput(output, proof);
        _expectNumberOfExecutedOutputsSame(numberOfExecutedOutputsBefore);
        vm.clearMockedCalls();
    }

    function _testERC20Success(bytes memory output, OutputValidityProof memory proof)
        internal
    {
        uint256 numberOfExecutedOutputsBefore = _appContract.getNumberOfExecutedOutputs();
        vm.prank(_tokenOwner);
        _erc20Token.transfer(address(_appContract), _transferAmount);

        uint256 recipientBalance = _erc20Token.balanceOf(address(_recipient));
        uint256 appBalance = _erc20Token.balanceOf(address(_appContract));

        _expectEmitOutputExecuted(output, proof);
        _appContract.executeOutput(output, proof);

        assertEq(
            _erc20Token.balanceOf(address(_recipient)),
            recipientBalance + _transferAmount,
            "Recipient should have received the transfer amount"
        );

        assertEq(
            _erc20Token.balanceOf(address(_appContract)),
            appBalance - _transferAmount,
            "Application contract should have the transfer amount deducted"
        );

        assertTrue(_wasOutputExecuted(proof), "Output should be marked as executed");
        _expectNumberOfExecutedOutputsIncrement(numberOfExecutedOutputsBefore);

        _expectRevertOutputNotReexecutable(output);
        _appContract.executeOutput(output, proof);
    }

    function _testERC1155SingleTransfer(
        bytes memory output,
        OutputValidityProof memory proof
    ) internal {
        uint256 numberOfExecutedOutputsBefore = _appContract.getNumberOfExecutedOutputs();
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Errors.ERC1155InsufficientBalance.selector,
                address(_appContract),
                0,
                _transferAmount,
                _tokenId
            )
        );
        _appContract.executeOutput(output, proof);
        _expectNumberOfExecutedOutputsSame(numberOfExecutedOutputsBefore);

        vm.prank(_tokenOwner);
        _erc1155SingleToken.safeTransferFrom(
            _tokenOwner, address(_appContract), _tokenId, _initialSupply, ""
        );

        uint256 recipientBalance = _erc1155SingleToken.balanceOf(_recipient, _tokenId);
        uint256 appBalance =
            _erc1155SingleToken.balanceOf(address(_appContract), _tokenId);

        _expectEmitOutputExecuted(output, proof);
        _appContract.executeOutput(output, proof);

        assertEq(
            _erc1155SingleToken.balanceOf(address(_appContract), _tokenId),
            appBalance - _transferAmount,
            "Application contract should have the transfer amount deducted"
        );
        assertEq(
            _erc1155SingleToken.balanceOf(_recipient, _tokenId),
            recipientBalance + _transferAmount,
            "Recipient should have received the transfer amount"
        );

        assertTrue(_wasOutputExecuted(proof), "Output should be marked as executed");
        _expectNumberOfExecutedOutputsIncrement(numberOfExecutedOutputsBefore);

        _expectRevertOutputNotReexecutable(output);
        _appContract.executeOutput(output, proof);
    }

    function _testERC1155BatchTransfer(
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
        _expectNumberOfExecutedOutputsSame(numberOfExecutedOutputsBefore);

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
        _expectNumberOfExecutedOutputsIncrement(numberOfExecutedOutputsBefore);

        _expectRevertOutputNotReexecutable(output);
        _appContract.executeOutput(output, proof);
    }
}

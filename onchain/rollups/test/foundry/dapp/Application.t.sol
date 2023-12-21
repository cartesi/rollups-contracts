// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Application Test
pragma solidity ^0.8.22;

import {TestBase} from "../util/TestBase.sol";

import {Application} from "contracts/dapp/Application.sol";
import {IApplication} from "contracts/dapp/IApplication.sol";
import {Proof} from "contracts/common/Proof.sol";
import {IConsensus} from "contracts/consensus/IConsensus.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {IInputRelay} from "contracts/inputs/IInputRelay.sol";
import {LibOutputValidation} from "contracts/library/LibOutputValidation.sol";
import {LibProof} from "contracts/library/LibProof.sol";
import {OutputValidityProof} from "contracts/common/OutputValidityProof.sol";
import {OutputEncoding} from "contracts/common/OutputEncoding.sol";
import {InputRange} from "contracts/common/InputRange.sol";

import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20Errors, IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {LibServerManager} from "../util/LibServerManager.sol";
import {LibBytes} from "../util/LibBytes.sol";
import {SimpleConsensus} from "../util/SimpleConsensus.sol";
import {SimpleERC20} from "../util/SimpleERC20.sol";
import {SimpleERC721} from "../util/SimpleERC721.sol";

import "forge-std/console.sol";

contract EtherReceiver {
    receive() external payable {}
}

contract ApplicationTest is TestBase {
    using LibServerManager for LibServerManager.RawFinishEpochResponse;
    using LibServerManager for LibServerManager.Proof;
    using LibServerManager for LibServerManager.Proof[];
    using LibProof for Proof;

    enum OutputName {
        DummyNotice,
        ERC20TransferVoucher,
        ETHWithdrawalVoucher,
        ERC721TransferVoucher
    }

    error UnexpectedOutputEnum(
        LibServerManager.OutputEnum expected,
        LibServerManager.OutputEnum obtained,
        uint256 inputIndexWithinEpoch
    );

    error InputIndexWithinEpochOutOfBounds(
        uint256 length,
        uint256 inputIndexWithinEpoch
    );

    error ProofNotFound(
        LibServerManager.OutputEnum outputEnum,
        uint256 inputIndexWithinEpoch
    );

    Application app;
    IConsensus consensus;
    IERC20 erc20Token;
    IERC721 erc721Token;

    struct Voucher {
        address destination;
        bytes payload;
    }

    LibServerManager.OutputEnum[] outputEnums;
    mapping(uint256 => Voucher) vouchers;
    mapping(uint256 => bytes) notices;

    bytes encodedFinishEpochResponse;

    IInputBox immutable inputBox;
    address immutable appOwner;
    address immutable noticeSender;
    address immutable recipient;
    address immutable tokenOwner;
    bytes32 immutable salt;
    bytes32 immutable templateHash;
    uint256 immutable initialSupply;
    uint256 immutable tokenId;
    uint256 immutable transferAmount;
    IInputRelay[] inputRelays;

    constructor() {
        appOwner = LibBytes.hashToAddress("appOwner");
        initialSupply = LibBytes.hashToUint256("initialSupply");
        inputBox = IInputBox(LibBytes.hashToAddress("inputBox"));
        noticeSender = LibBytes.hashToAddress("noticeSender");
        recipient = LibBytes.hashToAddress("recipient");
        salt = keccak256("salt");
        templateHash = keccak256("templateHash");
        tokenId = LibBytes.hashToUint256("tokenId");
        tokenOwner = LibBytes.hashToAddress("tokenOwner");
        transferAmount =
            LibBytes.hashToUint256("transferAmount") %
            (initialSupply + 1);
        for (uint256 i; i < 5; ++i) {
            inputRelays.push(
                IInputRelay(
                    LibBytes.hashToAddress(abi.encode("Input Relays", i))
                )
            );
        }
    }

    function setUp() public {
        deployContracts();
        generateOutputs();
        writeInputs();
        removeExtraInputs();
        readFinishEpochResponse();
    }

    function testSupportsInterface(bytes4 _randomInterfaceId) public {
        assertTrue(app.supportsInterface(type(IApplication).interfaceId));
        assertTrue(app.supportsInterface(type(IERC721Receiver).interfaceId));
        assertTrue(app.supportsInterface(type(IERC1155Receiver).interfaceId));
        assertTrue(app.supportsInterface(type(IERC165).interfaceId));

        assertFalse(app.supportsInterface(bytes4(0xffffffff)));

        vm.assume(_randomInterfaceId != type(IApplication).interfaceId);
        vm.assume(_randomInterfaceId != type(IERC721Receiver).interfaceId);
        vm.assume(_randomInterfaceId != type(IERC1155Receiver).interfaceId);
        vm.assume(_randomInterfaceId != type(IERC165).interfaceId);
        assertFalse(app.supportsInterface(_randomInterfaceId));
    }

    function testConstructorWithOwnerAsZeroAddress(
        IInputBox _inputBox,
        IInputRelay[] calldata _inputRelays,
        bytes32 _templateHash
    ) public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableInvalidOwner.selector,
                address(0)
            )
        );
        new Application(
            consensus,
            _inputBox,
            _inputRelays,
            address(0),
            _templateHash
        );
    }

    function testConstructor(
        IInputBox _inputBox,
        IInputRelay[] calldata _inputRelays,
        address _owner,
        bytes32 _templateHash
    ) public {
        vm.assume(_owner != address(0));

        vm.expectEmit(true, true, false, false);
        emit Ownable.OwnershipTransferred(address(0), _owner);

        app = new Application(
            consensus,
            _inputBox,
            _inputRelays,
            _owner,
            _templateHash
        );

        assertEq(address(app.getConsensus()), address(consensus));
        assertEq(address(app.getInputBox()), address(_inputBox));
        // abi.encode is used instead of a loop
        assertEq(abi.encode(app.getInputRelays()), abi.encode(_inputRelays));
        assertEq(app.owner(), _owner);
        assertEq(app.getTemplateHash(), _templateHash);
    }

    // test notices

    function testNoticeValidation() public {
        bytes memory notice = getNotice(OutputName.DummyNotice);
        Proof memory proof = setupNoticeProof(OutputName.DummyNotice);

        validateNotice(notice, proof);

        // reverts if notice is incorrect
        bytes memory falseNotice = abi.encodePacked(bytes4(0xdeaddead));
        vm.expectRevert(
            LibOutputValidation.IncorrectOutputHashesRootHash.selector
        );
        validateNotice(falseNotice, proof);
    }

    // test vouchers

    function testExecuteVoucherAndEvent(uint256 _appInitBalance) public {
        _appInitBalance = boundBalance(_appInitBalance);

        Voucher memory voucher = getVoucher(OutputName.ERC20TransferVoucher);
        Proof memory proof = setupVoucherProof(OutputName.ERC20TransferVoucher);

        // not able to execute voucher because application has 0 balance
        assertEq(erc20Token.balanceOf(address(app)), 0);
        assertEq(erc20Token.balanceOf(recipient), 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                address(app),
                0,
                transferAmount
            )
        );
        executeVoucher(voucher, proof);
        assertEq(erc20Token.balanceOf(address(app)), 0);
        assertEq(erc20Token.balanceOf(recipient), 0);

        // fund application
        vm.prank(tokenOwner);
        erc20Token.transfer(address(app), _appInitBalance);
        assertEq(erc20Token.balanceOf(address(app)), _appInitBalance);
        assertEq(erc20Token.balanceOf(recipient), 0);

        // expect event
        vm.expectEmit(false, false, false, true, address(app));
        emit IApplication.VoucherExecuted(
            _calculateInputIndex(proof),
            proof.validity.outputIndexWithinInput
        );

        // perform call
        executeVoucher(voucher, proof);

        // check result
        assertEq(
            erc20Token.balanceOf(address(app)),
            _appInitBalance - transferAmount
        );
        assertEq(erc20Token.balanceOf(recipient), transferAmount);
    }

    function testRevertsReexecution(uint256 _appInitBalance) public {
        _appInitBalance = boundBalance(_appInitBalance);

        Voucher memory voucher = getVoucher(OutputName.ERC20TransferVoucher);
        Proof memory proof = setupVoucherProof(OutputName.ERC20TransferVoucher);

        // fund application
        vm.prank(tokenOwner);
        erc20Token.transfer(address(app), _appInitBalance);

        // 1st execution attempt should succeed
        executeVoucher(voucher, proof);

        // 2nd execution attempt should fail
        vm.expectRevert(Application.VoucherReexecutionNotAllowed.selector);
        executeVoucher(voucher, proof);

        // end result should be the same as executing successfully only once
        assertEq(
            erc20Token.balanceOf(address(app)),
            _appInitBalance - transferAmount
        );
        assertEq(erc20Token.balanceOf(recipient), transferAmount);
    }

    function testWasVoucherExecuted(uint256 _appInitBalance) public {
        _appInitBalance = boundBalance(_appInitBalance);

        Voucher memory voucher = getVoucher(OutputName.ERC20TransferVoucher);
        Proof memory proof = setupVoucherProof(OutputName.ERC20TransferVoucher);

        uint256 inputIndex = _calculateInputIndex(proof);

        // before executing voucher
        bool executed = app.wasVoucherExecuted(
            inputIndex,
            proof.validity.outputIndexWithinInput
        );
        assertEq(executed, false);

        // execute voucher - failed
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                address(app),
                0,
                transferAmount
            )
        );
        executeVoucher(voucher, proof);

        // `wasVoucherExecuted` should still return false
        executed = app.wasVoucherExecuted(
            inputIndex,
            proof.validity.outputIndexWithinInput
        );
        assertEq(executed, false);

        // execute voucher - succeeded
        vm.prank(tokenOwner);
        erc20Token.transfer(address(app), _appInitBalance);
        executeVoucher(voucher, proof);

        // after executing voucher, `wasVoucherExecuted` should return true
        executed = app.wasVoucherExecuted(
            inputIndex,
            proof.validity.outputIndexWithinInput
        );
        assertEq(executed, true);
    }

    function testRevertsEpochHash() public {
        Voucher memory voucher = getVoucher(OutputName.ERC20TransferVoucher);
        Proof memory proof = setupVoucherProof(OutputName.ERC20TransferVoucher);

        proof.validity.vouchersEpochRootHash = bytes32(uint256(0xdeadbeef));

        vm.expectRevert(LibOutputValidation.IncorrectEpochHash.selector);
        executeVoucher(voucher, proof);
    }

    function testRevertsOutputsEpochRootHash() public {
        Voucher memory voucher = getVoucher(OutputName.ERC20TransferVoucher);
        Proof memory proof = setupVoucherProof(OutputName.ERC20TransferVoucher);

        proof.validity.outputHashesRootHash = bytes32(uint256(0xdeadbeef));

        vm.expectRevert(
            LibOutputValidation.IncorrectOutputsEpochRootHash.selector
        );
        executeVoucher(voucher, proof);
    }

    function testRevertsOutputHashesRootHash() public {
        Voucher memory voucher = getVoucher(OutputName.ERC20TransferVoucher);
        Proof memory proof = setupVoucherProof(OutputName.ERC20TransferVoucher);

        proof.validity.outputIndexWithinInput = 0xdeadbeef;

        vm.expectRevert(
            LibOutputValidation.IncorrectOutputHashesRootHash.selector
        );
        executeVoucher(voucher, proof);
    }

    function testRevertsInputIndexOutOfRange() public {
        OutputName outputName = OutputName.ERC20TransferVoucher;
        Voucher memory voucher = getVoucher(outputName);
        Proof memory proof = getVoucherProof(uint256(outputName));
        uint256 inputIndex = _calculateInputIndex(proof);

        // If the input index were 0, then there would be no way for the input index
        // in input box to be out of bounds because every claim is non-empty,
        // as it must contain at least one input
        require(inputIndex >= 1, "cannot test with input index less than 1");

        // Here we change the input range artificially to make it look like it ends
        // before the actual input (which is still provable!).
        // The `Application` contract, however, will not allow such proof.
        proof.inputRange.lastIndex = inputIndex - 1;
        mockConsensus(proof);

        vm.expectRevert(
            abi.encodeWithSelector(
                IApplication.InputIndexOutOfRange.selector,
                inputIndex,
                proof.inputRange
            )
        );
        executeVoucher(voucher, proof);
    }

    // test ether transfer

    function testEtherTransfer(uint256 _appInitBalance) public {
        _appInitBalance = boundBalance(_appInitBalance);

        Voucher memory voucher = getVoucher(OutputName.ETHWithdrawalVoucher);
        Proof memory proof = setupVoucherProof(OutputName.ETHWithdrawalVoucher);

        // not able to execute voucher because application has 0 balance
        assertEq(address(app).balance, 0);
        assertEq(address(recipient).balance, 0);
        vm.expectRevert();
        executeVoucher(voucher, proof);
        assertEq(address(app).balance, 0);
        assertEq(address(recipient).balance, 0);

        // fund application
        vm.deal(address(app), _appInitBalance);
        assertEq(address(app).balance, _appInitBalance);
        assertEq(address(recipient).balance, 0);

        // expect event
        vm.expectEmit(false, false, false, true, address(app));
        emit IApplication.VoucherExecuted(
            _calculateInputIndex(proof),
            proof.validity.outputIndexWithinInput
        );

        // perform call
        executeVoucher(voucher, proof);

        // check result
        assertEq(address(app).balance, _appInitBalance - transferAmount);
        assertEq(address(recipient).balance, transferAmount);

        // cannot execute the same voucher again
        vm.expectRevert(Application.VoucherReexecutionNotAllowed.selector);
        executeVoucher(voucher, proof);
    }

    function testWithdrawEtherContract(
        uint256 _value,
        address _notApplication
    ) public {
        vm.assume(_value <= address(this).balance);
        vm.assume(_notApplication != address(app));
        address receiver = address(new EtherReceiver());

        // fund application
        vm.deal(address(app), _value);

        // withdrawEther cannot be called by anyone
        vm.expectRevert(Application.OnlyApplication.selector);
        vm.prank(_notApplication);
        app.withdrawEther(receiver, _value);

        // withdrawEther can only be called by application itself
        uint256 preBalance = receiver.balance;
        vm.prank(address(app));
        app.withdrawEther(receiver, _value);
        assertEq(receiver.balance, preBalance + _value);
        assertEq(address(app).balance, 0);
    }

    function testWithdrawEtherEOA(
        uint256 _value,
        address _notApplication,
        uint256 _receiverSeed
    ) public {
        vm.assume(_notApplication != address(app));
        vm.assume(_value <= address(this).balance);

        // by deriving receiver from keccak-256, we avoid
        // collisions with precompiled contract addresses
        // assume receiver is not a contract
        address receiver = address(
            bytes20(keccak256(abi.encode(_receiverSeed)))
        );
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(receiver)
        }
        vm.assume(codeSize == 0);

        // fund application
        vm.deal(address(app), _value);

        // withdrawEther cannot be called by anyone
        vm.expectRevert(Application.OnlyApplication.selector);
        vm.prank(_notApplication);
        app.withdrawEther(receiver, _value);

        // withdrawEther can only be called by application itself
        uint256 preBalance = receiver.balance;
        vm.prank(address(app));
        app.withdrawEther(receiver, _value);
        assertEq(receiver.balance, preBalance + _value);
        assertEq(address(app).balance, 0);
    }

    function testRevertsWithdrawEther(uint256 _value, uint256 _funds) public {
        vm.assume(_value > _funds);
        address receiver = address(new EtherReceiver());

        // Fund application
        vm.deal(address(app), _funds);

        // application is not funded or does not have enough funds
        vm.prank(address(app));
        vm.expectRevert(Application.EtherTransferFailed.selector);
        app.withdrawEther(receiver, _value);
    }

    // test NFT transfer

    function testWithdrawNFT() public {
        Voucher memory voucher = getVoucher(OutputName.ERC721TransferVoucher);
        Proof memory proof = setupVoucherProof(
            OutputName.ERC721TransferVoucher
        );

        // not able to execute voucher because application doesn't have the nft
        assertEq(erc721Token.ownerOf(tokenId), tokenOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721Errors.ERC721InsufficientApproval.selector,
                address(app),
                tokenId
            )
        );
        executeVoucher(voucher, proof);
        assertEq(erc721Token.ownerOf(tokenId), tokenOwner);

        // fund application
        vm.prank(tokenOwner);
        erc721Token.safeTransferFrom(tokenOwner, address(app), tokenId);
        assertEq(erc721Token.ownerOf(tokenId), address(app));

        // expect event
        vm.expectEmit(false, false, false, true, address(app));
        emit IApplication.VoucherExecuted(
            _calculateInputIndex(proof),
            proof.validity.outputIndexWithinInput
        );

        // perform call
        executeVoucher(voucher, proof);

        // check result
        assertEq(erc721Token.ownerOf(tokenId), recipient);

        // cannot execute the same voucher again
        vm.expectRevert(Application.VoucherReexecutionNotAllowed.selector);
        executeVoucher(voucher, proof);
    }

    // test migration

    function testMigrateToConsensus(
        IInputBox _inputBox,
        IInputRelay[] calldata _inputRelays,
        address _owner,
        bytes32 _templateHash,
        address _newOwner,
        address _nonZeroAddress
    ) public {
        vm.assume(_owner != address(0));
        vm.assume(_owner != address(this));
        vm.assume(_owner != _newOwner);
        vm.assume(address(_newOwner) != address(0));
        vm.assume(_nonZeroAddress != address(0));

        app = new Application(
            consensus,
            _inputBox,
            _inputRelays,
            _owner,
            _templateHash
        );

        IConsensus newConsensus = new SimpleConsensus();

        // migrate fail if not called from owner
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(this)
            )
        );
        app.migrateToConsensus(newConsensus);

        // now impersonate owner
        vm.prank(_owner);
        vm.expectEmit(false, false, false, true, address(app));
        emit IApplication.NewConsensus(newConsensus);
        app.migrateToConsensus(newConsensus);
        assertEq(address(app.getConsensus()), address(newConsensus));

        // if owner changes, then original owner no longer can migrate consensus
        vm.prank(_owner);
        app.transferOwnership(_newOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                _owner
            )
        );
        vm.prank(_owner);
        app.migrateToConsensus(consensus);

        // if new owner renounce ownership (give ownership to address 0)
        // no one will be able to migrate consensus
        vm.prank(_newOwner);
        app.renounceOwnership();
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                _nonZeroAddress
            )
        );
        vm.prank(_nonZeroAddress);
        app.migrateToConsensus(consensus);
    }

    function deployContracts() internal {
        consensus = deployConsensusDeterministically();
        app = deployApplicationDeterministically();
        erc20Token = deployERC20Deterministically();
        erc721Token = deployERC721Deterministically();
    }

    function deployApplicationDeterministically()
        internal
        returns (Application)
    {
        vm.prank(appOwner);
        return
            new Application{salt: salt}(
                consensus,
                inputBox,
                inputRelays,
                appOwner,
                templateHash
            );
    }

    function deployConsensusDeterministically() internal returns (IConsensus) {
        vm.prank(appOwner);
        return new SimpleConsensus{salt: salt}();
    }

    function deployERC20Deterministically() internal returns (IERC20) {
        vm.prank(tokenOwner);
        return new SimpleERC20{salt: salt}(tokenOwner, initialSupply);
    }

    function deployERC721Deterministically() internal returns (IERC721) {
        vm.prank(tokenOwner);
        return new SimpleERC721{salt: salt}(tokenOwner, tokenId);
    }

    function addVoucher(address destination, bytes memory payload) internal {
        uint256 index = outputEnums.length;
        outputEnums.push(LibServerManager.OutputEnum.VOUCHER);
        vouchers[index] = Voucher(destination, payload);
    }

    function checkInputIndexWithinEpoch(
        uint256 inputIndexWithinEpoch
    ) internal view {
        uint256 length = outputEnums.length;
        if (inputIndexWithinEpoch >= length) {
            revert InputIndexWithinEpochOutOfBounds(
                length,
                inputIndexWithinEpoch
            );
        }
    }

    function checkOutputEnum(
        uint256 inputIndexWithinEpoch,
        LibServerManager.OutputEnum expected
    ) internal view {
        LibServerManager.OutputEnum obtained = outputEnums[
            inputIndexWithinEpoch
        ];
        if (expected != obtained) {
            revert UnexpectedOutputEnum(
                expected,
                obtained,
                inputIndexWithinEpoch
            );
        }
    }

    function getVoucher(
        uint256 inputIndexWithinEpoch
    ) internal view returns (Voucher memory) {
        checkInputIndexWithinEpoch(inputIndexWithinEpoch);
        checkOutputEnum(
            inputIndexWithinEpoch,
            LibServerManager.OutputEnum.VOUCHER
        );
        return vouchers[inputIndexWithinEpoch];
    }

    function getVoucher(
        OutputName _outputName
    ) internal view returns (Voucher memory) {
        return getVoucher(uint256(_outputName));
    }

    function addNotice(bytes memory notice) internal {
        uint256 index = outputEnums.length;
        outputEnums.push(LibServerManager.OutputEnum.NOTICE);
        notices[index] = notice;
    }

    function getNotice(
        uint256 inputIndexWithinEpoch
    ) internal view returns (bytes memory) {
        checkInputIndexWithinEpoch(inputIndexWithinEpoch);
        checkOutputEnum(
            inputIndexWithinEpoch,
            LibServerManager.OutputEnum.NOTICE
        );
        return notices[inputIndexWithinEpoch];
    }

    function getNotice(
        OutputName _outputName
    ) internal view returns (bytes memory) {
        return getNotice(uint256(_outputName));
    }

    function generateOutputs() internal {
        addNotice(abi.encode(bytes4(0xfafafafa)));
        addVoucher(
            address(erc20Token),
            abi.encodeCall(IERC20.transfer, (recipient, transferAmount))
        );
        addVoucher(
            address(app),
            abi.encodeCall(
                Application.withdrawEther,
                (recipient, transferAmount)
            )
        );
        addVoucher(
            address(erc721Token),
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256)",
                app,
                recipient,
                tokenId
            )
        );
    }

    function writeInputs() internal {
        for (uint256 i; i < outputEnums.length; ++i) {
            LibServerManager.OutputEnum outputEnum = outputEnums[i];
            if (outputEnum == LibServerManager.OutputEnum.VOUCHER) {
                Voucher memory voucher = getVoucher(i);
                writeInput(i, voucher.destination, voucher.payload);
            } else {
                bytes memory notice = getNotice(i);
                writeInput(i, noticeSender, notice);
            }
        }
    }

    function getInputPath(
        string memory inputIndexWithinEpochStr
    ) internal view returns (string memory) {
        string memory root = vm.projectRoot();
        return
            string.concat(
                root,
                "/test",
                "/foundry",
                "/dapp",
                "/helper",
                "/input",
                "/",
                inputIndexWithinEpochStr,
                ".json"
            );
    }

    function getInputPath(
        uint256 inputIndexWithinEpoch
    ) internal view returns (string memory) {
        string memory inputIndexWithinEpochStr = vm.toString(
            inputIndexWithinEpoch
        );
        return getInputPath(inputIndexWithinEpochStr);
    }

    function writeInput(
        uint256 inputIndexWithinEpoch,
        address sender,
        bytes memory payload
    ) internal {
        string memory inputIndexWithinEpochStr = vm.toString(
            inputIndexWithinEpoch
        );
        string memory objectKey = string.concat(
            "input",
            inputIndexWithinEpochStr
        );
        vm.serializeAddress(objectKey, "sender", sender);
        string memory json = vm.serializeBytes(objectKey, "payload", payload);
        string memory path = getInputPath(inputIndexWithinEpochStr);
        vm.writeJson(json, path);
    }

    function removeExtraInputs() internal {
        uint256 inputIndexWithinEpoch = outputEnums.length;
        string memory path = getInputPath(inputIndexWithinEpoch);
        while (vm.isFile(path)) {
            vm.removeFile(path);
            path = getInputPath(++inputIndexWithinEpoch);
        }
    }

    function readFinishEpochResponse() internal {
        // Construct path to FinishEpoch response JSON
        string memory root = vm.projectRoot();
        string memory path = string.concat(
            root,
            "/test",
            "/foundry",
            "/dapp",
            "/helper",
            "/output",
            "/finish_epoch_response.json"
        );

        // Require file to be in path
        require(vm.isFile(path), "Please run `yarn proofs:setup`");

        // Read contents of JSON file
        string memory json = vm.readFile(path);

        // Parse JSON into ABI-encoded data
        encodedFinishEpochResponse = vm.parseJson(json);
    }

    function validateNotice(
        bytes memory notice,
        Proof memory proof
    ) internal view {
        app.validateNotice(notice, proof);
    }

    function executeVoucher(
        Voucher memory voucher,
        Proof memory proof
    ) internal {
        app.executeVoucher(voucher.destination, voucher.payload, proof);
    }

    function calculateEpochHash(
        OutputValidityProof memory _validity
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _validity.vouchersEpochRootHash,
                    _validity.noticesEpochRootHash,
                    _validity.machineStateHash
                )
            );
    }

    function setupNoticeProof(
        OutputName _outputName
    ) internal returns (Proof memory) {
        uint256 inputIndexWithinEpoch = uint256(_outputName);
        Proof memory proof = getNoticeProof(inputIndexWithinEpoch);
        mockConsensus(proof);
        return proof;
    }

    function setupVoucherProof(
        OutputName _outputName
    ) internal returns (Proof memory) {
        uint256 inputIndexWithinEpoch = uint256(_outputName);
        Proof memory proof = getVoucherProof(inputIndexWithinEpoch);
        mockConsensus(proof);
        return proof;
    }

    function getNoticeProof(
        uint256 inputIndexWithinEpoch
    ) internal view returns (Proof memory) {
        return
            getProof(
                LibServerManager.OutputEnum.NOTICE,
                inputIndexWithinEpoch,
                0
            );
    }

    function getVoucherProof(
        uint256 inputIndexWithinEpoch
    ) internal view returns (Proof memory) {
        return
            getProof(
                LibServerManager.OutputEnum.VOUCHER,
                inputIndexWithinEpoch,
                0
            );
    }

    function getProof(
        LibServerManager.OutputEnum outputEnum,
        uint256 inputIndexWithinEpoch,
        uint256 outputIndex
    ) internal view returns (Proof memory) {
        // Decode ABI-encoded data into raw struct
        LibServerManager.RawFinishEpochResponse memory raw = abi.decode(
            encodedFinishEpochResponse,
            (LibServerManager.RawFinishEpochResponse)
        );

        // Format raw finish epoch response
        LibServerManager.FinishEpochResponse memory response = raw.fmt(vm);

        // Get the array of proofs
        LibServerManager.Proof[] memory proofs = response.proofs;

        // Calculate input range from the array of proofs
        InputRange memory inputRange = proofs.getInputRange();

        // Find the proof that proves the provided output
        for (uint256 i; i < proofs.length; ++i) {
            LibServerManager.Proof memory proof = proofs[i];
            if (proof.proves(outputEnum, inputIndexWithinEpoch, outputIndex)) {
                return
                    Proof({
                        validity: convert(proof.validity),
                        inputRange: inputRange
                    });
            }
        }

        // If a proof was not found, raise an error
        revert ProofNotFound(outputEnum, inputIndexWithinEpoch);
    }

    function convert(
        LibServerManager.OutputValidityProof memory v
    ) internal pure returns (OutputValidityProof memory) {
        return
            OutputValidityProof({
                inputIndexWithinEpoch: uint64(v.inputIndexWithinEpoch),
                outputIndexWithinInput: uint64(v.outputIndexWithinInput),
                outputHashesRootHash: v.outputHashesRootHash,
                vouchersEpochRootHash: v.vouchersEpochRootHash,
                noticesEpochRootHash: v.noticesEpochRootHash,
                machineStateHash: v.machineStateHash,
                outputHashInOutputHashesSiblings: v
                    .outputHashInOutputHashesSiblings,
                outputHashesInEpochSiblings: v.outputHashesInEpochSiblings
            });
    }

    // Mock the consensus contract so that calls to `getEpochHash` return
    // the epoch hash to be used to validate the proof.
    function mockConsensus(Proof memory _proof) internal {
        vm.mockCall(
            address(consensus),
            abi.encodeCall(
                IConsensus.getEpochHash,
                (address(app), _proof.inputRange)
            ),
            abi.encode(calculateEpochHash(_proof.validity))
        );
    }

    function boundBalance(uint256 _balance) internal view returns (uint256) {
        return bound(_balance, transferAmount, initialSupply);
    }

    function calculateInputIndex(
        Proof calldata _proof
    ) external pure returns (uint256) {
        return _proof.calculateInputIndex();
    }

    function _calculateInputIndex(
        Proof memory _proof
    ) internal view returns (uint256) {
        return this.calculateInputIndex(_proof);
    }
}

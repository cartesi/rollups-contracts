// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Application Test
pragma solidity ^0.8.22;

import {ERC165Test} from "../util/ERC165Test.sol";

import {Application} from "contracts/dapp/Application.sol";
import {IApplication} from "contracts/dapp/IApplication.sol";
import {IConsensus} from "contracts/consensus/IConsensus.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {IInputRelay} from "contracts/inputs/IInputRelay.sol";
import {LibOutputValidityProof} from "contracts/library/LibOutputValidityProof.sol";
import {OutputValidityProof} from "contracts/common/OutputValidityProof.sol";
import {Outputs} from "contracts/common/Outputs.sol";
import {InputRange} from "contracts/common/InputRange.sol";

import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20Errors, IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {LibServerManager} from "../util/LibServerManager.sol";
import {LibBytes} from "../util/LibBytes.sol";
import {SimpleConsensus} from "../util/SimpleConsensus.sol";
import {SimpleERC20} from "../util/SimpleERC20.sol";
import {SimpleERC721} from "../util/SimpleERC721.sol";

import "forge-std/console.sol";

contract ApplicationTest is ERC165Test {
    using LibServerManager for LibServerManager.RawFinishEpochResponse;
    using LibServerManager for LibServerManager.Proof;
    using LibServerManager for LibServerManager.Proof[];
    using LibOutputValidityProof for OutputValidityProof;
    using SafeCast for uint256;

    enum OutputName {
        DummyNotice,
        ERC20TransferVoucher,
        ETHWithdrawalVoucher,
        ERC721TransferVoucher
    }

    struct Voucher {
        address destination;
        uint256 value;
        bytes payload;
    }

    Application _app;
    IConsensus _consensus;
    IERC20 _erc20Token;
    IERC721 _erc721Token;
    IInputRelay[] _inputRelays;
    LibServerManager.OutputEnum[] _outputEnums;
    mapping(uint256 => Voucher) _vouchers;
    mapping(uint256 => bytes) _notices;
    bytes _encodedFinishEpochResponse;
    IInputBox immutable _inputBox;
    address immutable _appOwner;
    address immutable _inputSender;
    address immutable _recipient;
    address immutable _tokenOwner;
    bytes32 immutable _salt;
    bytes32 immutable _templateHash;
    uint256 immutable _initialSupply;
    uint256 immutable _tokenId;
    uint256 immutable _transferAmount;

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

    constructor() {
        _appOwner = LibBytes.hashToAddress("appOwner");
        _initialSupply = LibBytes.hashToUint256("initialSupply");
        _inputBox = IInputBox(LibBytes.hashToAddress("inputBox"));
        _inputSender = LibBytes.hashToAddress("inputSender");
        _recipient = LibBytes.hashToAddress("recipient");
        _salt = keccak256("salt");
        _templateHash = keccak256("templateHash");
        _tokenId = LibBytes.hashToUint256("tokenId");
        _tokenOwner = LibBytes.hashToAddress("tokenOwner");
        _transferAmount =
            LibBytes.hashToUint256("transferAmount") %
            (_initialSupply + 1);
        for (uint256 i; i < 5; ++i) {
            _inputRelays.push(
                IInputRelay(
                    LibBytes.hashToAddress(abi.encode("Input Relays", i))
                )
            );
        }
    }

    function setUp() public {
        _deployContracts();
        _generateOutputs();
        _writeInputs();
        _removeExtraInputs();
        _readFinishEpochResponse();
    }

    function getERC165Contract() public view override returns (IERC165) {
        return _app;
    }

    function getSupportedInterfaces()
        public
        pure
        override
        returns (bytes4[] memory)
    {
        bytes4[] memory interfaceIds = new bytes4[](3);
        interfaceIds[0] = type(IApplication).interfaceId;
        interfaceIds[1] = type(IERC721Receiver).interfaceId;
        interfaceIds[2] = type(IERC1155Receiver).interfaceId;
        return interfaceIds;
    }

    function testConstructorWithOwnerAsZeroAddress(
        IInputBox inputBox,
        IInputRelay[] calldata inputRelays,
        bytes32 templateHash
    ) public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableInvalidOwner.selector,
                address(0)
            )
        );
        new Application(
            _consensus,
            inputBox,
            inputRelays,
            address(0),
            templateHash
        );
    }

    function testConstructor(
        IInputBox inputBox,
        IInputRelay[] calldata inputRelays,
        address owner,
        bytes32 templateHash
    ) public {
        vm.assume(owner != address(0));

        vm.expectEmit(true, true, false, false);
        emit Ownable.OwnershipTransferred(address(0), owner);

        _app = new Application(
            _consensus,
            inputBox,
            inputRelays,
            owner,
            templateHash
        );

        assertEq(address(_app.getConsensus()), address(_consensus));
        assertEq(address(_app.getInputBox()), address(inputBox));
        // abi.encode is used instead of a loop
        assertEq(abi.encode(_app.getInputRelays()), abi.encode(inputRelays));
        assertEq(_app.owner(), owner);
        assertEq(_app.getTemplateHash(), templateHash);
    }

    // test notices

    function testNoticeValidation() public {
        bytes memory notice = _getNotice(OutputName.DummyNotice);
        OutputValidityProof memory proof = _setupNoticeProof(
            OutputName.DummyNotice
        );

        _validateNotice(notice, proof);

        // reverts if notice is incorrect
        bytes memory falseNotice = abi.encodePacked(bytes4(0xdeaddead));
        vm.expectRevert(IApplication.IncorrectOutputHashesRootHash.selector);
        _validateNotice(falseNotice, proof);
    }

    // test vouchers

    function testExecuteVoucherAndEvent(uint256 appInitBalance) public {
        appInitBalance = _boundBalance(appInitBalance);

        Voucher memory voucher = _getVoucher(OutputName.ERC20TransferVoucher);
        OutputValidityProof memory proof = _setupVoucherProof(
            OutputName.ERC20TransferVoucher
        );

        // not able to execute voucher because application has 0 balance
        assertEq(_erc20Token.balanceOf(address(_app)), 0);
        assertEq(_erc20Token.balanceOf(_recipient), 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                address(_app),
                0,
                _transferAmount
            )
        );
        _executeVoucher(voucher, proof);
        assertEq(_erc20Token.balanceOf(address(_app)), 0);
        assertEq(_erc20Token.balanceOf(_recipient), 0);

        // fund application
        vm.prank(_tokenOwner);
        _erc20Token.transfer(address(_app), appInitBalance);
        assertEq(_erc20Token.balanceOf(address(_app)), appInitBalance);
        assertEq(_erc20Token.balanceOf(_recipient), 0);

        // expect event
        vm.expectEmit(false, false, false, true, address(_app));
        emit IApplication.OutputExecuted(
            _calculateInputIndex(proof).toUint64(),
            proof.outputIndexWithinInput,
            _encodeVoucher(voucher)
        );

        // perform call
        _executeVoucher(voucher, proof);

        // check result
        assertEq(
            _erc20Token.balanceOf(address(_app)),
            appInitBalance - _transferAmount
        );
        assertEq(_erc20Token.balanceOf(_recipient), _transferAmount);
    }

    function testRevertsReexecution(uint256 appInitBalance) public {
        appInitBalance = _boundBalance(appInitBalance);

        Voucher memory voucher = _getVoucher(OutputName.ERC20TransferVoucher);
        OutputValidityProof memory proof = _setupVoucherProof(
            OutputName.ERC20TransferVoucher
        );

        // fund application
        vm.prank(_tokenOwner);
        _erc20Token.transfer(address(_app), appInitBalance);

        // 1st execution attempt should succeed
        _executeVoucher(voucher, proof);

        // 2nd execution attempt should fail
        vm.expectRevert(
            abi.encodeWithSelector(
                IApplication.OutputNotReexecutable.selector,
                _encodeVoucher(voucher)
            )
        );
        _executeVoucher(voucher, proof);

        // end result should be the same as executing successfully only once
        assertEq(
            _erc20Token.balanceOf(address(_app)),
            appInitBalance - _transferAmount
        );
        assertEq(_erc20Token.balanceOf(_recipient), _transferAmount);
    }

    function testWasVoucherExecuted(uint256 appInitBalance) public {
        appInitBalance = _boundBalance(appInitBalance);

        Voucher memory voucher = _getVoucher(OutputName.ERC20TransferVoucher);
        OutputValidityProof memory proof = _setupVoucherProof(
            OutputName.ERC20TransferVoucher
        );

        uint256 inputIndex = _calculateInputIndex(proof);

        // before executing voucher
        bool executed = _app.wasOutputExecuted(
            inputIndex,
            proof.outputIndexWithinInput
        );
        assertEq(executed, false);

        // execute voucher - failed
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                address(_app),
                0,
                _transferAmount
            )
        );
        _executeVoucher(voucher, proof);

        // `wasOutputExecuted` should still return false
        executed = _app.wasOutputExecuted(
            inputIndex,
            proof.outputIndexWithinInput
        );
        assertEq(executed, false);

        // execute voucher - succeeded
        vm.prank(_tokenOwner);
        _erc20Token.transfer(address(_app), appInitBalance);
        _executeVoucher(voucher, proof);

        // after executing voucher, `wasOutputExecuted` should return true
        executed = _app.wasOutputExecuted(
            inputIndex,
            proof.outputIndexWithinInput
        );
        assertEq(executed, true);
    }

    function testRevertsEpochHash() public {
        Voucher memory voucher = _getVoucher(OutputName.ERC20TransferVoucher);
        OutputValidityProof memory proof = _setupVoucherProof(
            OutputName.ERC20TransferVoucher
        );

        proof.outputsEpochRootHash = bytes32(uint256(0xdeadbeef));

        vm.expectRevert(IApplication.IncorrectEpochHash.selector);
        _executeVoucher(voucher, proof);
    }

    function testRevertsOutputsEpochRootHash() public {
        Voucher memory voucher = _getVoucher(OutputName.ERC20TransferVoucher);
        OutputValidityProof memory proof = _setupVoucherProof(
            OutputName.ERC20TransferVoucher
        );

        proof.outputHashesRootHash = bytes32(uint256(0xdeadbeef));

        vm.expectRevert(IApplication.IncorrectOutputsEpochRootHash.selector);
        _executeVoucher(voucher, proof);
    }

    function testRevertsOutputHashesRootHash() public {
        Voucher memory voucher = _getVoucher(OutputName.ERC20TransferVoucher);
        OutputValidityProof memory proof = _setupVoucherProof(
            OutputName.ERC20TransferVoucher
        );

        proof.outputIndexWithinInput = 0xdeadbeef;

        vm.expectRevert(IApplication.IncorrectOutputHashesRootHash.selector);
        _executeVoucher(voucher, proof);
    }

    function testRevertsInputIndexOutOfRange() public {
        OutputName outputName = OutputName.ERC20TransferVoucher;
        Voucher memory voucher = _getVoucher(outputName);
        OutputValidityProof memory proof = _getVoucherProof(
            uint256(outputName)
        );
        uint256 inputIndex = _calculateInputIndex(proof);

        // If the input index were 0, then there would be no way for the input index
        // in input box to be out of bounds because every claim is non-empty,
        // as it must contain at least one input
        require(inputIndex >= 1, "cannot test with input index less than 1");

        // Here we change the input range artificially to make it look like it ends
        // before the actual input (which is still provable!).
        // The `Application` contract, however, will not allow such proof.
        proof.inputRange.lastIndex = inputIndex.toUint64() - 1;
        _mockConsensus(proof);

        vm.expectRevert(
            abi.encodeWithSelector(
                IApplication.InputIndexOutOfRange.selector,
                inputIndex,
                proof.inputRange
            )
        );
        _executeVoucher(voucher, proof);
    }

    // test ether transfer

    function testEtherTransfer(uint256 appInitBalance) public {
        appInitBalance = _boundBalance(appInitBalance);

        Voucher memory voucher = _getVoucher(OutputName.ETHWithdrawalVoucher);
        OutputValidityProof memory proof = _setupVoucherProof(
            OutputName.ETHWithdrawalVoucher
        );

        // not able to execute voucher because application has 0 balance
        assertEq(address(_app).balance, 0);
        assertEq(address(_recipient).balance, 0);
        vm.expectRevert();
        _executeVoucher(voucher, proof);
        assertEq(address(_app).balance, 0);
        assertEq(address(_recipient).balance, 0);

        // fund application
        vm.deal(address(_app), appInitBalance);
        assertEq(address(_app).balance, appInitBalance);
        assertEq(address(_recipient).balance, 0);

        // expect event
        vm.expectEmit(false, false, false, true, address(_app));
        emit IApplication.OutputExecuted(
            _calculateInputIndex(proof).toUint64(),
            proof.outputIndexWithinInput,
            _encodeVoucher(voucher)
        );

        // perform call
        _executeVoucher(voucher, proof);

        // check result
        assertEq(address(_app).balance, appInitBalance - _transferAmount);
        assertEq(address(_recipient).balance, _transferAmount);

        // cannot execute the same voucher again
        vm.expectRevert(
            abi.encodeWithSelector(
                IApplication.OutputNotReexecutable.selector,
                _encodeVoucher(voucher)
            )
        );
        _executeVoucher(voucher, proof);
    }

    // test NFT transfer

    function testWithdrawNFT() public {
        Voucher memory voucher = _getVoucher(OutputName.ERC721TransferVoucher);
        OutputValidityProof memory proof = _setupVoucherProof(
            OutputName.ERC721TransferVoucher
        );

        // not able to execute voucher because application doesn't have the nft
        assertEq(_erc721Token.ownerOf(_tokenId), _tokenOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721Errors.ERC721InsufficientApproval.selector,
                address(_app),
                _tokenId
            )
        );
        _executeVoucher(voucher, proof);
        assertEq(_erc721Token.ownerOf(_tokenId), _tokenOwner);

        // fund application
        vm.prank(_tokenOwner);
        _erc721Token.safeTransferFrom(_tokenOwner, address(_app), _tokenId);
        assertEq(_erc721Token.ownerOf(_tokenId), address(_app));

        // expect event
        vm.expectEmit(false, false, false, true, address(_app));
        emit IApplication.OutputExecuted(
            _calculateInputIndex(proof).toUint64(),
            proof.outputIndexWithinInput,
            _encodeVoucher(voucher)
        );

        // perform call
        _executeVoucher(voucher, proof);

        // check result
        assertEq(_erc721Token.ownerOf(_tokenId), _recipient);

        // cannot execute the same voucher again
        vm.expectRevert(
            abi.encodeWithSelector(
                IApplication.OutputNotReexecutable.selector,
                _encodeVoucher(voucher)
            )
        );
        _executeVoucher(voucher, proof);
    }

    // test migration

    function testMigrateToConsensus(
        IInputBox inputBox,
        IInputRelay[] calldata inputRelays,
        address owner,
        bytes32 templateHash,
        address newOwner,
        address nonZeroAddress
    ) public {
        vm.assume(owner != address(0));
        vm.assume(owner != address(this));
        vm.assume(owner != newOwner);
        vm.assume(address(newOwner) != address(0));
        vm.assume(nonZeroAddress != address(0));

        _app = new Application(
            _consensus,
            inputBox,
            inputRelays,
            owner,
            templateHash
        );

        IConsensus newConsensus = new SimpleConsensus();

        // migrate fail if not called from owner
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(this)
            )
        );
        _app.migrateToConsensus(newConsensus);

        // now impersonate owner
        vm.prank(owner);
        vm.expectEmit(false, false, false, true, address(_app));
        emit IApplication.NewConsensus(newConsensus);
        _app.migrateToConsensus(newConsensus);
        assertEq(address(_app.getConsensus()), address(newConsensus));

        // if owner changes, then original owner no longer can migrate consensus
        vm.prank(owner);
        _app.transferOwnership(newOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                owner
            )
        );
        vm.prank(owner);
        _app.migrateToConsensus(_consensus);

        // if new owner renounce ownership (give ownership to address 0)
        // no one will be able to migrate consensus
        vm.prank(newOwner);
        _app.renounceOwnership();
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                nonZeroAddress
            )
        );
        vm.prank(nonZeroAddress);
        _app.migrateToConsensus(_consensus);
    }

    function _deployContracts() internal {
        _consensus = _deployConsensusDeterministically();
        _app = _deployApplicationDeterministically();
        _erc20Token = _deployERC20Deterministically();
        _erc721Token = _deployERC721Deterministically();
    }

    function _deployApplicationDeterministically()
        internal
        returns (Application)
    {
        vm.prank(_appOwner);
        return
            new Application{salt: _salt}(
                _consensus,
                _inputBox,
                _inputRelays,
                _appOwner,
                _templateHash
            );
    }

    function _deployConsensusDeterministically() internal returns (IConsensus) {
        vm.prank(_appOwner);
        return new SimpleConsensus{salt: _salt}();
    }

    function _deployERC20Deterministically() internal returns (IERC20) {
        vm.prank(_tokenOwner);
        return new SimpleERC20{salt: _salt}(_tokenOwner, _initialSupply);
    }

    function _deployERC721Deterministically() internal returns (IERC721) {
        vm.prank(_tokenOwner);
        return new SimpleERC721{salt: _salt}(_tokenOwner, _tokenId);
    }

    function _addVoucher(address destination, bytes memory payload) internal {
        _addVoucher(destination, 0, payload);
    }

    function _addVoucher(
        address destination,
        uint256 value,
        bytes memory payload
    ) internal {
        uint256 index = _outputEnums.length;
        _outputEnums.push(LibServerManager.OutputEnum.VOUCHER);
        _vouchers[index] = Voucher(destination, value, payload);
    }

    function _addNotice(bytes memory notice) internal {
        uint256 index = _outputEnums.length;
        _outputEnums.push(LibServerManager.OutputEnum.NOTICE);
        _notices[index] = notice;
    }

    function _generateOutputs() internal {
        _addNotice(abi.encode(bytes4(0xfafafafa)));
        _addVoucher(
            address(_erc20Token),
            abi.encodeCall(IERC20.transfer, (_recipient, _transferAmount))
        );
        _addVoucher(_recipient, _transferAmount, abi.encode());
        _addVoucher(
            address(_erc721Token),
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256)",
                _app,
                _recipient,
                _tokenId
            )
        );
    }

    function _encodeVoucher(
        Voucher memory voucher
    ) internal pure returns (bytes memory) {
        return
            abi.encodeCall(
                Outputs.Voucher,
                (voucher.destination, voucher.value, voucher.payload)
            );
    }

    function _encodeNotice(
        bytes memory notice
    ) internal pure returns (bytes memory) {
        return abi.encodeCall(Outputs.Notice, (notice));
    }

    function _writeInputs() internal {
        for (uint256 i; i < _outputEnums.length; ++i) {
            LibServerManager.OutputEnum outputEnum = _outputEnums[i];
            if (outputEnum == LibServerManager.OutputEnum.VOUCHER) {
                Voucher memory voucher = _getVoucher(i);
                _writeInput(i, _encodeVoucher(voucher));
            } else {
                bytes memory notice = _getNotice(i);
                _writeInput(i, _encodeNotice(notice));
            }
        }
    }

    function _writeInput(
        uint256 inputIndexWithinEpoch,
        bytes memory payload
    ) internal {
        string memory inputIndexWithinEpochStr = vm.toString(
            inputIndexWithinEpoch
        );
        string memory objectKey = string.concat(
            "input",
            inputIndexWithinEpochStr
        );
        vm.serializeAddress(objectKey, "sender", _inputSender);
        string memory json = vm.serializeBytes(objectKey, "payload", payload);
        string memory path = _getInputPath(inputIndexWithinEpochStr);
        vm.writeJson(json, path);
    }

    function _removeExtraInputs() internal {
        uint256 inputIndexWithinEpoch = _outputEnums.length;
        string memory path = _getInputPath(inputIndexWithinEpoch);
        while (vm.isFile(path)) {
            vm.removeFile(path);
            path = _getInputPath(++inputIndexWithinEpoch);
        }
    }

    function _readFinishEpochResponse() internal {
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
        _encodedFinishEpochResponse = vm.parseJson(json);
    }

    function _setupNoticeProof(
        OutputName outputName
    ) internal returns (OutputValidityProof memory) {
        uint256 inputIndexWithinEpoch = uint256(outputName);
        OutputValidityProof memory proof = _getNoticeProof(
            inputIndexWithinEpoch
        );
        _mockConsensus(proof);
        return proof;
    }

    function _setupVoucherProof(
        OutputName outputName
    ) internal returns (OutputValidityProof memory) {
        uint256 inputIndexWithinEpoch = uint256(outputName);
        OutputValidityProof memory proof = _getNoticeProof(
            inputIndexWithinEpoch
        );
        _mockConsensus(proof);
        return proof;
    }

    function _executeVoucher(
        Voucher memory voucher,
        OutputValidityProof memory proof
    ) internal {
        _app.executeOutput(_encodeVoucher(voucher), proof);
    }

    // Mock the consensus contract so that calls to `getEpochHash` return
    // the epoch hash to be used to validate the proof.
    function _mockConsensus(OutputValidityProof memory proof) internal {
        vm.mockCall(
            address(_consensus),
            abi.encodeCall(
                IConsensus.getEpochHash,
                (address(_app), proof.inputRange)
            ),
            abi.encode(_calculateEpochHash(proof))
        );
    }

    function _checkInputIndexWithinEpoch(
        uint256 inputIndexWithinEpoch
    ) internal view {
        uint256 length = _outputEnums.length;
        if (inputIndexWithinEpoch >= length) {
            revert InputIndexWithinEpochOutOfBounds(
                length,
                inputIndexWithinEpoch
            );
        }
    }

    function _checkOutputEnum(
        uint256 inputIndexWithinEpoch,
        LibServerManager.OutputEnum expected
    ) internal view {
        LibServerManager.OutputEnum obtained = _outputEnums[
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

    function _getVoucher(
        uint256 inputIndexWithinEpoch
    ) internal view returns (Voucher memory) {
        _checkInputIndexWithinEpoch(inputIndexWithinEpoch);
        _checkOutputEnum(
            inputIndexWithinEpoch,
            LibServerManager.OutputEnum.VOUCHER
        );
        return _vouchers[inputIndexWithinEpoch];
    }

    function _getVoucher(
        OutputName _outputName
    ) internal view returns (Voucher memory) {
        return _getVoucher(uint256(_outputName));
    }

    function _getNotice(
        uint256 inputIndexWithinEpoch
    ) internal view returns (bytes memory) {
        _checkInputIndexWithinEpoch(inputIndexWithinEpoch);
        _checkOutputEnum(
            inputIndexWithinEpoch,
            LibServerManager.OutputEnum.NOTICE
        );
        return _notices[inputIndexWithinEpoch];
    }

    function _getNotice(
        OutputName _outputName
    ) internal view returns (bytes memory) {
        return _getNotice(uint256(_outputName));
    }

    function _getInputPath(
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

    function _getInputPath(
        uint256 inputIndexWithinEpoch
    ) internal view returns (string memory) {
        string memory inputIndexWithinEpochStr = vm.toString(
            inputIndexWithinEpoch
        );
        return _getInputPath(inputIndexWithinEpochStr);
    }

    function _validateNotice(
        bytes memory notice,
        OutputValidityProof memory proof
    ) internal view {
        _app.validateOutput(_encodeNotice(notice), proof);
    }

    function _getNoticeProof(
        uint256 inputIndexWithinEpoch
    ) internal view returns (OutputValidityProof memory) {
        return
            _getProof(
                LibServerManager.OutputEnum.NOTICE,
                inputIndexWithinEpoch,
                0
            );
    }

    function _getVoucherProof(
        uint256 inputIndexWithinEpoch
    ) internal view returns (OutputValidityProof memory) {
        return
            _getProof(
                LibServerManager.OutputEnum.VOUCHER,
                inputIndexWithinEpoch,
                0
            );
    }

    function _getProof(
        LibServerManager.OutputEnum outputEnum,
        uint256 inputIndexWithinEpoch,
        uint256 outputIndex
    ) internal view returns (OutputValidityProof memory) {
        // Decode ABI-encoded data into raw struct
        LibServerManager.RawFinishEpochResponse memory raw = abi.decode(
            _encodedFinishEpochResponse,
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
                return _convert(proof.validity, inputRange);
            }
        }

        // If a proof was not found, raise an error
        revert ProofNotFound(outputEnum, inputIndexWithinEpoch);
    }

    function _boundBalance(uint256 balance) internal view returns (uint256) {
        return bound(balance, _transferAmount, _initialSupply);
    }

    function calculateInputIndex(
        OutputValidityProof calldata proof
    ) external pure returns (uint256) {
        return proof.calculateInputIndex();
    }

    function _calculateInputIndex(
        OutputValidityProof memory proof
    ) internal view returns (uint256) {
        return this.calculateInputIndex(proof);
    }

    function _calculateEpochHash(
        OutputValidityProof memory validity
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    validity.outputsEpochRootHash,
                    validity.machineStateHash
                )
            );
    }

    function _convert(
        LibServerManager.OutputValidityProof memory v,
        InputRange memory inputRange
    ) internal pure returns (OutputValidityProof memory) {
        return
            OutputValidityProof({
                inputRange: inputRange,
                inputIndexWithinEpoch: v.inputIndexWithinEpoch.toUint64(),
                outputIndexWithinInput: v.outputIndexWithinInput.toUint64(),
                outputHashesRootHash: v.outputHashesRootHash,
                outputsEpochRootHash: v.noticesEpochRootHash,
                machineStateHash: v.machineStateHash,
                outputHashInOutputHashesSiblings: v
                    .outputHashInOutputHashesSiblings,
                outputHashesInEpochSiblings: v.outputHashesInEpochSiblings
            });
    }
}

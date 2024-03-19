// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Application Test
pragma solidity ^0.8.22;

import {ERC165Test} from "../util/ERC165Test.sol";

import {Authority} from "contracts/consensus/authority/Authority.sol";
import {Application} from "contracts/dapp/Application.sol";
import {IApplication} from "contracts/dapp/IApplication.sol";
import {IConsensus} from "contracts/consensus/IConsensus.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {IPortal} from "contracts/portals/IPortal.sol";
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
import {EtherReceiver} from "../util/EtherReceiver.sol";
import {SimpleERC20} from "../util/SimpleERC20.sol";
import {SimpleERC721} from "../util/SimpleERC721.sol";

import "forge-std/console.sol";

contract ApplicationTest is ERC165Test {
    using LibServerManager for LibServerManager.RawFinishEpochResponse;
    using LibServerManager for LibServerManager.FinishEpochResponse;
    using LibServerManager for LibServerManager.Proof;
    using LibServerManager for LibServerManager.Proof[];
    using LibOutputValidityProof for OutputValidityProof;
    using SafeCast for uint256;

    enum OutputName {
        Empty,
        HelloWorld,
        MyOutput,
        ETHTransfer,
        PayableFunc,
        ERC20Transfer,
        ERC721Transfer
    }

    Application _app;
    IConsensus _consensus;
    EtherReceiver _etherReceiver;
    IERC20 _erc20Token;
    IERC721 _erc721Token;
    IPortal[] _portals;
    bytes[] _outputs;
    bytes _encodedFinishEpochResponse;
    IInputBox immutable _inputBox;
    address immutable _deployer;
    address immutable _authorityOwner;
    address immutable _appOwner;
    address immutable _inputSender;
    address immutable _recipient;
    address immutable _tokenOwner;
    bytes32 immutable _salt;
    bytes32 immutable _templateHash;
    uint256 immutable _initialSupply;
    uint256 immutable _tokenId;
    uint256 immutable _transferAmount;

    error OutputNotFound(uint256 outputIndex);
    error ProofNotFound(uint256 inputIndex, uint256 outputIndex);

    constructor() {
        _deployer = LibBytes.hashToAddress("deployer");
        _authorityOwner = LibBytes.hashToAddress("authorityOwner");
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
            _portals.push(
                IPortal(LibBytes.hashToAddress(abi.encode("Portals", i)))
            );
        }
    }

    function setUp() public {
        _deployContracts();
        _addOutputs();
        _writeInputs();
        _removeExtraInputs();
        _readFinishEpochResponse();
        _submitClaim();
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

    /// @dev Used by the proof generation system
    function testNothing() public pure {}

    function testConstructorWithOwnerAsZeroAddress(
        IInputBox inputBox,
        IPortal[] calldata portals,
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
            portals,
            address(0),
            templateHash
        );
    }

    function testConstructor(
        IInputBox inputBox,
        IPortal[] calldata portals,
        address owner,
        bytes32 templateHash
    ) public {
        vm.assume(owner != address(0));

        vm.expectEmit(true, true, false, false);
        emit Ownable.OwnershipTransferred(address(0), owner);

        _app = new Application(
            _consensus,
            inputBox,
            portals,
            owner,
            templateHash
        );

        assertEq(address(_app.getConsensus()), address(_consensus));
        assertEq(address(_app.getInputBox()), address(inputBox));
        // abi.encode is used instead of a loop
        assertEq(abi.encode(_app.getPortals()), abi.encode(portals));
        assertEq(_app.owner(), owner);
        assertEq(_app.getTemplateHash(), templateHash);
    }

    // test output validation

    function testOutputValidation() public {
        for (uint256 i; i < _outputs.length; ++i) {
            _testOutputValidation(i);
        }
    }

    // test output execution

    function testExecuteVoucherAndEvent(uint256 appInitBalance) public {
        appInitBalance = _boundBalance(appInitBalance);

        bytes memory output = _getOutput(OutputName.ERC20Transfer);
        OutputValidityProof memory proof = _getProof(OutputName.ERC20Transfer);

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
        _app.executeOutput(output, proof);
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
            proof.inputIndexWithinEpoch,
            proof.outputIndexWithinInput,
            output
        );

        // perform call
        _app.executeOutput(output, proof);

        // check result
        assertEq(
            _erc20Token.balanceOf(address(_app)),
            appInitBalance - _transferAmount
        );
        assertEq(_erc20Token.balanceOf(_recipient), _transferAmount);
    }

    function testRevertsReexecution(uint256 appInitBalance) public {
        appInitBalance = _boundBalance(appInitBalance);

        bytes memory output = _getOutput(OutputName.ERC20Transfer);
        OutputValidityProof memory proof = _getProof(OutputName.ERC20Transfer);

        // fund application
        vm.prank(_tokenOwner);
        _erc20Token.transfer(address(_app), appInitBalance);

        // 1st execution attempt should succeed
        _app.executeOutput(output, proof);

        // 2nd execution attempt should fail
        vm.expectRevert(
            abi.encodeWithSelector(
                IApplication.OutputNotReexecutable.selector,
                output
            )
        );
        _app.executeOutput(output, proof);

        // end result should be the same as executing successfully only once
        assertEq(
            _erc20Token.balanceOf(address(_app)),
            appInitBalance - _transferAmount
        );
        assertEq(_erc20Token.balanceOf(_recipient), _transferAmount);
    }

    function testWasVoucherExecuted(uint256 appInitBalance) public {
        appInitBalance = _boundBalance(appInitBalance);

        bytes memory output = _getOutput(OutputName.ERC20Transfer);
        OutputValidityProof memory proof = _getProof(OutputName.ERC20Transfer);

        // before executing voucher
        bool executed = _app.wasOutputExecuted(
            proof.inputIndexWithinEpoch,
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
        _app.executeOutput(output, proof);

        // `wasOutputExecuted` should still return false
        executed = _app.wasOutputExecuted(
            proof.inputIndexWithinEpoch,
            proof.outputIndexWithinInput
        );
        assertEq(executed, false);

        // execute voucher - succeeded
        vm.prank(_tokenOwner);
        _erc20Token.transfer(address(_app), appInitBalance);
        _app.executeOutput(output, proof);

        // after executing voucher, `wasOutputExecuted` should return true
        executed = _app.wasOutputExecuted(
            proof.inputIndexWithinEpoch,
            proof.outputIndexWithinInput
        );
        assertEq(executed, true);
    }

    function testRevertsEpochHash() public {
        bytes memory output = _getOutput(OutputName.ERC20Transfer);
        OutputValidityProof memory proof = _getProof(OutputName.ERC20Transfer);

        proof.outputsEpochRootHash = bytes32(uint256(0xdeadbeef));

        vm.expectRevert(IApplication.IncorrectEpochHash.selector);
        _app.executeOutput(output, proof);
    }

    function testRevertsOutputsEpochRootHash() public {
        bytes memory output = _getOutput(OutputName.ERC20Transfer);
        OutputValidityProof memory proof = _getProof(OutputName.ERC20Transfer);

        proof.outputHashesRootHash = bytes32(uint256(0xdeadbeef));

        vm.expectRevert(IApplication.IncorrectOutputsEpochRootHash.selector);
        _app.executeOutput(output, proof);
    }

    function testRevertsOutputHashesRootHash() public {
        bytes memory output = _getOutput(OutputName.ERC20Transfer);
        OutputValidityProof memory proof = _getProof(OutputName.ERC20Transfer);

        proof.outputIndexWithinInput = 0xdeadbeef;

        vm.expectRevert(IApplication.IncorrectOutputHashesRootHash.selector);
        _app.executeOutput(output, proof);
    }

    function testRevertsInputIndexOutOfRange() public {
        OutputName outputName = OutputName.ERC20Transfer;
        bytes memory output = _getOutput(outputName);
        OutputValidityProof memory proof = _getProof(outputName);
        uint256 inputIndex = proof.inputIndexWithinEpoch;

        // If the input index were 0, then there would be no way for the input index
        // in input box to be out of bounds because every claim is non-empty,
        // as it must contain at least one input
        require(inputIndex >= 1, "cannot test with input index less than 1");

        // First we get the epoch hash for the app and input range
        bytes32 epochHash = _consensus.getEpochHash(
            address(_app),
            proof.inputRange
        );

        // Then, we change the input range artificially to make it look like it ends
        // before the actual input (which is still provable!).
        // The `Application` contract, however, will not allow such proof.
        proof.inputRange.lastIndex = uint64(inputIndex) - 1;

        // Finally, we submit the same epoch hash but for the modified input range
        _submitClaim(proof.inputRange, epochHash);

        vm.expectRevert(
            abi.encodeWithSelector(
                IApplication.InputIndexOutOfRange.selector,
                inputIndex,
                proof.inputRange
            )
        );
        _app.executeOutput(output, proof);
    }

    function testEtherTransfer(uint256 appInitBalance) public {
        appInitBalance = _boundBalance(appInitBalance);

        bytes memory output = _getOutput(OutputName.ETHTransfer);
        OutputValidityProof memory proof = _getProof(OutputName.ETHTransfer);

        // not able to execute voucher because application has 0 balance
        assertEq(address(_app).balance, 0);
        assertEq(address(_recipient).balance, 0);
        vm.expectRevert();
        _app.executeOutput(output, proof);
        assertEq(address(_app).balance, 0);
        assertEq(address(_recipient).balance, 0);

        // fund application
        vm.deal(address(_app), appInitBalance);
        assertEq(address(_app).balance, appInitBalance);
        assertEq(address(_recipient).balance, 0);

        // expect event
        vm.expectEmit(false, false, false, true, address(_app));
        emit IApplication.OutputExecuted(
            proof.inputIndexWithinEpoch,
            proof.outputIndexWithinInput,
            output
        );

        // perform call
        _app.executeOutput(output, proof);

        // check result
        assertEq(address(_app).balance, appInitBalance - _transferAmount);
        assertEq(address(_recipient).balance, _transferAmount);

        // cannot execute the same voucher again
        vm.expectRevert(
            abi.encodeWithSelector(
                IApplication.OutputNotReexecutable.selector,
                output
            )
        );
        _app.executeOutput(output, proof);
    }

    function testWithdrawNFT() public {
        bytes memory output = _getOutput(OutputName.ERC721Transfer);
        OutputValidityProof memory proof = _getProof(OutputName.ERC721Transfer);

        // not able to execute voucher because application doesn't have the nft
        assertEq(_erc721Token.ownerOf(_tokenId), _tokenOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721Errors.ERC721InsufficientApproval.selector,
                address(_app),
                _tokenId
            )
        );
        _app.executeOutput(output, proof);
        assertEq(_erc721Token.ownerOf(_tokenId), _tokenOwner);

        // fund application
        vm.prank(_tokenOwner);
        _erc721Token.safeTransferFrom(_tokenOwner, address(_app), _tokenId);
        assertEq(_erc721Token.ownerOf(_tokenId), address(_app));

        // expect event
        vm.expectEmit(false, false, false, true, address(_app));
        emit IApplication.OutputExecuted(
            proof.inputIndexWithinEpoch,
            proof.outputIndexWithinInput,
            output
        );

        // perform call
        _app.executeOutput(output, proof);

        // check result
        assertEq(_erc721Token.ownerOf(_tokenId), _recipient);

        // cannot execute the same voucher again
        vm.expectRevert(
            abi.encodeWithSelector(
                IApplication.OutputNotReexecutable.selector,
                output
            )
        );
        _app.executeOutput(output, proof);
    }

    function testPayableFunctionCall(uint256 appInitBalance) public {
        appInitBalance = _boundBalance(appInitBalance);

        bytes memory output = _getOutput(OutputName.PayableFunc);
        OutputValidityProof memory proof = _getProof(OutputName.PayableFunc);

        assertEq(_etherReceiver.balanceOf(address(_app)), 0);
        assertEq(address(_app).balance, 0);

        vm.expectRevert();
        _app.executeOutput(output, proof);

        vm.deal(address(_app), appInitBalance);

        assertEq(_etherReceiver.balanceOf(address(_app)), 0);
        assertEq(address(_app).balance, appInitBalance);

        _app.executeOutput(output, proof);

        assertEq(_etherReceiver.balanceOf(address(_app)), _transferAmount);
        assertEq(address(_app).balance, appInitBalance - _transferAmount);
    }

    // test non-executable outputs

    function testExecuteEmptyOutput() public {
        _testOutputNotExecutable(OutputName.Empty);
    }

    function testExecuteNotice() public {
        _testOutputNotExecutable(OutputName.HelloWorld);
    }

    function testExecuteNewTypeOfOutput() public {
        _testOutputNotExecutable(OutputName.MyOutput);
    }

    // test migration

    function testMigrateToConsensus(
        IInputBox inputBox,
        IPortal[] calldata portals,
        IConsensus newConsensus,
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
            portals,
            owner,
            templateHash
        );

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

    function _getOutput(
        OutputName outputName
    ) internal view returns (bytes memory) {
        return _getOutput(uint256(outputName));
    }

    function _getOutput(
        uint256 inputIndex
    ) internal view returns (bytes memory) {
        if (inputIndex < _outputs.length) {
            return _outputs[inputIndex];
        } else {
            revert OutputNotFound(inputIndex);
        }
    }

    function _deployContracts() internal {
        _consensus = _deployConsensusDeterministically();
        _app = _deployApplicationDeterministically();
        _etherReceiver = _deployEtherReceiverDeterministically();
        _erc20Token = _deployERC20Deterministically();
        _erc721Token = _deployERC721Deterministically();
    }

    function _deployApplicationDeterministically()
        internal
        returns (Application)
    {
        vm.prank(_deployer);
        return
            new Application{salt: _salt}(
                _consensus,
                _inputBox,
                _portals,
                _appOwner,
                _templateHash
            );
    }

    function _deployConsensusDeterministically() internal returns (IConsensus) {
        vm.prank(_deployer);
        return new Authority{salt: _salt}(_authorityOwner);
    }

    function _deployEtherReceiverDeterministically()
        internal
        returns (EtherReceiver)
    {
        vm.prank(_deployer);
        return new EtherReceiver{salt: _salt}();
    }

    function _deployERC20Deterministically() internal returns (IERC20) {
        vm.prank(_deployer);
        return new SimpleERC20{salt: _salt}(_tokenOwner, _initialSupply);
    }

    function _deployERC721Deterministically() internal returns (IERC721) {
        vm.prank(_deployer);
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
        _addOutput(
            abi.encodeCall(Outputs.Voucher, (destination, value, payload))
        );
    }

    function _addNotice(bytes memory payload) internal {
        _addOutput(abi.encodeCall(Outputs.Notice, (payload)));
    }

    function _addOutput(bytes memory output) internal {
        _outputs.push(output);
    }

    function _addOutputs() internal {
        _addOutput(abi.encode());
        _addNotice("Hello, world!");
        _addOutput(abi.encodeWithSignature("MyOutput()"));
        _addVoucher(_recipient, _transferAmount, abi.encode());
        _addVoucher(
            address(_etherReceiver),
            _transferAmount,
            abi.encodeCall(EtherReceiver.mint, ())
        );
        _addVoucher(
            address(_erc20Token),
            abi.encodeCall(IERC20.transfer, (_recipient, _transferAmount))
        );
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

    function _writeInputs() internal {
        // The ioctl-echo-loop program receives inputs
        // and echoes them back as outputs.
        for (uint256 i; i < _outputs.length; ++i) {
            _writeInput(i, _outputs[i]);
        }
    }

    function _writeInput(uint256 inputIndex, bytes memory payload) internal {
        string memory inputIndexWithinEpochStr = vm.toString(inputIndex);
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
        uint256 inputIndex = _outputs.length;
        string memory path = _getInputPath(inputIndex);
        while (vm.isFile(path)) {
            vm.removeFile(path);
            path = _getInputPath(++inputIndex);
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
        require(vm.isFile(path), "Please run `pnpm proofs:setup`");

        // Read contents of JSON file
        string memory json = vm.readFile(path);

        // Parse JSON into ABI-encoded data
        _encodedFinishEpochResponse = vm.parseJson(json);
    }

    function _submitClaim() internal {
        LibServerManager.FinishEpochResponse memory response;
        InputRange memory inputRange;
        bytes32 epochHash;

        response = _getFinishEpochResponse();
        inputRange = response.proofs.getInputRange();
        epochHash = response.getEpochHash();

        _submitClaim(inputRange, epochHash);
    }

    function _submitClaim(
        InputRange memory inputRange,
        bytes32 epochHash
    ) internal {
        vm.prank(_authorityOwner);
        _consensus.submitClaim(address(_app), inputRange, epochHash);
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
        uint256 inputIndex
    ) internal view returns (string memory) {
        return _getInputPath(vm.toString(inputIndex));
    }

    function _getProof(
        OutputName outputName
    ) internal view returns (OutputValidityProof memory) {
        return _getProof(uint256(outputName));
    }

    function _getProof(
        uint256 inputIndex
    ) internal view returns (OutputValidityProof memory) {
        return _getProof(inputIndex, 0);
    }

    function _getFinishEpochResponse()
        internal
        view
        returns (LibServerManager.FinishEpochResponse memory)
    {
        LibServerManager.RawFinishEpochResponse memory rawFinishEpochResponse;

        rawFinishEpochResponse = abi.decode(
            _encodedFinishEpochResponse,
            (LibServerManager.RawFinishEpochResponse)
        );

        return rawFinishEpochResponse.fmt(vm);
    }

    function _getProof(
        uint256 inputIndex,
        uint256 outputIndex
    ) internal view returns (OutputValidityProof memory) {
        LibServerManager.Proof[] memory proofs;
        InputRange memory inputRange;

        proofs = _getFinishEpochResponse().proofs;
        inputRange = proofs.getInputRange();

        for (uint256 i; i < proofs.length; ++i) {
            LibServerManager.Proof memory proof = proofs[i];
            if (proof.proves(inputIndex, outputIndex)) {
                return _convert(proof.validity, inputRange);
            }
        }

        revert ProofNotFound(inputIndex, outputIndex);
    }

    function _boundBalance(uint256 balance) internal view returns (uint256) {
        return bound(balance, _transferAmount, _initialSupply);
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

    function _testOutputValidation(uint256 inputIndex) internal {
        bytes memory output = _getOutput(inputIndex);
        OutputValidityProof memory proof = _getProof(inputIndex);

        _app.validateOutput(output, proof);

        // to test a different output, we give two options
        // it is evident that the output cannot be equal to both

        bytes memory otherOutput;
        bytes memory option1 = bytes("deadbeef");
        bytes memory option2 = bytes("beefdead");

        if (keccak256(output) == keccak256(option1)) {
            otherOutput = option2;
        } else {
            otherOutput = option1;
        }

        vm.expectRevert(IApplication.IncorrectOutputHashesRootHash.selector);
        _app.validateOutput(otherOutput, proof);
    }

    function _testOutputNotExecutable(OutputName outputName) internal {
        bytes memory output = _getOutput(outputName);
        OutputValidityProof memory proof = _getProof(outputName);

        vm.expectRevert(
            abi.encodeWithSelector(
                IApplication.OutputNotExecutable.selector,
                output
            )
        );

        _app.executeOutput(output, proof);
    }
}

// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Application} from "contracts/dapp/Application.sol";
import {Authority} from "contracts/consensus/authority/Authority.sol";
import {CanonicalMachine} from "contracts/common/CanonicalMachine.sol";
import {ERC1155BatchPortal} from "contracts/portals/ERC1155BatchPortal.sol";
import {ERC1155SinglePortal} from "contracts/portals/ERC1155SinglePortal.sol";
import {ERC20Portal} from "contracts/portals/ERC20Portal.sol";
import {ERC721Portal} from "contracts/portals/ERC721Portal.sol";
import {EtherPortal} from "contracts/portals/EtherPortal.sol";
import {IApplication} from "contracts/dapp/IApplication.sol";
import {IConsensus} from "contracts/consensus/IConsensus.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {IPortal} from "contracts/portals/IPortal.sol";
import {InputBox} from "contracts/inputs/InputBox.sol";
import {InputRange} from "contracts/common/InputRange.sol";
import {OutputValidityProof} from "contracts/common/OutputValidityProof.sol";
import {Outputs} from "contracts/common/Outputs.sol";
import {SafeERC20Transfer} from "contracts/delegatecall/SafeERC20Transfer.sol";
import {AssetTransferToENS} from "contracts/delegatecall/AssetTransferToENS.sol";

import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Errors, IERC721Errors, IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import {AddrResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/AddrResolver.sol";

import {ERC165Test} from "../util/ERC165Test.sol";
import {EtherReceiver} from "../util/EtherReceiver.sol";
import {LibEmulator} from "../util/LibEmulator.sol";
import {SimpleERC20} from "../util/SimpleERC20.sol";
import {SimpleERC721} from "../util/SimpleERC721.sol";
import {SimpleSingleERC1155, SimpleBatchERC1155} from "../util/SimpleERC1155.sol";
import {ExternalLibMerkle32} from "../library/LibMerkle32.t.sol";

contract ApplicationTest is ERC165Test {
    using LibEmulator for LibEmulator.State;
    using ExternalLibMerkle32 for bytes32[];

    Application _appContract;
    EtherReceiver _etherReceiver;
    IConsensus _consensus;
    IERC20 _erc20Token;
    IERC721 _erc721Token;
    IERC1155 _erc1155SingleToken;
    IERC1155 _erc1155BatchToken;
    IInputBox _inputBox;
    IPortal[] _portals;
    SafeERC20Transfer _safeERC20Transfer;
    AssetTransferToENS _assetTransferToENS;
    ENS _ens;
    AddrResolver _resolver;

    LibEmulator.State _emulator;
    address _appOwner;
    address _authorityOwner;
    address _recipient;
    address _tokenOwner;
    string[] _outputNames;
    bytes4[] _interfaceIds;
    uint256[] _tokenIds;
    uint256[] _initialSupplies;
    uint256[] _transferAmounts;
    mapping(string => LibEmulator.OutputId) _outputIdsByName;

    bytes32 constant _templateHash = keccak256("templateHash");
    uint256 constant _initialSupply = 1000000000000000000000000000000000000;
    uint256 constant _tokenId = 88888888;
    uint256 constant _transferAmount = 42;
    bytes32 constant _ensNode = keccak256("user.eth");

    function setUp() public {
        _initVariables();
        _deployContracts();
        _addOutputs();
        _submitClaims();
        _mockENS();
    }

    // -----------
    // constructor
    // -----------

    function testConstructorRevertsInvalidOwner() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableInvalidOwner.selector,
                address(0)
            )
        );
        new Application(
            _consensus,
            _inputBox,
            _portals,
            address(0),
            _templateHash
        );
    }

    function testConstructor(
        IConsensus consensus,
        IInputBox inputBox,
        IPortal[] calldata portals,
        address owner,
        bytes32 templateHash
    ) external {
        vm.assume(owner != address(0));

        vm.expectEmit(true, true, false, false);
        emit Ownable.OwnershipTransferred(address(0), owner);

        Application appContract = new Application(
            consensus,
            inputBox,
            portals,
            owner,
            templateHash
        );

        assertEq(address(appContract.getConsensus()), address(consensus));
        assertEq(address(appContract.getInputBox()), address(inputBox));
        assertEq(appContract.owner(), owner);
        assertEq(appContract.getTemplateHash(), templateHash);
        assertEq(appContract.getPortals(), portals);
    }

    // -------------------
    // consensus migration
    // -------------------

    function testMigrateToConsensusRevertsUnauthorized(
        address caller,
        IConsensus newConsensus
    ) external {
        vm.assume(caller != _appOwner);
        vm.startPrank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                caller
            )
        );
        _appContract.migrateToConsensus(newConsensus);
    }

    function testMigrateToConsensus(IConsensus newConsensus) external {
        vm.prank(_appOwner);
        vm.expectEmit(false, false, false, true, address(_appContract));
        emit IApplication.NewConsensus(newConsensus);
        _appContract.migrateToConsensus(newConsensus);
        assertEq(address(_appContract.getConsensus()), address(newConsensus));
    }

    // -----------------
    // output validation
    // -----------------

    function testValidateOutput() external view {
        for (uint256 i; i < _outputNames.length; ++i) {
            string memory name = _outputNames[i];
            bytes memory output = _getOutput(name);
            OutputValidityProof memory proof = _getProof(name);
            _appContract.validateOutput(output, proof);
        }
    }

    function testValidateFakeOutput() external {
        string memory name = "HelloWorldNotice";
        OutputValidityProof memory proof = _getProof(name);

        bytes memory fakeOutput = _encodeNotice("Goodbye, World!");

        vm.expectRevert(IApplication.IncorrectOutputHashesRootHash.selector);
        _appContract.validateOutput(fakeOutput, proof);

        proof.outputHashesRootHash = proof
            .outputHashInOutputHashesSiblings
            .merkleRootAfterReplacement(
                proof.outputIndexWithinInput,
                keccak256(fakeOutput)
            );

        vm.expectRevert(IApplication.IncorrectOutputsEpochRootHash.selector);
        _appContract.validateOutput(fakeOutput, proof);

        proof.outputsEpochRootHash = proof
            .outputHashesInEpochSiblings
            .merkleRootAfterReplacement(
                proof.inputIndexWithinEpoch,
                proof.outputHashesRootHash
            );

        vm.expectRevert(IApplication.IncorrectEpochHash.selector);
        _appContract.validateOutput(fakeOutput, proof);
    }

    // ----------------
    // output execution
    // ----------------

    function testWasOutputExecuted(
        uint256 inputIndex,
        uint256 outputIndexWithinInput
    ) external view {
        assertFalse(
            _appContract.wasOutputExecuted(inputIndex, outputIndexWithinInput)
        );
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

        assertTrue(
            _wasOutputExecuted(proof),
            "Output should be marked as executed"
        );

        _expectRevertOutputNotReexecutable(output);
        _appContract.executeOutput(output, proof);
    }

    function testExecuteERC721TransferVoucher() external {
        string memory name = "ERC721TransferVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getProof(name);

        _testERC721Transfer(output, proof);
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

    function testEtherTransferToENS() external {
        string memory name = "EtherToENSDelegateCallVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getProof(name);

        _testEtherTransfer(output, proof);
    }

    function testEtherTransferWithPayloadToENS() external {
        string memory name = "EtherWithPayloadToENSDelegateCallVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getProof(name);

        vm.mockCall(
            address(_resolver),
            abi.encodeWithSignature("addr(bytes32)", (_ensNode)),
            abi.encode(address(_etherReceiver))
        );

        _testEtherMint(output, proof);
    }

    function testERC20TransferToENSFail() external {
        string memory name = "ERC20ToENSDelegateCallVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getProof(name);

        _testERC20Fail(output, proof);
    }

    function testERC20TransferToENSSuccess() external {
        string memory name = "ERC20ToENSDelegateCallVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getProof(name);

        _testERC20Success(output, proof);
    }

    function testERC721TransferToENS() external {
        string memory name = "ERC721ToENSDelegateCallVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getProof(name);

        _testERC721Transfer(output, proof);
    }

    function testERC1155SingleTransferToENS() external {
        string memory name = "ERC1155SingleToENSDelegateCallVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getProof(name);

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

        vm.prank(_tokenOwner);
        _erc1155SingleToken.safeTransferFrom(
            _tokenOwner,
            address(_appContract),
            _tokenId,
            _initialSupply,
            ""
        );

        uint256 recipientBalance = _erc1155SingleToken.balanceOf(
            _recipient,
            _tokenId
        );
        uint256 appBalance = _erc1155SingleToken.balanceOf(
            address(_appContract),
            _tokenId
        );

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

        assertTrue(
            _wasOutputExecuted(proof),
            "Output should be marked as executed"
        );

        _expectRevertOutputNotReexecutable(output);
        _appContract.executeOutput(output, proof);
    }

    function testERC1155BatchTransferToENS() external {
        string memory name = "ERC1155BatchToENSDelegateCallVoucher";
        bytes memory output = _getOutput(name);
        OutputValidityProof memory proof = _getProof(name);

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

        vm.prank(_tokenOwner);
        _erc1155BatchToken.safeBatchTransferFrom(
            _tokenOwner,
            address(_appContract),
            _tokenIds,
            _initialSupplies,
            ""
        );

        uint256 batchLength = _initialSupplies.length;
        uint256[] memory appBalances = new uint256[](batchLength);
        uint256[] memory recipientBalances = new uint256[](batchLength);
        for (uint256 i; i < batchLength; ++i) {
            appBalances[i] = _erc1155BatchToken.balanceOf(
                address(_appContract),
                _tokenIds[i]
            );
            recipientBalances[i] = _erc1155BatchToken.balanceOf(
                _recipient,
                _tokenIds[i]
            );
        }

        _expectEmitOutputExecuted(output, proof);
        _appContract.executeOutput(output, proof);

        for (uint256 i; i < _tokenIds.length; ++i) {
            assertEq(
                _erc1155BatchToken.balanceOf(
                    address(_appContract),
                    _tokenIds[i]
                ),
                appBalances[i] - _transferAmounts[i],
                "Application contract should have the transfer amount deducted"
            );
            assertEq(
                _erc1155BatchToken.balanceOf(_recipient, _tokenIds[i]),
                recipientBalances[i] + _transferAmounts[i],
                "Recipient should have received the transfer amount"
            );
        }

        assertTrue(
            _wasOutputExecuted(proof),
            "Output should be marked as executed"
        );

        _expectRevertOutputNotReexecutable(output);
        _appContract.executeOutput(output, proof);
    }

    // -------
    // ERC-165
    // -------

    function getERC165Contract() public view override returns (IERC165) {
        return _appContract;
    }

    function getSupportedInterfaces()
        public
        view
        override
        returns (bytes4[] memory)
    {
        return _interfaceIds;
    }

    // ------------------
    // internal functions
    // ------------------

    function _initVariables() internal {
        _authorityOwner = _newAddr();
        _appOwner = _newAddr();
        _recipient = _newAddr();
        _tokenOwner = _newAddr();
        _ens = ENS(_newAddr());
        _resolver = AddrResolver(_newAddr());
        _interfaceIds.push(type(IApplication).interfaceId);
        _interfaceIds.push(type(IERC721Receiver).interfaceId);
        _interfaceIds.push(type(IERC1155Receiver).interfaceId);
        for (uint256 i; i < 7; ++i) {
            _tokenIds.push(i);
            _initialSupplies.push(_initialSupply);
            _transferAmounts.push(
                bound(uint256(keccak256(abi.encode(i))), 1, _initialSupply)
            );
        }
    }

    function _deployContracts() internal {
        _etherReceiver = new EtherReceiver();
        _erc20Token = new SimpleERC20(_tokenOwner, _initialSupply);
        _erc721Token = new SimpleERC721(_tokenOwner, _tokenId);
        _erc1155SingleToken = new SimpleSingleERC1155(
            _tokenOwner,
            _tokenId,
            _initialSupply
        );
        _erc1155BatchToken = new SimpleBatchERC1155(
            _tokenOwner,
            _tokenIds,
            _initialSupplies
        );
        _inputBox = new InputBox();
        _portals.push(new EtherPortal(_inputBox));
        _portals.push(new ERC20Portal(_inputBox));
        _portals.push(new ERC721Portal(_inputBox));
        _portals.push(new ERC1155SinglePortal(_inputBox));
        _portals.push(new ERC1155BatchPortal(_inputBox));
        _consensus = new Authority(_authorityOwner);
        _appContract = new Application(
            _consensus,
            _inputBox,
            _portals,
            _appOwner,
            _templateHash
        );
        _safeERC20Transfer = new SafeERC20Transfer();
        _assetTransferToENS = new AssetTransferToENS(_ens);
    }

    function _addOutputs() internal {
        _nameOutput("EmptyOutput", _addOutput(abi.encode()));
        _nameOutput(
            "HelloWorldNotice",
            _addOutput(_encodeNotice("Hello, world!"))
        );
        _finishInput();

        _nameOutput(
            "MyOutput",
            _addOutput(abi.encodeWithSignature("MyOutput()"))
        );
        _finishInput();
        _finishEpoch();

        _nameOutput(
            "EtherTransferVoucher",
            _addOutput(
                _encodeVoucher(_recipient, _transferAmount, abi.encode())
            )
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
        _finishInput();
        _finishEpoch();

        _nameOutput(
            "ERC20TransferVoucher",
            _addOutput(
                _encodeVoucher(
                    address(_erc20Token),
                    0,
                    abi.encodeCall(
                        IERC20.transfer,
                        (_recipient, _transferAmount)
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
                        _appContract,
                        _recipient,
                        _tokenId
                    )
                )
            )
        );
        _finishInput();
        _finishEpoch();

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
        _finishInput();
        _finishEpoch();

        _nameOutput(
            "EtherToENSDelegateCallVoucher",
            _addOutput(
                _encodeDelegateCallVoucher(
                    address(_assetTransferToENS),
                    abi.encodeCall(
                        AssetTransferToENS.sendEtherToENS,
                        (_ensNode, _transferAmount, "")
                    )
                )
            )
        );
        _nameOutput(
            "EtherWithPayloadToENSDelegateCallVoucher",
            _addOutput(
                _encodeDelegateCallVoucher(
                    address(_assetTransferToENS),
                    abi.encodeCall(
                        AssetTransferToENS.sendEtherToENS,
                        (
                            _ensNode,
                            _transferAmount,
                            abi.encodeCall(EtherReceiver.mint, ())
                        )
                    )
                )
            )
        );
        _nameOutput(
            "ERC20ToENSDelegateCallVoucher",
            _addOutput(
                _encodeDelegateCallVoucher(
                    address(_assetTransferToENS),
                    abi.encodeCall(
                        AssetTransferToENS.sendERC20ToENS,
                        (_erc20Token, _ensNode, _transferAmount)
                    )
                )
            )
        );
        _nameOutput(
            "ERC721ToENSDelegateCallVoucher",
            _addOutput(
                _encodeDelegateCallVoucher(
                    address(_assetTransferToENS),
                    abi.encodeCall(
                        AssetTransferToENS.sendERC721ToENS,
                        (_erc721Token, _ensNode, _tokenId, "")
                    )
                )
            )
        );
        _nameOutput(
            "ERC1155SingleToENSDelegateCallVoucher",
            _addOutput(
                _encodeDelegateCallVoucher(
                    address(_assetTransferToENS),
                    abi.encodeCall(
                        AssetTransferToENS.sendERC1155ToENS,
                        (
                            _erc1155SingleToken,
                            _ensNode,
                            _tokenId,
                            _transferAmount,
                            ""
                        )
                    )
                )
            )
        );
        _nameOutput(
            "ERC1155BatchToENSDelegateCallVoucher",
            _addOutput(
                _encodeDelegateCallVoucher(
                    address(_assetTransferToENS),
                    abi.encodeCall(
                        AssetTransferToENS.sendBatchERC1155ToENS,
                        (
                            _erc1155BatchToken,
                            _ensNode,
                            _tokenIds,
                            _transferAmounts,
                            ""
                        )
                    )
                )
            )
        );
        _finishInput();
        _finishEpoch();

        // Test input with no outputs
        _finishInput();
        _finishEpoch();
    }

    function _encodeNotice(
        bytes memory payload
    ) internal pure returns (bytes memory) {
        return abi.encodeCall(Outputs.Notice, (payload));
    }

    function _encodeVoucher(
        address destination,
        uint256 value,
        bytes memory payload
    ) internal pure returns (bytes memory) {
        return abi.encodeCall(Outputs.Voucher, (destination, value, payload));
    }

    function _encodeDelegateCallVoucher(
        address destination,
        bytes memory payload
    ) internal pure returns (bytes memory) {
        return
            abi.encodeCall(Outputs.DelegateCallVoucher, (destination, payload));
    }

    function _addOutput(
        bytes memory output
    ) internal returns (LibEmulator.OutputId memory) {
        return _emulator.addOutput(output);
    }

    function _nameOutput(
        string memory name,
        LibEmulator.OutputId memory oid
    ) internal {
        _outputIdsByName[name] = oid;
        _outputNames.push(name);
    }

    function _getOutput(
        string memory name
    ) internal view returns (bytes storage) {
        return _emulator.getOutput(_outputIdsByName[name]);
    }

    function _getProof(
        string memory name
    ) internal view returns (OutputValidityProof memory) {
        return _emulator.getOutputValidityProof(_outputIdsByName[name]);
    }

    function _finishInput() internal {
        _emulator.finishInput();
    }

    function _finishEpoch() internal {
        _emulator.finishEpoch(_getMachineStateHash(_emulator.epochCount));
    }

    function _getMachineStateHash(
        uint256 epochIndex
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode("machineStateHash", epochIndex));
    }

    function _submitClaims() internal {
        uint256 epochCount = _emulator.epochCount;
        for (uint256 epochIndex; epochIndex < epochCount; ++epochIndex) {
            InputRange memory inputRange = _emulator.getInputRange(epochIndex);
            bytes32 epochHash = _emulator.getEpochHash(epochIndex);
            _submitClaim(inputRange, epochHash);
        }
    }

    function _submitClaim(
        InputRange memory inputRange,
        bytes32 epochHash
    ) internal {
        vm.prank(_authorityOwner);
        _consensus.submitClaim(address(_appContract), inputRange, epochHash);
    }

    function _expectEmitOutputExecuted(
        bytes memory output,
        OutputValidityProof memory proof
    ) internal {
        vm.expectEmit(false, false, false, true, address(_appContract));
        emit IApplication.OutputExecuted(
            proof.inputRange.firstIndex + proof.inputIndexWithinEpoch,
            proof.outputIndexWithinInput,
            output
        );
    }

    function _expectRevertOutputNotExecutable(bytes memory output) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                IApplication.OutputNotExecutable.selector,
                output
            )
        );
    }

    function _expectRevertOutputNotReexecutable(bytes memory output) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                IApplication.OutputNotReexecutable.selector,
                output
            )
        );
    }

    function _wasOutputExecuted(
        OutputValidityProof memory proof
    ) internal view returns (bool) {
        return
            _appContract.wasOutputExecuted(
                proof.inputRange.firstIndex + proof.inputIndexWithinEpoch,
                proof.outputIndexWithinInput
            );
    }

    function _mockENS() internal {
        vm.mockCall(
            address(_ens),
            abi.encodeCall(ENS.resolver, (_ensNode)),
            abi.encode(_resolver)
        );
        vm.mockCall(
            address(_resolver),
            abi.encodeWithSignature("addr(bytes32)", (_ensNode)),
            abi.encode(_recipient)
        );
    }

    function assertEq(IPortal[] memory a, IPortal[] memory b) internal pure {
        assertEq(a.length, b.length);
        for (uint256 i; i < a.length; ++i) {
            assertEq(address(a[i]), address(b[i]));
        }
    }

    function _testEtherTransfer(
        bytes memory output,
        OutputValidityProof memory proof
    ) internal {
        assertLt(
            address(_appContract).balance,
            _transferAmount,
            "Application contract does not have enough Ether"
        );

        vm.expectRevert();
        _appContract.executeOutput(output, proof);

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

        assertTrue(
            _wasOutputExecuted(proof),
            "Output should be marked as executed"
        );

        _expectRevertOutputNotReexecutable(output);
        _appContract.executeOutput(output, proof);
    }

    function _testEtherMint(
        bytes memory output,
        OutputValidityProof memory proof
    ) internal {
        assertLt(
            address(_appContract).balance,
            _transferAmount,
            "Application contract does not have enough Ether"
        );

        vm.expectRevert();
        _appContract.executeOutput(output, proof);

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

        assertTrue(
            _wasOutputExecuted(proof),
            "Output should be marked as executed"
        );

        _expectRevertOutputNotReexecutable(output);
        _appContract.executeOutput(output, proof);
    }

    function _testERC721Transfer(
        bytes memory output,
        OutputValidityProof memory proof
    ) internal {
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

        vm.prank(_tokenOwner);
        _erc721Token.safeTransferFrom(
            _tokenOwner,
            address(_appContract),
            _tokenId
        );

        _expectEmitOutputExecuted(output, proof);
        _appContract.executeOutput(output, proof);

        assertEq(
            _erc721Token.ownerOf(_tokenId),
            _recipient,
            "The NFT is then transferred to the recipient"
        );

        assertTrue(
            _wasOutputExecuted(proof),
            "Output should be marked as executed"
        );

        _expectRevertOutputNotReexecutable(output);
        _appContract.executeOutput(output, proof);
    }

    function _testERC20Fail(
        bytes memory output,
        OutputValidityProof memory proof
    ) internal {
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

        // test return false

        vm.mockCall(
            address(_erc20Token),
            abi.encodeCall(_erc20Token.transfer, (_recipient, _transferAmount)),
            abi.encode(false)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeERC20.SafeERC20FailedOperation.selector,
                address(_erc20Token)
            )
        );
        _appContract.executeOutput(output, proof);
        vm.clearMockedCalls();
    }

    function _testERC20Success(
        bytes memory output,
        OutputValidityProof memory proof
    ) internal {
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

        assertTrue(
            _wasOutputExecuted(proof),
            "Output should be marked as executed"
        );

        _expectRevertOutputNotReexecutable(output);
        _appContract.executeOutput(output, proof);
    }
}

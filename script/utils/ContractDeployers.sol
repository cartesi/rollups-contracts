// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

import {AuthorityFactory} from "src/consensus/authority/AuthorityFactory.sol";
import {IAuthorityFactory} from "src/consensus/authority/IAuthorityFactory.sol";
import {QuorumFactory} from "src/consensus/quorum/QuorumFactory.sol";
import {ApplicationFactory} from "src/dapp/ApplicationFactory.sol";
import {IApplicationFactory} from "src/dapp/IApplicationFactory.sol";
import {SelfHostedApplicationFactory} from "src/dapp/SelfHostedApplicationFactory.sol";
import {ISafeERC20Transfer} from "src/delegatecall/ISafeERC20Transfer.sol";
import {SafeERC20Transfer} from "src/delegatecall/SafeERC20Transfer.sol";
import {TestFungibleToken} from "src/devnet/TestFungibleToken.sol";
import {TestMultiToken} from "src/devnet/TestMultiToken.sol";
import {TestNonFungibleToken} from "src/devnet/TestNonFungibleToken.sol";
import {InputBox} from "src/inputs/InputBox.sol";
import {ERC1155BatchPortal} from "src/portals/ERC1155BatchPortal.sol";
import {ERC1155SinglePortal} from "src/portals/ERC1155SinglePortal.sol";
import {ERC20Portal} from "src/portals/ERC20Portal.sol";
import {ERC721Portal} from "src/portals/ERC721Portal.sol";
import {EtherPortal} from "src/portals/EtherPortal.sol";
import {IERC1155BatchPortal} from "src/portals/IERC1155BatchPortal.sol";
import {IERC1155SinglePortal} from "src/portals/IERC1155SinglePortal.sol";
import {IERC20Portal} from "src/portals/IERC20Portal.sol";
import {IERC721Portal} from "src/portals/IERC721Portal.sol";
import {IEtherPortal} from "src/portals/IEtherPortal.sol";
import {IRefundOutputBuilder} from "src/refund/IRefundOutputBuilder.sol";
import {RefundOutputBuilder} from "src/refund/RefundOutputBuilder.sol";
import {IUsdWithdrawalOutputBuilder} from "src/withdrawal/IUsdWithdrawalOutputBuilder.sol";
import {IUsdWithdrawalOutputBuilderFactory} from "src/withdrawal/IUsdWithdrawalOutputBuilderFactory.sol";
import {UsdWithdrawalOutputBuilderFactory} from "src/withdrawal/UsdWithdrawalOutputBuilderFactory.sol";

function computeAddress(bytes32 salt, bytes32 initCodeHash) pure returns (address) {
    return address(
        uint160(
            uint256(
                keccak256(
                    abi.encodePacked(
                        bytes1(0xff),
                        0x4e59b44847b379578588920cA78FbF26c0B4956C,
                        salt,
                        initCodeHash
                    )
                )
            )
        )
    );
}

function deployAuthorityFactory() returns (AuthorityFactory deployment) {
    bytes32 salt;
    bytes memory creationCode = type(AuthorityFactory).creationCode;
    bytes memory encodedArgs = abi.encode();
    bytes memory initCode = abi.encodePacked(creationCode, encodedArgs);
    bytes32 initCodeHash = keccak256(initCode);
    address precomputedAddress = computeAddress(salt, initCodeHash);
    if (precomputedAddress.code.length == 0) {
        deployment = new AuthorityFactory{salt: salt}();
        assert(address(deployment) == precomputedAddress);
        assert(address(deployment).code.length > 0);
    } else {
        deployment = AuthorityFactory(precomputedAddress);
    }
}

function deployInputBox() returns (InputBox deployment) {
    bytes32 salt;
    bytes memory creationCode = type(InputBox).creationCode;
    bytes memory encodedArgs = abi.encode();
    bytes memory initCode = abi.encodePacked(creationCode, encodedArgs);
    bytes32 initCodeHash = keccak256(initCode);
    address precomputedAddress = computeAddress(salt, initCodeHash);
    if (precomputedAddress.code.length == 0) {
        deployment = new InputBox{salt: salt}();
        assert(address(deployment) == precomputedAddress);
        assert(address(deployment).code.length > 0);
    } else {
        deployment = InputBox(precomputedAddress);
    }
}

function deployQuorumFactory() returns (QuorumFactory deployment) {
    bytes32 salt;
    bytes memory creationCode = type(QuorumFactory).creationCode;
    bytes memory encodedArgs = abi.encode();
    bytes memory initCode = abi.encodePacked(creationCode, encodedArgs);
    bytes32 initCodeHash = keccak256(initCode);
    address precomputedAddress = computeAddress(salt, initCodeHash);
    if (precomputedAddress.code.length == 0) {
        deployment = new QuorumFactory{salt: salt}();
        assert(address(deployment) == precomputedAddress);
        assert(address(deployment).code.length > 0);
    } else {
        deployment = QuorumFactory(precomputedAddress);
    }
}

function deploySafeERC20Transfer() returns (SafeERC20Transfer deployment) {
    bytes32 salt;
    bytes memory creationCode = type(SafeERC20Transfer).creationCode;
    bytes memory encodedArgs = abi.encode();
    bytes memory initCode = abi.encodePacked(creationCode, encodedArgs);
    bytes32 initCodeHash = keccak256(initCode);
    address precomputedAddress = computeAddress(salt, initCodeHash);
    if (precomputedAddress.code.length == 0) {
        deployment = new SafeERC20Transfer{salt: salt}();
        assert(address(deployment) == precomputedAddress);
        assert(address(deployment).code.length > 0);
    } else {
        deployment = SafeERC20Transfer(precomputedAddress);
    }
}

function deployTestFungibleToken() returns (TestFungibleToken deployment) {
    bytes32 salt;
    bytes memory creationCode = type(TestFungibleToken).creationCode;
    bytes memory encodedArgs = abi.encode();
    bytes memory initCode = abi.encodePacked(creationCode, encodedArgs);
    bytes32 initCodeHash = keccak256(initCode);
    address precomputedAddress = computeAddress(salt, initCodeHash);
    if (precomputedAddress.code.length == 0) {
        deployment = new TestFungibleToken{salt: salt}();
        assert(address(deployment) == precomputedAddress);
        assert(address(deployment).code.length > 0);
    } else {
        deployment = TestFungibleToken(precomputedAddress);
    }
}

function deployTestMultiToken() returns (TestMultiToken deployment) {
    bytes32 salt;
    bytes memory creationCode = type(TestMultiToken).creationCode;
    bytes memory encodedArgs = abi.encode();
    bytes memory initCode = abi.encodePacked(creationCode, encodedArgs);
    bytes32 initCodeHash = keccak256(initCode);
    address precomputedAddress = computeAddress(salt, initCodeHash);
    if (precomputedAddress.code.length == 0) {
        deployment = new TestMultiToken{salt: salt}();
        assert(address(deployment) == precomputedAddress);
        assert(address(deployment).code.length > 0);
    } else {
        deployment = TestMultiToken(precomputedAddress);
    }
}

function deployTestNonFungibleToken() returns (TestNonFungibleToken deployment) {
    bytes32 salt;
    bytes memory creationCode = type(TestNonFungibleToken).creationCode;
    bytes memory encodedArgs = abi.encode();
    bytes memory initCode = abi.encodePacked(creationCode, encodedArgs);
    bytes32 initCodeHash = keccak256(initCode);
    address precomputedAddress = computeAddress(salt, initCodeHash);
    if (precomputedAddress.code.length == 0) {
        deployment = new TestNonFungibleToken{salt: salt}();
        assert(address(deployment) == precomputedAddress);
        assert(address(deployment).code.length > 0);
    } else {
        deployment = TestNonFungibleToken(precomputedAddress);
    }
}

function deployERC1155BatchPortal() returns (ERC1155BatchPortal deployment) {
    bytes32 salt;
    bytes memory creationCode = type(ERC1155BatchPortal).creationCode;
    bytes memory encodedArgs = abi.encode();
    bytes memory initCode = abi.encodePacked(creationCode, encodedArgs);
    bytes32 initCodeHash = keccak256(initCode);
    address precomputedAddress = computeAddress(salt, initCodeHash);
    if (precomputedAddress.code.length == 0) {
        deployment = new ERC1155BatchPortal{salt: salt}();
        assert(address(deployment) == precomputedAddress);
        assert(address(deployment).code.length > 0);
    } else {
        deployment = ERC1155BatchPortal(precomputedAddress);
    }
}

function deployERC1155SinglePortal() returns (ERC1155SinglePortal deployment) {
    bytes32 salt;
    bytes memory creationCode = type(ERC1155SinglePortal).creationCode;
    bytes memory encodedArgs = abi.encode();
    bytes memory initCode = abi.encodePacked(creationCode, encodedArgs);
    bytes32 initCodeHash = keccak256(initCode);
    address precomputedAddress = computeAddress(salt, initCodeHash);
    if (precomputedAddress.code.length == 0) {
        deployment = new ERC1155SinglePortal{salt: salt}();
        assert(address(deployment) == precomputedAddress);
        assert(address(deployment).code.length > 0);
    } else {
        deployment = ERC1155SinglePortal(precomputedAddress);
    }
}

function deployERC20Portal() returns (ERC20Portal deployment) {
    bytes32 salt;
    bytes memory creationCode = type(ERC20Portal).creationCode;
    bytes memory encodedArgs = abi.encode();
    bytes memory initCode = abi.encodePacked(creationCode, encodedArgs);
    bytes32 initCodeHash = keccak256(initCode);
    address precomputedAddress = computeAddress(salt, initCodeHash);
    if (precomputedAddress.code.length == 0) {
        deployment = new ERC20Portal{salt: salt}();
        assert(address(deployment) == precomputedAddress);
        assert(address(deployment).code.length > 0);
    } else {
        deployment = ERC20Portal(precomputedAddress);
    }
}

function deployERC721Portal() returns (ERC721Portal deployment) {
    bytes32 salt;
    bytes memory creationCode = type(ERC721Portal).creationCode;
    bytes memory encodedArgs = abi.encode();
    bytes memory initCode = abi.encodePacked(creationCode, encodedArgs);
    bytes32 initCodeHash = keccak256(initCode);
    address precomputedAddress = computeAddress(salt, initCodeHash);
    if (precomputedAddress.code.length == 0) {
        deployment = new ERC721Portal{salt: salt}();
        assert(address(deployment) == precomputedAddress);
        assert(address(deployment).code.length > 0);
    } else {
        deployment = ERC721Portal(precomputedAddress);
    }
}

function deployEtherPortal() returns (EtherPortal deployment) {
    bytes32 salt;
    bytes memory creationCode = type(EtherPortal).creationCode;
    bytes memory encodedArgs = abi.encode();
    bytes memory initCode = abi.encodePacked(creationCode, encodedArgs);
    bytes32 initCodeHash = keccak256(initCode);
    address precomputedAddress = computeAddress(salt, initCodeHash);
    if (precomputedAddress.code.length == 0) {
        deployment = new EtherPortal{salt: salt}();
        assert(address(deployment) == precomputedAddress);
        assert(address(deployment).code.length > 0);
    } else {
        deployment = EtherPortal(precomputedAddress);
    }
}

function deployRefundOutputBuilder(
    IEtherPortal param1,
    IERC20Portal param2,
    IERC721Portal param3,
    IERC1155SinglePortal param4,
    IERC1155BatchPortal param5,
    ISafeERC20Transfer param6
) returns (RefundOutputBuilder deployment) {
    bytes32 salt;
    bytes memory creationCode = type(RefundOutputBuilder).creationCode;
    bytes memory encodedArgs = abi.encode(param1, param2, param3, param4, param5, param6);
    bytes memory initCode = abi.encodePacked(creationCode, encodedArgs);
    bytes32 initCodeHash = keccak256(initCode);
    address precomputedAddress = computeAddress(salt, initCodeHash);
    if (precomputedAddress.code.length == 0) {
        deployment = new RefundOutputBuilder{salt: salt}(
            param1, param2, param3, param4, param5, param6
        );
        assert(address(deployment) == precomputedAddress);
        assert(address(deployment).code.length > 0);
    } else {
        deployment = RefundOutputBuilder(precomputedAddress);
    }
}

function deployApplicationFactory(IRefundOutputBuilder param1)
    returns (ApplicationFactory deployment)
{
    bytes32 salt;
    bytes memory creationCode = type(ApplicationFactory).creationCode;
    bytes memory encodedArgs = abi.encode(param1);
    bytes memory initCode = abi.encodePacked(creationCode, encodedArgs);
    bytes32 initCodeHash = keccak256(initCode);
    address precomputedAddress = computeAddress(salt, initCodeHash);
    if (precomputedAddress.code.length == 0) {
        deployment = new ApplicationFactory{salt: salt}(param1);
        assert(address(deployment) == precomputedAddress);
        assert(address(deployment).code.length > 0);
    } else {
        deployment = ApplicationFactory(precomputedAddress);
    }
}

function deployUsdWithdrawalOutputBuilderFactory(ISafeERC20Transfer param1)
    returns (UsdWithdrawalOutputBuilderFactory deployment)
{
    bytes32 salt;
    bytes memory creationCode = type(UsdWithdrawalOutputBuilderFactory).creationCode;
    bytes memory encodedArgs = abi.encode(param1);
    bytes memory initCode = abi.encodePacked(creationCode, encodedArgs);
    bytes32 initCodeHash = keccak256(initCode);
    address precomputedAddress = computeAddress(salt, initCodeHash);
    if (precomputedAddress.code.length == 0) {
        deployment = new UsdWithdrawalOutputBuilderFactory{salt: salt}(param1);
        assert(address(deployment) == precomputedAddress);
        assert(address(deployment).code.length > 0);
    } else {
        deployment = UsdWithdrawalOutputBuilderFactory(precomputedAddress);
    }
}

function deploySelfHostedApplicationFactory(
    IAuthorityFactory param1,
    IApplicationFactory param2
) returns (SelfHostedApplicationFactory deployment) {
    bytes32 salt;
    bytes memory creationCode = type(SelfHostedApplicationFactory).creationCode;
    bytes memory encodedArgs = abi.encode(param1, param2);
    bytes memory initCode = abi.encodePacked(creationCode, encodedArgs);
    bytes32 initCodeHash = keccak256(initCode);
    address precomputedAddress = computeAddress(salt, initCodeHash);
    if (precomputedAddress.code.length == 0) {
        deployment = new SelfHostedApplicationFactory{salt: salt}(param1, param2);
        assert(address(deployment) == precomputedAddress);
        assert(address(deployment).code.length > 0);
    } else {
        deployment = SelfHostedApplicationFactory(precomputedAddress);
    }
}

function deployUsdWithdrawalOutputBuilder(
    IUsdWithdrawalOutputBuilderFactory factory,
    IERC20 param1
) returns (IUsdWithdrawalOutputBuilder deployment) {
    bytes32 salt;
    address addr = factory.calculateUsdWithdrawalOutputBuilderAddress(param1, salt);
    if (addr.code.length == 0) {
        deployment = factory.newUsdWithdrawalOutputBuilder(param1, salt);
        assert(address(deployment) == addr);
        assert(addr.code.length > 0);
    } else {
        deployment = IUsdWithdrawalOutputBuilder(addr);
    }
}

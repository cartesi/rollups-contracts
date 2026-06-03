// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.8;

import {Script} from "forge-std-1.9.6/src/Script.sol";

abstract contract CodeGenerationScript is Script {
    string private _code;

    function _addLine(string memory line) internal {
        _code = string.concat(_code, line, "\n");
    }

    function _addPreamble() internal {
        _addLine("// (c) Cartesi and individual authors (see AUTHORS)");
        _addLine("// SPDX-License-Identifier: Apache-2.0");
        _addLine("");
        _addLine("pragma solidity ^0.8.30;");
        _addLine("");
    }

    function _addImport(string memory directory, string memory contractName) internal {
        string memory path = string.concat(directory, "/", contractName, ".sol");
        _addLine(string.concat("import {", contractName, '} from "', path, '";'));
    }

    function _writeCodeToFile(string memory path) internal {
        // forge-lint: disable-next-line(unsafe-cheatcode)
        vmSafe.writeFile(path, _code);
    }
}

contract DeployersCodeGenerationScript is CodeGenerationScript {
    function run() external {
        _addPreamble();
        _addImport("src/consensus/authority", "AuthorityFactory");
        _addImport("src/consensus/authority", "IAuthorityFactory");
        _addImport("src/consensus/quorum", "QuorumFactory");
        _addImport("src/dapp", "ApplicationFactory");
        _addImport("src/dapp", "IApplicationFactory");
        _addImport("src/dapp", "SelfHostedApplicationFactory");
        _addImport("src/delegatecall", "ISafeERC20Transfer");
        _addImport("src/delegatecall", "SafeERC20Transfer");
        _addImport("src/devnet", "TestFungibleToken");
        _addImport("src/devnet", "TestMultiToken");
        _addImport("src/devnet", "TestNonFungibleToken");
        _addImport("src/inputs", "IInputBox");
        _addImport("src/inputs", "InputBox");
        _addImport("src/portals", "ERC1155BatchPortal");
        _addImport("src/portals", "ERC1155SinglePortal");
        _addImport("src/portals", "ERC20Portal");
        _addImport("src/portals", "ERC721Portal");
        _addImport("src/portals", "EtherPortal");
        _addImport("src/withdrawal", "UsdWithdrawalOutputBuilderFactory");
        _addLine("");
        _addLine("function computeAddress(bytes32 salt, bytes32 initCodeHash)");
        _addLine("pure returns (address) {");
        _addLine("return address(uint160(uint256(keccak256(");
        _addLine("abi.encodePacked(bytes1(0xff),");
        _addLine(vmSafe.toString(CREATE2_FACTORY));
        _addLine(", salt, initCodeHash)");
        _addLine("))));");
        _addLine("}"); // function
        _addLine("");

        {
            string[] memory paramTypes = new string[](0);
            _addDeployer("ApplicationFactory", paramTypes);
            _addDeployer("AuthorityFactory", paramTypes);
            _addDeployer("InputBox", paramTypes);
            _addDeployer("QuorumFactory", paramTypes);
            _addDeployer("SafeERC20Transfer", paramTypes);
            _addDeployer("TestFungibleToken", paramTypes);
            _addDeployer("TestMultiToken", paramTypes);
            _addDeployer("TestNonFungibleToken", paramTypes);
        }

        {
            string[] memory paramTypes = new string[](1);
            paramTypes[0] = "IInputBox";
            _addDeployer("ERC1155BatchPortal", paramTypes);
            _addDeployer("ERC1155SinglePortal", paramTypes);
            _addDeployer("ERC20Portal", paramTypes);
            _addDeployer("ERC721Portal", paramTypes);
            _addDeployer("EtherPortal", paramTypes);
        }

        {
            string[] memory paramTypes = new string[](1);
            paramTypes[0] = "ISafeERC20Transfer";
            _addDeployer("UsdWithdrawalOutputBuilderFactory", paramTypes);
        }

        {
            string[] memory paramTypes = new string[](2);
            paramTypes[0] = "IAuthorityFactory";
            paramTypes[1] = "IApplicationFactory";
            _addDeployer("SelfHostedApplicationFactory", paramTypes);
        }

        _writeCodeToFile("script/utils/ContractDeployers.sol");
    }

    function _addDeployer(string memory contractName, string[] memory paramTypes)
        internal
    {
        string memory parameters;
        string memory arguments;

        for (uint256 i; i < paramTypes.length; ++i) {
            string memory paramName = string.concat("param", vmSafe.toString(i + 1));
            string memory paramType = paramTypes[i];
            string memory sep = (i == 0) ? "" : ", ";
            parameters = string.concat(parameters, sep, paramType, " ", paramName);
            arguments = string.concat(arguments, sep, paramName);
        }

        string memory funcName = string.concat("deploy", contractName);
        string memory funcSig = string.concat(funcName, "(", parameters, ")");
        string memory returnTuple = string.concat("(", contractName, " deployment)");
        string memory contractType = string.concat("type(", contractName, ")");
        string memory creationCode = string.concat(contractType, ".creationCode");
        string memory encodedArgs = string.concat("abi.encode(", arguments, ")");
        string memory newContract = string.concat("new ", contractName, "{salt: salt}");

        _addLine("");
        _addLine(string.concat("function ", funcSig, " returns ", returnTuple, " {"));
        _addLine("bytes32 salt;");
        _addLine(string.concat("bytes memory creationCode = ", creationCode, ";"));
        _addLine(string.concat("bytes memory encodedArgs = ", encodedArgs, ";"));
        _addLine("bytes memory initCode = abi.encodePacked(creationCode, encodedArgs);");
        _addLine("bytes32 initCodeHash = keccak256(initCode);");
        _addLine("address precomputedAddress = computeAddress(salt, initCodeHash);");
        _addLine("if (precomputedAddress.code.length == 0) {");
        _addLine(string.concat("deployment = ", newContract, "(", arguments, ");"));
        _addLine("assert(address(deployment) == precomputedAddress);");
        _addLine("} else {");
        _addLine(string.concat("deployment = ", contractName, "(precomputedAddress);"));
        _addLine("}"); // if
        _addLine("}"); // function
    }
}

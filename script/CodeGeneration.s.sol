// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.30;

import {Script} from "forge-std-1.9.6/src/Script.sol";

import "./utils/SemanticVersioning.sol" as SemanticVersioning;

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

    function _addConstant(
        string memory constantType,
        string memory constantName,
        string memory rhs
    ) internal {
        string memory lhs = string.concat(constantType, " constant ", constantName);
        _addLine(string.concat(lhs, " = ", rhs, ";"));
    }

    function _buildParamsAndArgs(string[] memory paramTypes)
        internal
        pure
        returns (string memory params, string memory args)
    {
        for (uint256 i; i < paramTypes.length; ++i) {
            string memory paramName = string.concat("param", vmSafe.toString(i + 1));
            string memory paramType = paramTypes[i];
            params = _join(params, string.concat(paramType, " ", paramName));
            args = _join(args, paramName);
        }
    }

    function _join(string memory a, string memory b)
        internal
        pure
        returns (string memory c)
    {
        if (bytes(a).length == 0) {
            return b;
        } else if (bytes(b).length == 0) {
            return a;
        } else {
            return string.concat(a, ", ", b);
        }
    }

    function _quote(string memory str) internal pure returns (string memory) {
        return string.concat("\"", str, "\"");
    }

    function _writeCodeToFile(string memory path) internal {
        // forge-lint: disable-next-line(unsafe-cheatcode)
        vmSafe.writeFile(path, _code);
    }
}

contract DeployersCodeGenerationScript is CodeGenerationScript {
    function run() external {
        _addPreamble();
        _addImport("@openzeppelin-contracts-5.2.0/token/ERC20", "IERC20");
        _addLine("");
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
        _addImport("src/portals", "IERC1155BatchPortal");
        _addImport("src/portals", "IERC1155SinglePortal");
        _addImport("src/portals", "IERC20Portal");
        _addImport("src/portals", "IERC721Portal");
        _addImport("src/portals", "IEtherPortal");
        _addImport("src/refund", "IRefundOutputBuilder");
        _addImport("src/refund", "RefundOutputBuilder");
        _addImport("src/withdrawal", "IUsdWithdrawalOutputBuilder");
        _addImport("src/withdrawal", "IUsdWithdrawalOutputBuilderFactory");
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
            string[] memory paramTypes = new string[](6);
            paramTypes[0] = "IEtherPortal";
            paramTypes[1] = "IERC20Portal";
            paramTypes[2] = "IERC721Portal";
            paramTypes[3] = "IERC1155SinglePortal";
            paramTypes[4] = "IERC1155BatchPortal";
            paramTypes[5] = "ISafeERC20Transfer";
            _addDeployer("RefundOutputBuilder", paramTypes);
        }

        {
            string[] memory paramTypes = new string[](1);
            paramTypes[0] = "IRefundOutputBuilder";
            _addDeployer("ApplicationFactory", paramTypes);
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

        {
            string[] memory paramTypes = new string[](1);
            paramTypes[0] = "IERC20";
            _addFactoryDeployer("UsdWithdrawalOutputBuilder", paramTypes);
        }

        _writeCodeToFile("script/utils/ContractDeployers.sol");
    }

    function _addDeployer(string memory contractName, string[] memory paramTypes)
        internal
    {
        (string memory params, string memory args) = _buildParamsAndArgs(paramTypes);
        string memory funcName = string.concat("deploy", contractName);
        string memory funcSig = string.concat(funcName, "(", params, ")");
        string memory returnTuple = string.concat("(", contractName, " deployment)");
        string memory contractType = string.concat("type(", contractName, ")");
        string memory creationCode = string.concat(contractType, ".creationCode");
        string memory encodedArgs = string.concat("abi.encode(", args, ")");
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
        _addLine(string.concat("deployment = ", newContract, "(", args, ");"));
        _addLine("assert(address(deployment) == precomputedAddress);");
        _addLine("assert(address(deployment).code.length > 0);");
        _addLine("} else {");
        _addLine(string.concat("deployment = ", contractName, "(precomputedAddress);"));
        _addLine("}"); // if
        _addLine("}"); // function
    }

    function _addFactoryDeployer(string memory contractName, string[] memory paramTypes)
        internal
    {
        (string memory params, string memory args) = _buildParamsAndArgs(paramTypes);
        string memory interfaceName = string.concat("I", contractName);
        string memory factoryName = string.concat(interfaceName, "Factory");
        string memory factoryParam = string.concat(factoryName, " factory");
        string memory funcName = string.concat("deploy", contractName);
        string memory returnTuple = string.concat("(", interfaceName, " deployment)");
        string memory calcFuncName = string.concat("calculate", contractName, "Address");
        string memory newFuncName = string.concat("new", contractName);

        params = _join(factoryParam, params);
        args = _join(args, "salt");

        string memory funcSig = string.concat(funcName, "(", params, ")");
        string memory calcFuncCall = string.concat(calcFuncName, "(", args, ")");
        string memory newFuncCall = string.concat(newFuncName, "(", args, ")");

        _addLine("");
        _addLine(string.concat("function ", funcSig, " returns ", returnTuple, " {"));
        _addLine("bytes32 salt;");
        _addLine(string.concat("address addr = factory.", calcFuncCall, ";"));
        _addLine("if (addr.code.length == 0) {");
        _addLine(string.concat("deployment = factory.", newFuncCall, ";"));
        _addLine("assert(address(deployment) == addr);");
        _addLine("assert(addr.code.length > 0);");
        _addLine("} else {");
        _addLine(string.concat("deployment = ", interfaceName, "(addr);"));
        _addLine("}"); // if
        _addLine("}"); // function
    }
}

contract VersionCodeGenerationScript is CodeGenerationScript {
    /// @notice This error is raised whenever the script is run with
    /// an invalid semantic version pre-release string.
    /// @param preRelease The pre-release string
    error InvalidPreRelease(string preRelease);

    /// @notice This error is raised whenever the script is run with
    /// an invalid semantic version build metadata string.
    /// @param buildMetadata The build metadata string
    error InvalidBuildMetadata(string buildMetadata);

    function run(
        uint64 major,
        uint64 minor,
        uint64 patch,
        string memory preRelease,
        string memory buildMetadata
    ) external {
        // First, we validate the pre-release and build metadata strings against the
        // grammar at <https://semver.org/>. If this script is run with an invalid
        // semantic version, then an appropriate custom error will be raised and the
        // Version.sol file will remain intact. This avoids the production of ill-formed
        // Solidity code, given that pre-release and build metadata strings disallow
        // quotes and other characters that might result in compilation errors.
        require(
            SemanticVersioning.isPreReleaseValid(bytes(preRelease)),
            InvalidPreRelease(preRelease)
        );
        require(
            SemanticVersioning.isBuildMetadataValid(bytes(buildMetadata)),
            InvalidBuildMetadata(buildMetadata)
        );

        _addPreamble();
        _addConstant("uint64", "MAJOR", vmSafe.toString(major));
        _addConstant("uint64", "MINOR", vmSafe.toString(minor));
        _addConstant("uint64", "PATCH", vmSafe.toString(patch));
        _addConstant("string", "PRE_RELEASE", _quote(preRelease));
        _addConstant("string", "BUILD_METADATA", _quote(buildMetadata));

        _writeCodeToFile("src/common/Version.sol");
    }
}

// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {VersionGetterTestUtils} from "./VersionGetterTestUtils.sol";

contract VersionGetterTestUtilsTest is VersionGetterTestUtils {
    string[] _strings;

    function testValidPreReleases() external {
        _strings.push("alpha");
        _strings.push("beta");
        _strings.push("rc");
        _strings.push("x");
        _strings.push("a-b");
        _strings.push("a-");
        _strings.push("-a");
        _strings.push("--");
        _strings.push("0");
        _strings.push("0a");
        _strings.push("00a");
        _strings.push("1");
        _strings.push("99");
        _strings.push("1000");
        _strings.push("1.2.3");
        _strings.push("alpha.1");
        _strings.push("alpha.beta");
        _strings.push("rc.1.beta.2");
        _strings.push("x.7.z.92");
        _strings.push("0.1.2");
        _strings.push("1.0.0");
        _strings.push("-alpha");
        _strings.push("-alpha.1");
        _strings.push("-.1");
        _strings.push("0.0.0");
        _strings.push("1.2.3.4.5.6.7.8.9");
        _strings.push("a1b2c3");
        _strings.push("123abc");
        _strings.push("abc123");
        _strings.push("1-2-3");
        _strings.push("alpha--beta");
        _strings.push("ALPHA");
        _strings.push("RC");
        _strings.push("A.B.C");
        _strings.push("0.alpha.1");
        _strings.push("alpha.0");

        for (uint256 i; i < _strings.length; ++i) {
            assertTrue(
                _isPreReleaseValid(bytes(_strings[i])),
                string.concat("Expected ", _strings[i], " to be valid")
            );
        }
    }

    function testInvalidPreReleases() external {
        _strings.push("");
        _strings.push("00");
        _strings.push("01");
        _strings.push("09");
        _strings.push("0!");
        _strings.push("00.1");
        _strings.push("000");
        _strings.push("1.00.3");
        _strings.push("0.01");
        _strings.push(".");
        _strings.push(".alpha");
        _strings.push("alpha.");
        _strings.push("alpha..beta");
        _strings.push("alpha. .beta");
        _strings.push(" alpha");
        _strings.push("alpha ");
        _strings.push("alpha.beta .rc");
        _strings.push("!");
        _strings.push("alpha!");
        _strings.push("@beta");
        _strings.push("1.2.!");
        _strings.push("1.2.#3");
        _strings.push("alpha/beta");
        _strings.push("alpha+beta");
        _strings.push("alpha.+");
        _strings.push("1.2.3+");
        _strings.push("1.2.3.");
        _strings.push(".1.2.3");

        for (uint256 i; i < _strings.length; ++i) {
            assertFalse(
                _isPreReleaseValid(bytes(_strings[i])),
                string.concat("Expected ", _strings[i], " to be invalid")
            );
        }
    }

    function testValidBuildMetadatas() external {
        _strings.push("001");
        _strings.push("000");
        _strings.push("00");
        _strings.push("01");
        _strings.push("099");
        _strings.push("1");
        _strings.push("99");
        _strings.push("1000");
        _strings.push("0");
        _strings.push("exp");
        _strings.push("sha");
        _strings.push("build");
        _strings.push("BUILD");
        _strings.push("RC");
        _strings.push("a-b");
        _strings.push("a-");
        _strings.push("-a");
        _strings.push("--");
        _strings.push("-");
        _strings.push("0.0.0");
        _strings.push("1.2.3");
        _strings.push("001.002.003");
        _strings.push("exp.sha.5114f85");
        _strings.push("20130313144700");
        _strings.push("0.build.1");
        _strings.push("build.01");
        _strings.push("alpha.001");
        _strings.push("a1b2c3");
        _strings.push("123abc");
        _strings.push("ALPHA.BETA");
        _strings.push("A.B.C");
        _strings.push("x.7.z.92");
        _strings.push("1-2-3");
        _strings.push("alpha--beta");

        for (uint256 i; i < _strings.length; ++i) {
            assertTrue(
                _isBuildMetadataValid(bytes(_strings[i])),
                string.concat("Expected ", _strings[i], " to be valid")
            );
        }
    }

    function testInvalidBuildMetadatas() external {
        _strings.push("");
        _strings.push(".");
        _strings.push(".build");
        _strings.push("build.");
        _strings.push("build..1");
        _strings.push("..");
        _strings.push(".1.2.3");
        _strings.push("1.2.3.");
        _strings.push("build. .1");
        _strings.push(" build");
        _strings.push("build ");
        _strings.push("build.meta data");
        _strings.push("build.meta!");
        _strings.push("build+extra");
        _strings.push("exp.sha+abc");
        _strings.push("1.2.!");
        _strings.push("@build");
        _strings.push("build/1");
        _strings.push("build.#1");

        for (uint256 i; i < _strings.length; ++i) {
            assertFalse(
                _isBuildMetadataValid(bytes(_strings[i])),
                string.concat("Expected ", _strings[i], " to be invalid")
            );
        }
    }
}

// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Authority Test
pragma solidity ^0.8.8;

import {TestBase} from "../../util/TestBase.sol";
import {Authority} from "contracts/consensus/authority/Authority.sol";
import {IHistory} from "contracts/history/IHistory.sol";
import {Vm} from "forge-std/Vm.sol";

contract HistoryReverts is IHistory {
    function submitClaim(bytes calldata) external pure override {
        revert();
    }

    function migrateToConsensus(address) external pure override {
        revert();
    }

    function getClaim(
        address,
        bytes calldata
    ) external pure override returns (bytes32, uint256, uint256) {
        revert();
    }
}

contract AuthorityTest is TestBase {
    Authority authority;

    // events
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event NewHistory(IHistory history);
    event ApplicationJoined(address application);

    function testConstructor(address _owner) public {
        vm.assume(_owner != address(0));
        uint256 numOfEvents;

        // two `OwnershipTransferred` events might be emitted during the constructor call
        // the first event is emitted by Ownable constructor
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(0), address(this));
        ++numOfEvents;

        // a second event is emitted by Authority constructor iff msg.sender != _owner
        if (_owner != address(this)) {
            vm.expectEmit(true, true, false, false);
            emit OwnershipTransferred(address(this), _owner);
            ++numOfEvents;
        }

        vm.recordLogs();
        authority = new Authority(_owner);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, numOfEvents, "number of events");
        assertEq(authority.owner(), _owner, "authority owner");
    }

    function testRevertsOwnerAddressZero() public {
        vm.expectRevert("Ownable: new owner is the zero address");
        new Authority(address(0));
    }

    function testMigrateHistory(
        address _owner,
        IHistory _history,
        address _newConsensus
    ) public isMockable(address(_history)) {
        vm.assume(_owner != address(0));
        vm.assume(_owner != address(this));
        vm.assume(_newConsensus != address(0));

        authority = new Authority(_owner);

        vm.prank(_owner);
        authority.setHistory(_history);

        vm.assume(address(_history) != address(authority));
        vm.mockCall(
            address(_history),
            abi.encodeWithSelector(
                IHistory.migrateToConsensus.selector,
                _newConsensus
            ),
            ""
        );

        // will fail as not called from owner
        vm.expectRevert("Ownable: caller is not the owner");
        authority.migrateHistoryToConsensus(_newConsensus);

        vm.expectCall(
            address(_history),
            abi.encodeWithSelector(
                IHistory.migrateToConsensus.selector,
                _newConsensus
            )
        );

        // can only be called by owner
        vm.prank(_owner);
        authority.migrateHistoryToConsensus(_newConsensus);
    }

    function testSubmitClaim(
        address _owner,
        IHistory _history,
        bytes calldata _claim
    ) public isMockable(address(_history)) {
        vm.assume(_owner != address(0));
        vm.assume(_owner != address(this));

        authority = new Authority(_owner);

        vm.prank(_owner);
        authority.setHistory(_history);

        vm.assume(address(_history) != address(authority));
        vm.mockCall(
            address(_history),
            abi.encodeWithSelector(IHistory.submitClaim.selector, _claim),
            ""
        );

        // will fail as not called from owner
        vm.expectRevert("Ownable: caller is not the owner");
        authority.submitClaim(_claim);

        vm.expectCall(
            address(_history),
            abi.encodeWithSelector(IHistory.submitClaim.selector, _claim)
        );

        // can only be called by owner
        vm.prank(_owner);
        authority.submitClaim(_claim);
    }

    function testSetHistory(
        address _owner,
        IHistory _history,
        IHistory _newHistory
    ) public {
        vm.assume(_owner != address(0));
        vm.assume(_owner != address(this));

        authority = new Authority(_owner);

        vm.prank(_owner);
        vm.expectEmit(false, false, false, true);
        emit NewHistory(_history);
        authority.setHistory(_history);

        // before setting new history
        assertEq(address(authority.getHistory()), address(_history));

        // set new history
        // will fail as not called from owner
        vm.expectRevert("Ownable: caller is not the owner");
        authority.setHistory(_newHistory);

        // can only be called by owner
        vm.prank(_owner);
        // expect event NewHistory
        vm.expectEmit(false, false, false, true);
        emit NewHistory(_newHistory);
        authority.setHistory(_newHistory);

        // after setting new history
        assertEq(address(authority.getHistory()), address(_newHistory));
    }

    function testGetClaim(
        address _owner,
        IHistory _history,
        address _dapp,
        bytes calldata _proofContext,
        bytes32 _r0,
        uint256 _r1,
        uint256 _r2
    ) public isMockable(address(_history)) {
        vm.assume(_owner != address(0));
        vm.assume(_owner != address(this));

        authority = new Authority(_owner);

        vm.prank(_owner);
        authority.setHistory(_history);

        // mocking history
        vm.assume(address(_history) != address(authority));
        vm.mockCall(
            address(_history),
            abi.encodeWithSelector(
                IHistory.getClaim.selector,
                _dapp,
                _proofContext
            ),
            abi.encode(_r0, _r1, _r2)
        );

        vm.expectCall(
            address(_history),
            abi.encodeWithSelector(
                IHistory.getClaim.selector,
                _dapp,
                _proofContext
            )
        );

        // perform call
        (bytes32 r0, uint256 r1, uint256 r2) = authority.getClaim(
            _dapp,
            _proofContext
        );

        // check result
        assertEq(_r0, r0);
        assertEq(_r1, r1);
        assertEq(_r2, r2);
    }

    // test behaviors when history reverts
    function testHistoryReverts(
        address _owner,
        IHistory _newHistory,
        address _dapp,
        bytes calldata _claim,
        address _consensus,
        bytes calldata _proofContext
    ) public {
        vm.assume(_owner != address(0));

        HistoryReverts historyR = new HistoryReverts();

        authority = new Authority(_owner);

        vm.prank(_owner);
        authority.setHistory(historyR);
        assertEq(address(authority.getHistory()), address(historyR));

        vm.expectRevert();
        vm.prank(_owner);
        authority.submitClaim(_claim);

        vm.expectRevert();
        vm.prank(_owner);
        authority.migrateHistoryToConsensus(_consensus);

        vm.expectRevert();
        authority.getClaim(_dapp, _proofContext);

        vm.prank(_owner);
        authority.setHistory(_newHistory);
        assertEq(address(authority.getHistory()), address(_newHistory));
    }

    function testJoin(address _owner, IHistory _history, address _dapp) public {
        vm.assume(_owner != address(0));

        authority = new Authority(_owner);

        vm.prank(_owner);
        authority.setHistory(_history);

        vm.expectEmit(false, false, false, true);
        emit ApplicationJoined(_dapp);

        vm.prank(_dapp);
        authority.join();
    }
}

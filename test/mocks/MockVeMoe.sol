// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IMasterChef} from "../../src/interfaces/IMasterChef.sol";

contract MockVeMoe {
    using EnumerableSet for EnumerableSet.UintSet;

    address public immutable masterChef;

    uint256 public getTotalVotes;
    mapping(uint256 => uint256) public getVotes;

    EnumerableSet.UintSet private _topPoolIds;

    constructor(address masterChef_) {
        masterChef = masterChef_;
    }

    function getTopPoolIds() public view returns (uint256[] memory) {
        return _topPoolIds.values();
    }

    function getTopPidsTotalVotes() public view returns (uint256) {
        uint256 totalVotes;

        for (uint256 i = 0; i < _topPoolIds.length(); i++) {
            totalVotes += getVotes[_topPoolIds.at(i)];
        }

        return totalVotes;
    }

    function getTotalWeight() public view returns (uint256) {
        return getTopPidsTotalVotes();
    }

    function getWeight(uint256 pid) public view returns (uint256) {
        return isInTopPoolIds(pid) ? getVotes[pid] : 0;
    }

    function isInTopPoolIds(uint256 pid) public view returns (bool) {
        return _topPoolIds.contains(pid);
    }

    function setTopPoolIds(uint256[] memory pids) public {
        require(pids.length <= 10, "VeMoe__TooManyPoolIds");

        uint256[] memory topPoolIds = _topPoolIds.values();

        IMasterChef(masterChef).updateAll(pids);
        IMasterChef(masterChef).updateAll(topPoolIds);

        for (uint256 i; i < topPoolIds.length; i++) {
            _topPoolIds.remove(topPoolIds[i]);
        }

        getTotalVotes = 0;
        for (uint256 i = 0; i < pids.length; i++) {
            getTotalVotes += getVotes[pids[i]];
            _topPoolIds.add(pids[i]);
        }
    }

    function setVotes(uint256 pid, uint256 votes) public {
        IMasterChef(masterChef).updateAll(_topPoolIds.values());

        getTotalVotes = getTotalVotes - getVotes[pid] + votes;
        getVotes[pid] = votes;
    }
}

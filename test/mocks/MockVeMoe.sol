// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract MockVeMoe {
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 public getTotalVotes;
    mapping(uint256 => uint256) public getVotes;

    EnumerableSet.UintSet private _topPoolIds;

    function getTopPoolIds() external view returns (uint256[] memory) {
        return _topPoolIds.values();
    }

    function getTopPidsTotalVotes() external view returns (uint256) {
        uint256 totalVotes;

        for (uint256 i = 0; i < _topPoolIds.length(); i++) {
            totalVotes += getVotes[_topPoolIds.at(i)];
        }

        return totalVotes;
    }

    function isInTopPoolIds(uint256 pid) external view returns (bool) {
        return _topPoolIds.contains(pid);
    }

    function setTopPoolIds(uint256[] memory pids) external {
        require(pids.length <= 10, "VeMoe__TooManyPoolIds");

        for (uint256 i = 0; i < pids.length; i++) {
            _topPoolIds.add(pids[i]);
        }
    }

    function setVotes(uint256 pid, uint256 votes) external {
        getTotalVotes += votes - getVotes[pid];

        getVotes[pid] = votes;
    }
}

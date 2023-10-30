// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockVeMoe {
    uint256 public getTotalVotes;
    mapping(uint256 => uint256) public getVotes;

    function setVotes(uint256 pid, uint256 votes) external {
        getTotalVotes += votes - getVotes[pid];

        getVotes[pid] = votes;
    }
}

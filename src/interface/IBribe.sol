// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IBribe {
    function onVote(address voter, uint256 pid, uint256 oldAmount, uint256 newAmount, uint256 totalSupply) external;
}

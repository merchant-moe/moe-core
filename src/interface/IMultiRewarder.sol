// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IMultiRewarder {
    function onModify(address account, uint256 pid, uint256 oldBalance, uint256 newBalance, uint256 totalSupply)
        external;
}

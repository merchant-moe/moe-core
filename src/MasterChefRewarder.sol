// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMasterChef} from "./interface/IMasterChef.sol";
import {SimpleRewarder} from "./SimpleRewarder.sol";

contract MasterChefRewarder is SimpleRewarder {
    error MasterChefRewarder__InvalidPid(uint256 pid);

    uint256 internal immutable _pid;

    constructor(IERC20 token, address caller, uint256 pid, address initialOwner)
        SimpleRewarder(token, caller, initialOwner)
    {
        _pid = pid;
    }

    function link(uint256 pid) public override {
        if (pid != _pid) revert MasterChefRewarder__InvalidPid(pid);

        super.link(pid);
    }

    function unlink(uint256 pid) public override {
        if (pid != _pid) revert MasterChefRewarder__InvalidPid(pid);

        super.unlink(pid);
    }

    function onModify(address account, uint256 pid, uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply)
        public
        override
    {
        if (pid != _pid) revert MasterChefRewarder__InvalidPid(pid);

        super.onModify(account, pid, oldBalance, newBalance, oldTotalSupply);
    }

    function _getTotalSupply() internal view override returns (uint256) {
        return IMasterChef(_caller).getTotalDeposit(_pid);
    }
}

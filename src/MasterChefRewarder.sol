// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMasterChefRewarder} from "./interface/IMasterChefRewarder.sol";
import {IMasterChef} from "./interface/IMasterChef.sol";
import {BaseRewarder, IBaseRewarder} from "./BaseRewarder.sol";

contract MasterChefRewarder is BaseRewarder, IMasterChefRewarder {
    Status internal _status;

    constructor(IERC20 token, address caller, uint256 pid, address initialOwner)
        BaseRewarder(token, caller, pid, initialOwner)
    {}

    function link(uint256 pid) public override {
        if (msg.sender != _caller) revert BaseRewarder__InvalidCaller();
        if (_status != Status.Unlinked) revert MasterChefRewarder__AlreadyLinked();
        if (pid != _pid) revert BaseRewarder__InvalidPid(pid);
        if (_isStopped) revert BaseRewarder__Stopped();

        _status = Status.Linked;
    }

    function unlink(uint256 pid) public override {
        if (msg.sender != _caller) revert BaseRewarder__InvalidCaller();
        if (pid != _pid) revert BaseRewarder__InvalidPid(pid);
        if (_status != Status.Linked) revert MasterChefRewarder__NotLinked();

        _status = Status.Stopped;
        _isStopped = true;
    }

    function stop() public pure override(IBaseRewarder, BaseRewarder) {
        revert MasterChefRewarder__UseUnlink();
    }

    function onModify(address account, uint256 pid, uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply)
        public
        override(BaseRewarder, IBaseRewarder)
    {
        if (_status != Status.Linked) revert MasterChefRewarder__NotLinked();

        BaseRewarder.onModify(account, pid, oldBalance, newBalance, oldTotalSupply);
    }

    function _getTotalSupply() internal view override returns (uint256) {
        return IMasterChef(_caller).getTotalDeposit(_pid);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IVeMoe} from "./interface/IVeMoe.sol";
import {BaseRewarder, IRewarder} from "./BaseRewarder.sol";

contract VeMoeRewarder is BaseRewarder {
    error VeMoeRewarder__InvalidPid(uint256 pid);

    uint256 internal immutable _pid;

    constructor(IERC20 token, address caller, uint256 pid, address initialOwner)
        BaseRewarder(token, caller, initialOwner)
    {
        _pid = pid;
    }

    function onModify(address account, uint256 pid, uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply)
        public
        override
    {
        if (pid != _pid) revert VeMoeRewarder__InvalidPid(pid);

        super.onModify(account, pid, oldBalance, newBalance, oldTotalSupply);
    }

    function _getTotalSupply() internal view override returns (uint256) {
        return IVeMoe(_caller).getBribesTotalVotes(IRewarder(this), _pid);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IVeMoe} from "./interface/IVeMoe.sol";
import {BaseRewarder} from "./BaseRewarder.sol";
import {IVeMoeRewarder} from "./interface/IVeMoeRewarder.sol";

contract VeMoeRewarder is BaseRewarder, IVeMoeRewarder {
    constructor(IERC20 token, address caller, uint256 pid, address initialOwner)
        BaseRewarder(token, caller, pid, initialOwner)
    {}

    function _getTotalSupply() internal view override returns (uint256) {
        return IVeMoe(_caller).getBribesTotalVotes(this, _pid);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IVeMoe} from "./interface/IVeMoe.sol";
import {BaseRewarder} from "./BaseRewarder.sol";
import {IVeMoeRewarder} from "./interface/IVeMoeRewarder.sol";

/**
 * @title VeMoe Rewarder Contract
 * @dev The VeMoeRewarder Contract is a contract that is used as a bribery system for the VeMoe contract.
 * Protocols can bribe users to vote on their pools by distributing rewards to veMoe stakers of their pools.
 */
contract VeMoeRewarder is BaseRewarder, IVeMoeRewarder {
    /**
     * @dev Constructor for VeMoeRewarder contract.
     * @param token The token to be distributed as rewards.
     * @param caller The address of the contract that will call the onModify function.
     * @param pid The pool ID of the staking pool.
     * @param initialOwner The initial owner of the contract.
     */
    constructor(IERC20 token, address caller, uint256 pid, address initialOwner)
        BaseRewarder(token, caller, pid, initialOwner)
    {}

    /**
     * @dev Gets the total votes of this bribe contract.
     * @return The total votes of this bribe contract.
     */
    function _getTotalSupply() internal view override returns (uint256) {
        return IVeMoe(_caller).getBribesTotalVotes(this, _pid);
    }
}

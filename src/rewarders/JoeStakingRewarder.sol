// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IJoeStakingRewarder} from "../interfaces/IJoeStakingRewarder.sol";
import {IJoeStaking} from "../interfaces/IJoeStaking.sol";
import {BaseRewarder, IBaseRewarder} from "./BaseRewarder.sol";

/**
 * @title JoeStaking Rewarder Contract
 * @dev Contract for distributing rewards to stakers in the JoeStaking contract.
 */
contract JoeStakingRewarder is BaseRewarder, IJoeStakingRewarder {
    /**
     * @dev Constructor for JoeStakingRewarder contract.
     * @param token The token to be distributed as rewards.
     * @param caller The address of the contract that will call the onModify function.
     * @param initialOwner The initial owner of the contract.
     */
    constructor(IERC20 token, address caller, address initialOwner) BaseRewarder(token, caller, 0, initialOwner) {}

    /**
     * @dev Returns the total supply of the staking pool.
     * @return The total supply of the staking pool.
     */
    function _getTotalSupply() internal view override returns (uint256) {
        return IJoeStaking(_caller).getTotalDeposit();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
     * @param caller The address of the contract that will call the onModify function.
     */
    constructor(address caller) BaseRewarder(caller) {}

    /**
     * @dev Called by the caller contract to update the rewards for a given account.
     * @param account The account to update rewards for.
     * @param pid The pool ID of the staking pool.
     * @param oldBalance The old balance of the account.
     * @param newBalance The new balance of the account.
     * @param oldTotalSupply The old total supply of the staking pool.
     * @return reward The amount of rewards sent to the account.
     */
    function onModify(address account, uint256 pid, uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply)
        public
        override(BaseRewarder, IBaseRewarder)
        returns (uint256 reward)
    {
        reward = BaseRewarder.onModify(account, pid, oldBalance, newBalance, oldTotalSupply);

        _claim(account, reward);
    }

    /**
     * @dev Returns the total supply of the staking pool.
     * @return The total supply of the staking pool.
     */
    function _getTotalSupply() internal view override returns (uint256) {
        return IJoeStaking(_caller).getRewarder() == this ? IJoeStaking(_caller).getTotalDeposit() : 0;
    }
}

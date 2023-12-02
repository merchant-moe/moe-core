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
    IERC20 private immutable _immutableToken;

    /**
     * @dev Constructor for JoeStakingRewarder contract.
     * @param token The token to be distributed as rewards.
     * @param caller The address of the contract that will call the onModify function.
     * @param initialOwner The initial owner of the contract.
     */
    constructor(IERC20 token, address caller, address initialOwner) BaseRewarder(caller) {
        _immutableToken = token;

        initialize(initialOwner);
    }

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
     * @dev Reverts if the contract receives native tokens.
     */
    function _nativeReceived() internal pure override {
        revert BaseRewarder__NotNativeRewarder();
    }

    /**
     * @dev Returns the address of the token to be distributed as rewards.
     * @return The address of the token to be distributed as rewards.
     */
    function _token() internal view override returns (IERC20) {
        return _immutableToken;
    }

    /**
     * @dev Returns the pool ID of the staking pool.
     * @return The pool ID.
     */
    function _pid() internal pure override returns (uint256) {
        return 0;
    }

    /**
     * @dev Returns the total supply of the staking pool.
     * @return The total supply of the staking pool.
     */
    function _getTotalSupply() internal view override returns (uint256) {
        return IJoeStaking(_caller).getTotalDeposit();
    }
}

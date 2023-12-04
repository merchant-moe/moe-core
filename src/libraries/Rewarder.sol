// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Amounts} from "./Amounts.sol";
import {Constants} from "./Constants.sol";

/**
 * @title Rewarder Library
 * @dev A library that defines various functions for calculating rewards.
 * It takes care about the reward debt and the accumulated debt per share.
 */
library Rewarder {
    using Amounts for Amounts.Parameter;

    struct Parameter {
        uint256 lastUpdateTimestamp;
        uint256 accDebtPerShare;
        mapping(address => uint256) debt;
    }

    /**
     * @dev Returns the debt associated with an amount.
     * @param accDebtPerShare The accumulated debt per share.
     * @param deposit The amount.
     * @return The debt associated with the amount.
     */
    function getDebt(uint256 accDebtPerShare, uint256 deposit) internal pure returns (uint256) {
        return (deposit * accDebtPerShare) >> Constants.ACC_PRECISION_BITS;
    }

    /**
     * @dev Returns the debt per share associated with a total deposit and total rewards.
     * @param totalDeposit The total deposit.
     * @param totalRewards The total rewards.
     * @return The debt per share associated with the total deposit and total rewards.
     */
    function getDebtPerShare(uint256 totalDeposit, uint256 totalRewards) internal pure returns (uint256) {
        return totalDeposit == 0 ? 0 : (totalRewards << Constants.ACC_PRECISION_BITS) / totalDeposit;
    }

    /**
     * @dev Returns the total rewards to emit.
     * If the end timestamp is in the past, the rewards are calculated up to the end timestamp.
     * If the last update timestamp is in the future, it will return 0.
     * @param rewarder The storage pointer to the rewarder.
     * @param rewardPerSecond The reward per second.
     * @param endTimestamp The end timestamp.
     * @param totalSupply The total supply.
     * @return The total rewards.
     */
    function getTotalRewards(
        Parameter storage rewarder,
        uint256 rewardPerSecond,
        uint256 endTimestamp,
        uint256 totalSupply
    ) internal view returns (uint256) {
        if (totalSupply == 0) return 0;

        uint256 lastUpdateTimestamp = rewarder.lastUpdateTimestamp;
        uint256 timestamp = block.timestamp > endTimestamp ? endTimestamp : block.timestamp;

        return timestamp > lastUpdateTimestamp ? (timestamp - lastUpdateTimestamp) * rewardPerSecond : 0;
    }

    /**
     * @dev Returns the total rewards to emit.
     * @param rewarder The storage pointer to the rewarder.
     * @param rewardPerSecond The reward per second.
     * @param totalSupply The total supply.
     * @return The total rewards.
     */
    function getTotalRewards(Parameter storage rewarder, uint256 rewardPerSecond, uint256 totalSupply)
        internal
        view
        returns (uint256)
    {
        return getTotalRewards(rewarder, rewardPerSecond, block.timestamp, totalSupply);
    }

    /**
     * @dev Returns the pending reward of an account.
     * @param rewarder The storage pointer to the rewarder.
     * @param amounts The storage pointer to the amounts.
     * @param account The address of the account.
     * @param totalRewards The total rewards.
     * @return The pending reward of the account.
     */
    function getPendingReward(
        Parameter storage rewarder,
        Amounts.Parameter storage amounts,
        address account,
        uint256 totalRewards
    ) internal view returns (uint256) {
        return getPendingReward(rewarder, account, amounts.getAmountOf(account), amounts.getTotalAmount(), totalRewards);
    }

    /**
     * @dev Returns the pending reward of an account.
     * If the balance of the account is 0, it will always return 0.
     * @param rewarder The storage pointer to the rewarder.
     * @param account The address of the account.
     * @param balance The balance of the account.
     * @param totalSupply The total supply.
     * @param totalRewards The total rewards.
     * @return The pending reward of the account.
     */
    function getPendingReward(
        Parameter storage rewarder,
        address account,
        uint256 balance,
        uint256 totalSupply,
        uint256 totalRewards
    ) internal view returns (uint256) {
        uint256 accDebtPerShare = rewarder.accDebtPerShare + getDebtPerShare(totalSupply, totalRewards);

        return balance == 0 ? 0 : getDebt(accDebtPerShare, balance) - rewarder.debt[account];
    }

    /**
     * @dev Updates the rewarder.
     * If the balance of the account is 0, it will always return 0.
     * @param rewarder The storage pointer to the rewarder.
     * @param account The address of the account.
     * @param oldBalance The old balance of the account.
     * @param newBalance The new balance of the account.
     * @param totalSupply The total supply.
     * @param totalRewards The total rewards.
     * @return rewards The rewards of the account.
     */
    function update(
        Parameter storage rewarder,
        address account,
        uint256 oldBalance,
        uint256 newBalance,
        uint256 totalSupply,
        uint256 totalRewards
    ) internal returns (uint256 rewards) {
        uint256 accDebtPerShare = updateAccDebtPerShare(rewarder, totalSupply, totalRewards);

        rewards = oldBalance == 0 ? 0 : getDebt(accDebtPerShare, oldBalance) - rewarder.debt[account];

        rewarder.debt[account] = getDebt(accDebtPerShare, newBalance);
    }

    /**
     * @dev Updates the accumulated debt per share.
     * If the last update timestamp is in the future, it will not update the last update timestamp.
     * @param rewarder The storage pointer to the rewarder.
     * @param totalSupply The total supply.
     * @param totalRewards The total rewards.
     * @return The accumulated debt per share.
     */
    function updateAccDebtPerShare(Parameter storage rewarder, uint256 totalSupply, uint256 totalRewards)
        internal
        returns (uint256)
    {
        uint256 debtPerShare = getDebtPerShare(totalSupply, totalRewards);

        if (block.timestamp > rewarder.lastUpdateTimestamp) rewarder.lastUpdateTimestamp = block.timestamp;

        return debtPerShare == 0 ? rewarder.accDebtPerShare : rewarder.accDebtPerShare += debtPerShare;
    }
}

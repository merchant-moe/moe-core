// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {SafeMath} from "./SafeMath.sol";

import {Amounts} from "./Amounts.sol";
import {Constants} from "./Constants.sol";

library Rewarder {
    using SafeMath for uint256;
    using Amounts for Amounts.Parameter;

    struct Parameter {
        uint256 totalDeposit;
        uint256 lastUpdateTimestamp;
        uint256 accDebtPerShare;
        mapping(address => uint256) debt;
    }

    function getDebt(uint256 accDebtPerShare, uint256 deposit) internal pure returns (uint256) {
        return (deposit * accDebtPerShare) >> Constants.ACC_PRECISION_BITS;
    }

    function getDebtPerShare(uint256 totalDeposit, uint256 totalRewards) internal pure returns (uint256) {
        return totalDeposit == 0 ? 0 : (totalRewards << Constants.ACC_PRECISION_BITS) / totalDeposit;
    }

    function getTotalRewards(Parameter storage rewarder, uint256 rewardPerSecond, uint256 endTimestamp)
        internal
        view
        returns (uint256)
    {
        uint256 lastUpdateTimestamp = rewarder.lastUpdateTimestamp;
        uint256 timestamp = block.timestamp > endTimestamp ? endTimestamp : block.timestamp;

        return lastUpdateTimestamp > timestamp ? 0 : (timestamp - lastUpdateTimestamp) * rewardPerSecond;
    }

    function getTotalRewards(Parameter storage rewarder, uint256 rewardPerSecond) internal view returns (uint256) {
        return getTotalRewards(rewarder, rewardPerSecond, block.timestamp);
    }

    function getPendingReward(
        Parameter storage rewarder,
        Amounts.Parameter storage amounts,
        address account,
        uint256 totalRewards
    ) internal view returns (uint256) {
        return getPendingReward(rewarder, account, amounts.getAmountOf(account), amounts.getTotalAmount(), totalRewards);
    }

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

    function updateAccDebtPerShare(Parameter storage rewarder, uint256 totalSupply, uint256 totalRewards)
        internal
        returns (uint256)
    {
        rewarder.lastUpdateTimestamp = block.timestamp;
        return rewarder.accDebtPerShare += getDebtPerShare(totalSupply, totalRewards);
    }
}

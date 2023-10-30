// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {SafeMath} from "./SafeMath.sol";

import {Bank} from "./Bank.sol";
import {Constants} from "./Constants.sol";

library Rewarder {
    using SafeMath for uint256;
    using Bank for Bank.Parameter;

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

    function getTotalRewards(Parameter storage rewarder, uint256 rewardPerSecond) internal view returns (uint256) {
        uint256 lastUpdateTimestamp = rewarder.lastUpdateTimestamp;
        return lastUpdateTimestamp > block.timestamp ? 0 : (block.timestamp - lastUpdateTimestamp) * rewardPerSecond;
    }

    function getPendingReward(
        Parameter storage rewarder,
        Bank.Parameter storage bank,
        address account,
        uint256 totalRewards
    ) internal view returns (uint256) {
        uint256 accDebtPerShare = rewarder.accDebtPerShare + getDebtPerShare(bank.totalSupply, totalRewards);

        return getDebt(accDebtPerShare, bank.balances[account]) - rewarder.debt[account];
    }

    function update(
        Parameter storage rewarder,
        address account,
        uint256 oldBalance,
        uint256 newBalance,
        uint256 oldTotalSupply,
        uint256 totalRewards
    ) internal returns (uint256 rewards) {
        uint256 accDebtPerShare = updateAccDebtPerShare(rewarder, oldTotalSupply, totalRewards);

        rewards = getDebt(accDebtPerShare, oldBalance) - rewarder.debt[account];

        rewarder.debt[account] = getDebt(accDebtPerShare, newBalance);
    }

    function updateAccDebtPerShare(Parameter storage rewarder, uint256 oldTotalSupply, uint256 totalRewards)
        internal
        returns (uint256)
    {
        rewarder.lastUpdateTimestamp = block.timestamp;
        return rewarder.accDebtPerShare += getDebtPerShare(oldTotalSupply, totalRewards);
    }
}

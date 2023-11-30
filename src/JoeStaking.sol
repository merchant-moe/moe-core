// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Math} from "./libraries/Math.sol";
import {Amounts} from "./libraries/Amounts.sol";
import {IJoeStaking} from "./interfaces/IJoeStaking.sol";
import {IJoeStakingRewarder} from "./interfaces/IJoeStakingRewarder.sol";

/**
 * @title Joe Staking Contract
 * @dev The Joe Staking Contract allows users to stake JOE tokens to receive JOE tokens or other rewards.
 */
contract JoeStaking is IJoeStaking {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using Amounts for Amounts.Parameter;

    IERC20 private immutable _joe;
    IJoeStakingRewarder private immutable _rewarder;

    Amounts.Parameter private _amounts;

    /**
     * @dev Constructor for JoeStaking contract.
     * @param joe The JOE token.
     * @param rewarder The JOE Staking Rewarder contract.
     */
    constructor(IERC20 joe, IJoeStakingRewarder rewarder) {
        _joe = joe;
        _rewarder = rewarder;
    }

    /**
     * @dev Returns the JOE token.
     * @return The JOE token.
     */
    function getJoe() external view override returns (address) {
        return address(_joe);
    }

    /**
     * @dev Returns the JOE Staking Rewarder contract.
     * @return The JOE Staking Rewarder contract.
     */
    function getRewarder() external view override returns (address) {
        return address(_rewarder);
    }

    /**
     * @dev Returns the amount of JOE tokens staked by an account.
     * @param account The account to check.
     * @return The amount of JOE tokens staked by the account.
     */
    function getDeposit(address account) external view override returns (uint256) {
        return _amounts.getAmountOf(account);
    }

    /**
     * @dev Returns the total amount of JOE tokens staked.
     * @return The total amount of JOE tokens staked.
     */
    function getTotalDeposit() external view override returns (uint256) {
        return _amounts.getTotalAmount();
    }

    /**
     * @dev Returns the pending reward of an account.
     * @param account The account to check.
     * @return rewardToken The reward token.
     * @return rewardAmount The pending reward of the account.
     */
    function getPendingReward(address account)
        external
        view
        override
        returns (IERC20 rewardToken, uint256 rewardAmount)
    {
        return _rewarder.getPendingReward(account, _amounts.getAmountOf(account), _amounts.getTotalAmount());
    }

    /**
     * @dev Stakes JOE tokens.
     * @param amount The amount of JOE tokens to stake.
     */
    function stake(uint256 amount) external override {
        _modify(msg.sender, amount.toInt256());

        if (amount > 0) _joe.safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @dev Unstakes JOE tokens.
     * @param amount The amount of JOE tokens to unstake.
     */
    function unstake(uint256 amount) external override {
        _modify(msg.sender, -amount.toInt256());

        if (amount > 0) _joe.safeTransfer(msg.sender, amount);
    }

    /**
     * @dev Claims rewards from the rewarder.
     */
    function claim() external override {
        _modify(msg.sender, 0);
    }

    /**
     * @dev Modifies the staking position of an account.
     * Will update the veJOE and sJOE positions of the account.
     * @param account The account to modify.
     * @param deltaAmount The delta amount to modify.
     */
    function _modify(address account, int256 deltaAmount) private {
        (uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply,) = _amounts.update(account, deltaAmount);

        _rewarder.onModify(account, 0, oldBalance, newBalance, oldTotalSupply);

        emit PositionModified(account, deltaAmount);
    }
}

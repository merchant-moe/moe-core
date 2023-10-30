// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {SafeMath} from "./library/SafeMath.sol";
import {Rewarder} from "./library/Rewarder.sol";
import {Bank} from "./library/Bank.sol";
import {Constants} from "./library/Constants.sol";
import {IRewarder} from "./interface/IRewarder.sol";
import {IMasterChef} from "./interface/IMasterChef.sol";

contract VeMoe {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Rewarder for Rewarder.Parameter;
    using Bank for Bank.Parameter;

    error VeMoe__InvalidLength();

    event Modify(address indexed account, int256 deltaAmount, int256 deltaVeMoe);
    event Claim(address indexed account, address[] tokens, uint256[] rewards);

    struct User {
        uint256 veMoe;
        uint256 lastUpdateTimestamp;
        uint256 boostedEndTimestamp;
        uint256 totalVotes;
    }

    struct VeRewarder {
        Bank.Parameter bank;
        Rewarder.Parameter rewarder;
    }

    struct Reward {
        Rewarder.Parameter rewarder;
        IERC20 token;
        uint256 reserve;
    }

    struct VoteParameter {
        Bank.Parameter bank;
        IRewarder optionalRewarder;
    }

    IERC20 private immutable _moe;
    IMasterChef private immutable _masterChef;

    uint256 private _veMoePerSecond;

    uint256 private _boostedVeMoeMultiplier;
    uint256 private _boostedVeMoeDuration;
    uint256 private _boostedVeMoeRequirement;

    uint256 private _maxVeMoePerMoe;

    uint256 private _totalVotes;

    VeRewarder private _veRewarder;
    Reward[] private _rewards;

    // pid to Vote
    mapping(uint256 => VoteParameter) private _votes;
    mapping(address => User) private _users;

    constructor(IERC20 moe, IMasterChef masterChef) {
        _moe = moe;
        _masterChef = masterChef;
    }

    function getVeMoe(address account) external view returns (uint256) {
        User storage user = _users[account];
        VeRewarder storage veRewarder = _veRewarder;

        Rewarder.Parameter storage rewarder = veRewarder.rewarder;

        uint256 totalAddedVeAmount = rewarder.getTotalRewards(_veMoePerSecond);
        uint256 pendingVeAmount = rewarder.getPendingReward(veRewarder.bank, account, totalAddedVeAmount);

        uint256 boostedEndTimestamp = user.boostedEndTimestamp;
        if (boostedEndTimestamp != 0) {
            uint256 boostedVeAmount = pendingVeAmount * _boostedVeMoeMultiplier / Constants.PRECISION;

            if (block.timestamp > boostedEndTimestamp) {
                uint256 lastUpdateTimestamp = user.lastUpdateTimestamp;

                uint256 remaining = boostedEndTimestamp - lastUpdateTimestamp;
                uint256 duration = block.timestamp - lastUpdateTimestamp;

                boostedVeAmount = boostedVeAmount * remaining / duration;
            }

            pendingVeAmount += boostedVeAmount;
        }

        uint256 newVeMoe = user.veMoe + pendingVeAmount;
        uint256 maxVeMoe = veRewarder.bank.balances[account] * _maxVeMoePerMoe / Constants.PRECISION;

        return newVeMoe > maxVeMoe ? maxVeMoe : newVeMoe;
    }

    function getVeMoeParameters()
        external
        view
        returns (
            uint256 veMoePerSecond,
            uint256 boostedVeMoeMultiplier,
            uint256 boostedVeMoeDuration,
            uint256 boostedVeMoeRequirement,
            uint256 maxVeMoePerMoe
        )
    {
        return
            (_veMoePerSecond, _boostedVeMoeMultiplier, _boostedVeMoeDuration, _boostedVeMoeRequirement, _maxVeMoePerMoe);
    }

    function getTotalDeposit() external view returns (uint256) {
        return _veRewarder.bank.totalSupply;
    }

    function getVote(uint256 pid) external view returns (uint256) {
        return _votes[pid].bank.totalSupply;
    }

    function getTotalVotes() external view returns (uint256) {
        return _totalVotes;
    }

    function stake(uint256 amount) external {
        _modify(msg.sender, int256(amount));

        if (amount > 0) _moe.safeTransferFrom(msg.sender, address(this), amount);
    }

    function unstake(uint256 amount) external {
        _modify(msg.sender, -int256(amount));

        if (amount > 0) _moe.safeTransfer(msg.sender, amount);
    }

    function claim() external {
        _modify(msg.sender, 0);
    }

    function _modify(address account, int256 deltaAmount) private {
        (uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply, uint256 newTotalSupply) =
            _updateUser(account, deltaAmount);

        _claim(account, oldBalance, newBalance, oldTotalSupply, newTotalSupply);
    }

    function _updateUser(address account, int256 deltaAmount)
        private
        returns (uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply, uint256 newTotalSupply)
    {
        User storage user = _users[account];
        Rewarder.Parameter storage rewarder = _veRewarder.rewarder;

        (oldBalance, newBalance, oldTotalSupply, newTotalSupply) = _veRewarder.bank.update(account, deltaAmount);

        uint256 totalAddedVeAmount = rewarder.getTotalRewards(_veMoePerSecond);
        uint256 addedVeAmount = rewarder.update(account, oldBalance, newBalance, oldTotalSupply, totalAddedVeAmount);

        uint256 newVeMoe;
        int256 deltaVeMoe;

        if (deltaAmount >= 0) {
            uint256 boostedEndTimestamp = user.boostedEndTimestamp;
            if (boostedEndTimestamp != 0) {
                uint256 boostedVeAmount = addedVeAmount * _boostedVeMoeMultiplier / Constants.PRECISION;

                if (block.timestamp > boostedEndTimestamp) {
                    uint256 remaining = boostedEndTimestamp - user.lastUpdateTimestamp;
                    uint256 duration = block.timestamp - user.lastUpdateTimestamp;

                    boostedVeAmount = boostedVeAmount * remaining / duration;
                    user.boostedEndTimestamp = 0;
                }

                addedVeAmount += boostedVeAmount;
            }

            if (newBalance >= oldBalance * _boostedVeMoeRequirement / Constants.PRECISION) {
                uint256 newBoostedEndTimestamp = block.timestamp + _boostedVeMoeDuration;
                if (newBoostedEndTimestamp > boostedEndTimestamp) user.boostedEndTimestamp = newBoostedEndTimestamp;
            }

            uint256 oldVeMoe = user.veMoe;
            newVeMoe = oldVeMoe + addedVeAmount;

            uint256 maxVeMoe = newBalance * _maxVeMoePerMoe / Constants.PRECISION;

            newVeMoe = newVeMoe > maxVeMoe ? maxVeMoe : newVeMoe;

            deltaVeMoe = int256(newVeMoe - oldVeMoe);
        } else {
            newVeMoe = 0;
            deltaVeMoe = -int256(user.veMoe);

            user.boostedEndTimestamp = 0;
        }

        user.veMoe = newVeMoe;
        user.lastUpdateTimestamp = block.timestamp;

        emit Modify(account, deltaAmount, deltaVeMoe);
    }

    function _claim(
        address account,
        uint256 oldBalance,
        uint256 newBalance,
        uint256 oldTotalSupply,
        uint256 newTotalSupply
    ) private {
        uint256 length = _rewards.length;

        uint256[] memory allRewards = new uint256[](length);
        address[] memory allTokens = new address[](length);

        for (uint256 i; i < length; ++i) {
            Reward storage reward = _rewards[i];

            IERC20 token = reward.token;

            uint256 reserve = reward.reserve;
            uint256 balance = token.balanceOf(address(this)) - (token == _moe ? newTotalSupply : 0);

            uint256 totalRewards = balance - reserve;

            uint256 rewards = reward.rewarder.update(account, oldBalance, newBalance, oldTotalSupply, totalRewards);

            allRewards[i] = rewards;
            allTokens[i] = address(token);

            reward.reserve = balance - rewards;

            if (rewards > 0) token.safeTransfer(account, rewards);
        }

        emit Claim(account, allTokens, allRewards);
    }
}

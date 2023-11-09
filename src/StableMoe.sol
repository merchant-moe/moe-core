// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Math} from "./library/Math.sol";
import {Rewarder} from "./library/Rewarder.sol";
import {IMoeStaking} from "./interface/IMoeStaking.sol";
import {IStableMoe} from "./interface/IStableMoe.sol";

contract StableMoe is Ownable, IStableMoe {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using Rewarder for Rewarder.Parameter;
    using EnumerableSet for EnumerableSet.UintSet;

    IMoeStaking private immutable _moeStaking;

    EnumerableSet.UintSet private _activeRewardIds;

    mapping(IERC20 => uint256) private _rewardIds;
    Reward[] private _rewards;

    constructor(IMoeStaking moeStaking, address initialOwner) Ownable(initialOwner) {
        _moeStaking = moeStaking;
    }

    function getMoeStaking() external view returns (IMoeStaking) {
        return _moeStaking;
    }

    function getNumberOfRewards() external view returns (uint256) {
        return _rewards.length;
    }

    function getRewardToken(uint256 id) external view returns (IERC20) {
        return _rewards[id].token;
    }

    function getActiveRewardTokens() external view returns (IERC20[] memory) {
        uint256 length = _activeRewardIds.length();

        IERC20[] memory tokens = new IERC20[](length);

        for (uint256 i; i < length; ++i) {
            tokens[i] = _rewards[_activeRewardIds.at(i)].token;
        }

        return tokens;
    }

    function getPendingRewards(address account)
        external
        view
        returns (IERC20[] memory tokens, uint256[] memory rewards)
    {
        uint256 length = _activeRewardIds.length();

        tokens = new IERC20[](length);
        rewards = new uint256[](length);

        uint256 totalSupply = _moeStaking.getTotalDeposit();
        uint256 balance = _moeStaking.getDeposit(account);

        for (uint256 i; i < length; ++i) {
            Reward storage reward = _rewards[_activeRewardIds.at(i)];

            uint256 totalRewards = reward.token.balanceOf(address(this)) - reward.reserve;

            tokens[i] = reward.token;
            rewards[i] = reward.rewarder.getPendingReward(account, balance, totalSupply, totalRewards);
        }
    }

    function claim(address account) external {
        uint256 balance = _moeStaking.getDeposit(account);
        uint256 totalSupply = _moeStaking.getTotalDeposit();

        _claim(account, balance, balance, totalSupply);
    }

    function onModify(address account, uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply, uint256)
        external
    {
        if (msg.sender != address(_moeStaking)) revert StableMoe__UnauthorizedCaller();

        _claim(account, oldBalance, newBalance, oldTotalSupply);
    }

    function addReward(IERC20 reward) external onlyOwner {
        if (_rewardIds[reward] != 0) revert StableMoe__RewardAlreadyAdded(reward);

        uint256 id = _rewards.length;

        _activeRewardIds.add(id);
        _rewardIds[reward] = id + 1;

        Reward storage _reward = _rewards.push();

        _reward.token = reward;

        emit AddReward(reward);
    }

    function removeReward(IERC20 reward) external onlyOwner {
        uint256 id = _rewardIds[reward];

        if (id == 0) revert StableMoe__RewardNotAdded(reward);
        if (_activeRewardIds.contains(id - 1)) revert StableMoe__RewardAlreadyRemoved(reward);

        _activeRewardIds.remove(id - 1);

        emit RemoveReward(reward);
    }

    function sweep(IERC20 token, address account) external onlyOwner {
        uint256 id = _rewardIds[token];

        if (_activeRewardIds.contains(id - 1)) revert StableMoe__ActiveReward(token);

        token.safeTransfer(account, token.balanceOf(address(this)));

        emit Sweep(token, account);
    }

    function _claim(address account, uint256 oldBalance, uint256 newBalance, uint256 totalSupply) private {
        uint256 length = _activeRewardIds.length();

        for (uint256 i; i < length; ++i) {
            Reward storage reward = _rewards[_activeRewardIds.at(i)];

            IERC20 token = reward.token;

            uint256 reserve = reward.reserve;
            uint256 balance = token.balanceOf(address(this));

            uint256 totalRewards = balance - reserve;

            uint256 rewards = reward.rewarder.update(account, oldBalance, newBalance, totalSupply, totalRewards);

            reward.reserve = balance - rewards;

            if (rewards > 0) token.safeTransfer(account, rewards);

            emit Claim(account, token, rewards);
        }
    }
}

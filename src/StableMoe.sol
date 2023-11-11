// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {
    Ownable2StepUpgradeable,
    OwnableUpgradeable,
    Initializable
} from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

import {Math} from "./library/Math.sol";
import {Rewarder} from "./library/Rewarder.sol";
import {IMoeStaking} from "./interface/IMoeStaking.sol";
import {IStableMoe} from "./interface/IStableMoe.sol";
import {Constants} from "./library/Constants.sol";

/**
 * @title StableMoe Contract
 * @dev The StableMoe Contract allows users to claim rewards from the volume of the DEX.
 * The protocol fees will be swapped to the reward tokens and distributed to MOE stakers.
 */
contract StableMoe is Ownable2StepUpgradeable, IStableMoe {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using Rewarder for Rewarder.Parameter;
    using EnumerableSet for EnumerableSet.UintSet;

    IMoeStaking private immutable _moeStaking;

    EnumerableSet.UintSet private _activeRewardIds;

    mapping(IERC20 => uint256) private _rewardIds;
    Reward[] private _rewards;

    /**
     * @dev Constructor for StableMoe contract.
     * @param moeStaking The MOE Staking contract.
     */
    constructor(IMoeStaking moeStaking) {
        _disableInitializers();

        _moeStaking = moeStaking;
    }

    /**
     * @dev Initializes the StableMoe contract.
     * @param initialOwner The initial owner of the contract.
     */
    function initialize(address initialOwner) external initializer {
        __Ownable_init(initialOwner);
    }

    /**
     * @dev Receive function to allow the contract to receive native tokens.
     */
    receive() external payable {}

    /**
     * @dev Returns the MOE Staking contract.
     * @return The MOE Staking contract.
     */
    function getMoeStaking() external view returns (IMoeStaking) {
        return _moeStaking;
    }

    /**
     * @dev Returns the number of rewards.
     * @return The number of rewards tokens.
     */
    function getNumberOfRewards() external view returns (uint256) {
        return _rewards.length;
    }

    /**
     * @dev Returns the reward with the specified ID.
     * @param id The ID of the reward.
     * @return The reward token.
     */
    function getRewardToken(uint256 id) external view returns (IERC20) {
        return _rewards[id].token;
    }

    /**
     * @dev Returns the active rewards tokens.
     * @return tokens The active rewards tokens.
     */
    function getActiveRewardTokens() external view returns (IERC20[] memory tokens) {
        uint256 length = _activeRewardIds.length();

        tokens = new IERC20[](length);

        for (uint256 i; i < length; ++i) {
            tokens[i] = _rewards[_activeRewardIds.at(i) - 1].token;
        }
    }

    /**
     * @dev Returns the pending rewards for a given account.
     * @param account The account to check.
     * @return tokens The reward tokens.
     * @return rewards The pending rewards.
     */
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
            Reward storage reward = _rewards[_activeRewardIds.at(i) - 1];

            uint256 totalRewards = _balanceOfThis(reward.token) - reward.reserve;

            tokens[i] = reward.token;
            rewards[i] = reward.rewarder.getPendingReward(account, balance, totalSupply, totalRewards);
        }
    }

    /**
     * @dev Claims the pending rewards of the user.
     */
    function claim() external {
        uint256 balance = _moeStaking.getDeposit(msg.sender);
        uint256 totalSupply = _moeStaking.getTotalDeposit();

        _claim(msg.sender, balance, balance, totalSupply);
    }

    /**
     * @dev Called by the MOE Staking contract to update the rewards for a given account.
     * @param account The account to update rewards for.
     * @param oldBalance The old balance of the account.
     * @param newBalance The new balance of the account.
     * @param oldTotalSupply The old total supply of the staking pool.
     */
    function onModify(address account, uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply, uint256)
        external
    {
        if (msg.sender != address(_moeStaking)) revert StableMoe__UnauthorizedCaller();

        _claim(account, oldBalance, newBalance, oldTotalSupply);
    }

    /**
     * @dev Adds a reward token.
     * A reward token can be added only once.
     * @param reward The reward token to add.
     */
    function addReward(IERC20 reward) external onlyOwner {
        if (_rewardIds[reward] != 0) revert StableMoe__RewardAlreadyAdded(reward);
        if (_activeRewardIds.length() >= Constants.MAX_NUMBER_OF_REWARDS) revert StableMoe__TooManyActiveRewards();

        Reward storage _reward = _rewards.push();
        _reward.token = reward;

        uint256 id = _rewards.length;

        _activeRewardIds.add(id);
        _rewardIds[reward] = id;

        emit AddReward(reward);
    }

    /**
     * @dev Removes a reward token from the active rewards.
     * @param reward The reward token to remove.
     */
    function removeReward(IERC20 reward) external onlyOwner {
        uint256 id = _rewardIds[reward];

        if (!_activeRewardIds.remove(id)) revert StableMoe__RewardAlreadyRemoved(reward);

        emit RemoveReward(reward);
    }

    /**
     * @dev Sweeps the balance of a token to an account.
     * Can only be a token that is not in the active reward.
     * @param token The token to sweep.
     * @param account The account to sweep the balance to.
     */
    function sweep(IERC20 token, address account) external onlyOwner {
        uint256 id = _rewardIds[token];

        if (_activeRewardIds.contains(id)) revert StableMoe__ActiveReward(token);

        _safeTransferTo(token, account, _balanceOfThis(token));

        emit Sweep(token, account);
    }

    /**
     * @dev Returns the balance of the specified token held by the contract.
     * @param token The token to check the balance of.
     * @return The balance of the token held by the contract.
     */
    function _balanceOfThis(IERC20 token) internal view virtual returns (uint256) {
        return address(token) == address(0) ? address(this).balance : token.balanceOf(address(this));
    }

    /**
     * @dev Claims the rewards for a given account.
     * @param account The account to claim rewards for.
     * @param oldBalance The old balance of the account.
     * @param newBalance The new balance of the account.
     * @param totalSupply The total supply.
     */
    function _claim(address account, uint256 oldBalance, uint256 newBalance, uint256 totalSupply) private {
        uint256 length = _activeRewardIds.length();

        for (uint256 i; i < length; ++i) {
            Reward storage reward = _rewards[_activeRewardIds.at(i) - 1];

            IERC20 token = reward.token;

            uint256 reserve = reward.reserve;
            uint256 balance = _balanceOfThis(token);

            uint256 totalRewards = balance - reserve;

            uint256 rewards = reward.rewarder.update(account, oldBalance, newBalance, totalSupply, totalRewards);

            reward.reserve = balance - rewards;

            _safeTransferTo(token, account, rewards);

            emit Claim(account, token, rewards);
        }
    }

    /**
     * @dev Safely transfers the specified amount of tokens to an account.
     * @param token The token to transfer.
     * @param account The account to transfer the tokens to.
     * @param amount The amount of tokens to transfer.
     */
    function _safeTransferTo(IERC20 token, address account, uint256 amount) internal virtual {
        if (amount == 0) return;

        if (address(token) == address(0)) {
            (bool s,) = account.call{value: amount}("");
            if (!s) revert StableMoe__NativeTransferFailed();
        } else {
            token.safeTransfer(account, amount);
        }
    }
}

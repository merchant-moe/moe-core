// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Math} from "../libraries/Math.sol";
import {Rewarder} from "../libraries/Rewarder.sol";
import {IBaseRewarder} from "../interfaces/IBaseRewarder.sol";

/**
 * @title Base Rewarder Contract
 * @dev Base contract for reward distribution to stakers.
 */
abstract contract BaseRewarder is Ownable2Step, IBaseRewarder {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using Rewarder for Rewarder.Parameter;

    IERC20 internal immutable _token;
    address internal immutable _caller;
    uint256 internal immutable _pid;

    uint256 internal _rewardsPerSecond;
    uint256 internal _totalUnclaimedRewards;
    uint256 internal _reserve;
    uint256 internal _endTimestamp;
    bool internal _isStopped;

    Rewarder.Parameter internal _rewarder;

    /**
     * @dev Constructor for BaseRewarder contract.
     * @param token The token to be distributed as rewards.
     * @param caller The address of the contract that will call the onModify function.
     * @param pid The pool ID of the staking pool.
     * @param initialOwner The initial owner of the contract.
     */
    constructor(IERC20 token, address caller, uint256 pid, address initialOwner) Ownable(initialOwner) {
        _token = token;
        _caller = caller;
        _pid = pid;
    }

    /**
     * @dev Allows the contract to receive native tokens only if the token is address(0).
     */
    receive() external payable {
        if (address(_token) != address(0)) revert BaseRewarder__NotNativeRewarder();
    }

    /**
     * @dev Returns the address of the token to be distributed as rewards.
     * @return The address of the token to be distributed as rewards.
     */
    function getToken() public view virtual override returns (IERC20) {
        return _token;
    }

    /**
     * @dev Returns the address of the contract that calls the onModify function.
     * @return The address of the caller contract.
     */
    function getCaller() public view virtual override returns (address) {
        return _caller;
    }

    /**
     * @dev Returns the pool ID of the staking pool.
     * @return The pool ID.
     */
    function getPid() public view virtual override returns (uint256) {
        return _pid;
    }

    /**
     * @dev Returns the rewarder parameter values.
     * @return token The token to be distributed as rewards.
     * @return rewardPerSecond The reward per second.
     * @return lastUpdateTimestamp The last update timestamp.
     * @return endTimestamp The end timestamp.
     */
    function getRewarderParameter()
        public
        view
        virtual
        override
        returns (IERC20 token, uint256 rewardPerSecond, uint256 lastUpdateTimestamp, uint256 endTimestamp)
    {
        return (_token, _rewardsPerSecond, _rewarder.lastUpdateTimestamp, _endTimestamp);
    }

    /**
     * @dev Returns the pending rewards for a given account.
     * @param account The account to check for pending rewards.
     * @param balance The balance of the account.
     * @param totalSupply The total supply of the staking pool.
     * @return The token and the amount of pending rewards.
     */
    function getPendingReward(address account, uint256 balance, uint256 totalSupply)
        public
        view
        virtual
        override
        returns (IERC20, uint256)
    {
        uint256 totalRewards = _rewarder.getTotalRewards(_rewardsPerSecond, _endTimestamp);

        return (_token, _rewarder.getPendingReward(account, balance, totalSupply, totalRewards));
    }

    /**
     * @dev Returns whether the reward distribution has been stopped.
     * @return True if the reward distribution has been stopped, false otherwise.
     */
    function isStopped() public view virtual override returns (bool) {
        return _isStopped;
    }

    /**
     * @dev Sets the start of the reward distribution.
     * @param startTimestamp The start timestamp.
     */
    function setRewarderParameters(uint256 rewardPerSecond, uint256 startTimestamp, uint256 expectedDuration)
        public
        virtual
        onlyOwner
    {
        if (_isStopped) revert BaseRewarder__Stopped();
        if (startTimestamp < block.timestamp) revert BaseRewarder__InvalidStartTimestamp(startTimestamp);

        _setRewardParameters(rewardPerSecond, startTimestamp, expectedDuration);
    }

    /**
     * @dev Sets the reward per second and expected duration.
     * If the expected duration is 0, the reward distribution will be stopped.
     * @param rewardPerSecond The new reward per second.
     * @param expectedDuration The expected duration of the reward distribution.
     */
    function setRewardPerSecond(uint256 rewardPerSecond, uint256 expectedDuration) public virtual override onlyOwner {
        uint256 lastUpdateTimestamp = _rewarder.lastUpdateTimestamp;
        uint256 startTimestamp = lastUpdateTimestamp > block.timestamp ? lastUpdateTimestamp : block.timestamp;

        _setRewardParameters(rewardPerSecond, startTimestamp, expectedDuration);
    }

    /**
     * @dev Stops the reward distribution.
     */
    function stop() public virtual override onlyOwner {
        if (_isStopped) revert BaseRewarder__AlreadyStopped();

        _isStopped = true;
    }

    /**
     * @dev Transfers any remaining tokens to the specified account.
     * If the token is the reward token, only the excess amount will be transferred.
     * If the rewarder is stopped, the entire balance will be transferred.
     * @param token The token to transfer.
     * @param account The account to transfer the tokens to.
     */
    function sweep(IERC20 token, address account) public virtual override onlyOwner {
        uint256 balance = _balanceOfThis(token);

        if (!_isStopped && token == _token) balance -= _reserve;
        if (balance == 0) revert BaseRewarder__ZeroAmount();

        _safeTransferTo(token, account, balance);
    }

    /**
     * @dev Called by the caller contract to update the rewards for a given account.
     * @param account The account to update rewards for.
     * @param pid The pool ID of the staking pool.
     * @param oldBalance The old balance of the account.
     * @param newBalance The new balance of the account.
     * @param oldTotalSupply The old total supply of the staking pool.
     */
    function onModify(address account, uint256 pid, uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply)
        public
        virtual
        override
    {
        if (msg.sender != _caller) revert BaseRewarder__InvalidCaller();
        if (pid != _pid) revert BaseRewarder__InvalidPid(pid);
        if (_isStopped) revert BaseRewarder__Stopped();

        _claim(account, oldBalance, newBalance, oldTotalSupply);
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
     * @param oldTotalSupply The old total supply of the staking pool.
     */
    function _claim(address account, uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply) internal virtual {
        uint256 totalUnclaimedRewards = _totalUnclaimedRewards;
        uint256 reserve = _reserve;

        uint256 totalRewards = _rewarder.getTotalRewards(_rewardsPerSecond, _endTimestamp);
        uint256 rewards = _rewarder.update(account, oldBalance, newBalance, oldTotalSupply, totalRewards);

        _totalUnclaimedRewards = totalUnclaimedRewards + totalRewards - rewards;
        _reserve = reserve - rewards;

        _safeTransferTo(_token, account, rewards);

        emit Claim(account, _token, rewards);
    }

    /**
     * @dev Safely transfers the specified amount of tokens to the specified account.
     * @param token The token to transfer.
     * @param account The account to transfer the tokens to.
     * @param amount The amount of tokens to transfer.
     */
    function _safeTransferTo(IERC20 token, address account, uint256 amount) internal virtual {
        if (amount == 0) return;

        if (address(token) == address(0)) {
            (bool s,) = account.call{value: amount}("");
            if (!s) revert BaseRewarder__NativeTransferFailed();
        } else {
            token.safeTransfer(account, amount);
        }
    }

    /**
     * @dev Sets the reward parameters.
     * This will set the reward per second, the start timestamp, and the end timestamp.
     * If the expected duration is 0, the reward distribution will be stopped.
     * @param rewardPerSecond The new reward per second.
     * @param startTimestamp The start timestamp.
     * @param expectedDuration The expected duration of the reward distribution.
     */
    function _setRewardParameters(uint256 rewardPerSecond, uint256 startTimestamp, uint256 expectedDuration)
        internal
        virtual
    {
        if (_isStopped) revert BaseRewarder__Stopped();
        if (expectedDuration == 0 && rewardPerSecond != 0) revert BaseRewarder__InvalidDuration();

        uint256 totalUnclaimedRewards = _totalUnclaimedRewards;
        uint256 totalRewards = _rewarder.getTotalRewards(_rewardsPerSecond, _endTimestamp);

        totalUnclaimedRewards += totalRewards;

        uint256 remainingReward = _balanceOfThis(_token) - totalUnclaimedRewards;
        uint256 expectedReward = rewardPerSecond * expectedDuration;

        if (remainingReward < expectedReward) revert BaseRewarder__InsufficientReward(remainingReward, expectedReward);

        uint256 endTimestamp = startTimestamp + expectedDuration;
        uint256 totalSupply = _getTotalSupply();

        _rewardsPerSecond = rewardPerSecond;
        _reserve = totalUnclaimedRewards + expectedReward;

        _endTimestamp = endTimestamp;
        _totalUnclaimedRewards = totalUnclaimedRewards;

        _rewarder.updateAccDebtPerShare(totalSupply, totalRewards);

        if (startTimestamp != block.timestamp) _rewarder.lastUpdateTimestamp = startTimestamp;

        emit RewardParameterUpdated(rewardPerSecond, startTimestamp, endTimestamp);
    }

    /**
     * @dev Returns the total supply of the staking pool.
     * Used to calculate the rewards when setting the reward per second.
     * Must be implemented by child contracts.
     * @return The total supply of the staking pool.
     */
    function _getTotalSupply() internal view virtual returns (uint256);
}

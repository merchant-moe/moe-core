// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IMasterChef} from "./interface/IMasterChef.sol";
import {IMoe} from "./interface/IMoe.sol";
import {Math} from "./library/Math.sol";
import {Rewarder} from "./library/Rewarder.sol";
import {Amounts} from "./library/Amounts.sol";
import {IRewarder} from "./interface/IRewarder.sol";

abstract contract BaseRewarder is Ownable, IRewarder {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using Rewarder for Rewarder.Parameter;
    using Amounts for Amounts.Parameter;

    IERC20 internal immutable _token;
    address internal immutable _caller;

    uint256 internal _rewardsPerSecond;
    uint256 internal _totalUnclaimedRewards;
    uint256 internal _reserve;
    uint256 internal _endTimestamp;
    bool internal _isStopped;

    Rewarder.Parameter internal _rewarder;

    constructor(IERC20 token, address caller, address initialOwner) Ownable(initialOwner) {
        _token = token;
        _caller = caller;
    }

    receive() external payable {
        if (address(_token) != address(0)) revert Rewarder__NotNativeToken();
    }

    function getCaller() public view virtual override returns (address) {
        return _caller;
    }

    function getRewarderParameter()
        public
        view
        virtual
        override
        returns (IERC20 token, uint256 rewardPerSecond, uint256 lastUpdateTimestamp, uint256 endTimestamp)
    {
        return (_token, _rewardsPerSecond, _rewarder.lastUpdateTimestamp, _endTimestamp);
    }

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

    function isStopped() public view virtual override returns (bool) {
        return _isStopped;
    }

    function setRewardPerSecond(uint256 rewardPerSecond, uint256 expectedDuration) public virtual override onlyOwner {
        if (_isStopped) revert Rewarder__Stopped();
        if (expectedDuration == 0 && rewardPerSecond != 0) revert Rewarder__InvalidDuration();

        uint256 totalUnclaimedRewards = _totalUnclaimedRewards;
        uint256 totalRewards = _getTotalReward(_reserve, totalUnclaimedRewards);

        totalUnclaimedRewards += totalRewards;

        uint256 remainingReward = _balanceOfThis(_token) - totalUnclaimedRewards;
        uint256 expectedReward = rewardPerSecond * expectedDuration;

        if (remainingReward < expectedReward) revert Rewarder__InsufficientReward(remainingReward, expectedReward);

        uint256 totalSupply = _getTotalSupply();
        uint256 endTimestamp = block.timestamp + expectedDuration;

        _rewarder.updateAccDebtPerShare(totalSupply, totalRewards);

        _rewardsPerSecond = rewardPerSecond;
        _reserve = totalUnclaimedRewards + expectedReward;

        _endTimestamp = endTimestamp;
        _totalUnclaimedRewards = totalUnclaimedRewards;

        emit RewardPerSecondSet(rewardPerSecond, endTimestamp);
    }

    function stop() public virtual override onlyOwner {
        if (_isStopped) revert Rewarder__AlreadyStopped();

        _isStopped = true;
    }

    function sweep(IERC20 token, address account) public virtual override onlyOwner {
        if (!_isStopped && token == _token) revert Rewarder__InvalidToken();

        _safeTransferTo(token, account, _balanceOfThis(token));
    }

    function onModify(address account, uint256, uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply)
        public
        virtual
        override
    {
        if (msg.sender != _caller) revert Rewarder__InvalidCaller();
        if (_isStopped) revert Rewarder__Stopped();

        _claim(account, oldBalance, newBalance, oldTotalSupply);
    }

    function _balanceOfThis(IERC20 token) internal view virtual returns (uint256) {
        return address(token) == address(0) ? address(this).balance : token.balanceOf(address(this));
    }

    function _claim(address account, uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply) internal virtual {
        uint256 totalUnclaimedRewards = _totalUnclaimedRewards;
        uint256 reserve = _reserve;

        uint256 totalRewards = _getTotalReward(reserve, totalUnclaimedRewards);

        uint256 rewards = _rewarder.update(account, oldBalance, newBalance, oldTotalSupply, totalRewards);

        _totalUnclaimedRewards = totalUnclaimedRewards + totalRewards - rewards;
        _reserve = reserve - rewards;

        _safeTransferTo(_token, account, rewards);

        emit Claim(account, _token, rewards);
    }

    function _getTotalReward(uint256 reserve, uint256 totalUnclaimedRewards) internal view virtual returns (uint256) {
        uint256 totalRewards = _rewarder.getTotalRewards(_rewardsPerSecond, _endTimestamp);
        uint256 avalaibleRewards = reserve > totalUnclaimedRewards ? reserve - totalUnclaimedRewards : 0;

        return totalRewards > avalaibleRewards ? avalaibleRewards : totalRewards;
    }

    function _safeTransferTo(IERC20 token, address account, uint256 amount) internal virtual {
        if (amount == 0) return;

        if (address(token) == address(0)) {
            (bool s,) = account.call{value: amount}("");
            if (!s) revert Rewarder__NativeTransferFailed();
        } else {
            token.safeTransfer(account, amount);
        }
    }

    function _getTotalSupply() internal view virtual returns (uint256);
}

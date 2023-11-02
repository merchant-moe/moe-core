// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IMasterChef} from "./interface/IMasterChef.sol";
import {IMoe} from "./interface/IMoe.sol";
import {SafeMath} from "./library/SafeMath.sol";
import {Rewarder} from "./library/Rewarder.sol";
import {Constants} from "./library/Constants.sol";
import {Amounts} from "./library/Amounts.sol";

contract SimpleRewarder is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Rewarder for Rewarder.Parameter;
    using Amounts for Amounts.Parameter;

    error SimpleRewarder__NativeTransferFailed();
    error SimpleRewarder__InvalidCaller();
    error SimpleRewarder__AlreadyLinked();

    event Claim(address indexed account, address indexed token, uint256 reward);

    IERC20 private immutable _token;
    IMasterChef private immutable _masterChef;

    uint256 private _rewardsPerSecond;
    uint256 private _unclaimedRewards;
    uint256 private _reserve;
    uint256 private _endTimestamp;
    uint256 private _linkedPid;

    Rewarder.Parameter private _rewarder;

    constructor(IERC20 token, IMasterChef masterChef, address initialOwner) Ownable(initialOwner) {
        _token = token;
        _masterChef = masterChef;
    }

    function getRewarderParameter() external view returns (uint256 rewardPerSecond, uint256 endTimestamp) {
        return (_rewardsPerSecond, _endTimestamp);
    }

    function setRewardPerSecond(uint256 rewardPerSecond) external onlyOwner {
        uint256 totalRewards = _rewarder.getTotalRewards(_rewardsPerSecond);
        uint256 reserve = _reserve;

        totalRewards = totalRewards > reserve ? reserve : totalRewards;

        uint256 remainingReward = _balanceOfThis() - (_unclaimedRewards + totalRewards);
        uint256 duration = remainingReward / rewardPerSecond;

        uint256 linkedPid = _linkedPid;
        uint256 totalSupply = linkedPid == 0 ? 0 : _masterChef.getTotalDeposit(linkedPid - 1);

        _rewarder.updateAccDebtPerShare(totalSupply, totalRewards);

        _endTimestamp = block.timestamp + duration;
        _rewardsPerSecond = rewardPerSecond;
        _reserve = remainingReward;
    }

    function link(uint256 pid) external {
        if (msg.sender != address(_masterChef)) revert SimpleRewarder__InvalidCaller();
        if (_linkedPid != 0) revert SimpleRewarder__AlreadyLinked();

        _linkedPid = pid + 1;
    }

    function unlink() external {
        if (msg.sender != address(_masterChef)) revert SimpleRewarder__InvalidCaller();

        _endTimestamp = 0;
    }

    function claim(address account, uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply)
        external
        returns (IERC20 token, uint256 rewards)
    {
        if (msg.sender != address(_masterChef)) revert SimpleRewarder__InvalidCaller();

        rewards = _claim(account, oldBalance, newBalance, oldTotalSupply);

        return (_token, rewards);
    }

    function _claim(address account, uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply)
        private
        returns (uint256 rewards)
    {
        uint256 endTimestamp = _endTimestamp;

        if (block.timestamp > endTimestamp) {
            return _rewarder.update(account, oldBalance, newBalance, oldTotalSupply, 0);
        }

        uint256 totalRewards = _rewarder.getTotalRewards(_rewardsPerSecond);

        rewards = _rewarder.update(account, oldBalance, newBalance, oldTotalSupply, totalRewards);

        _unclaimedRewards += totalRewards - rewards;

        _safeTransferTo(account, rewards);
    }

    function _balanceOfThis() private view returns (uint256) {
        return address(_token) == address(0) ? address(this).balance : _token.balanceOf(address(this));
    }

    function _safeTransferTo(address account, uint256 amount) private {
        uint256 reserve = _reserve;
        amount = amount > reserve ? reserve : amount;

        if (amount == 0) return;

        if (address(_token) == address(0)) {
            (bool s,) = account.call{value: amount}("");
            if (!s) revert SimpleRewarder__NativeTransferFailed();
        } else {
            _token.safeTransfer(account, amount);
        }

        _reserve -= amount;
    }
}

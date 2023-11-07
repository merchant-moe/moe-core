// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IMasterChef} from "./interface/IMasterChef.sol";
import {IMoe} from "./interface/IMoe.sol";
import {SafeMath} from "./library/SafeMath.sol";
import {Rewarder} from "./library/Rewarder.sol";
import {Amounts} from "./library/Amounts.sol";
import {IRewarder} from "./interface/IRewarder.sol";

abstract contract SimpleRewarder is Ownable, IRewarder {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Rewarder for Rewarder.Parameter;
    using Amounts for Amounts.Parameter;

    IERC20 internal immutable _token;
    address internal immutable _caller;

    uint256 internal _rewardsPerSecond;
    uint256 internal _totalUnclaimedRewards;
    uint256 internal _reserve;
    uint256 internal _endTimestamp;
    Status internal _status;

    Rewarder.Parameter internal _rewarder;

    constructor(IERC20 token, address caller, address initialOwner) Ownable(initialOwner) {
        _token = token;
        _caller = caller;
    }

    receive() external payable {
        if (address(_token) != address(0)) revert Rewarder__NotNativeToken();
    }

    function getRewarderParameter()
        public
        view
        virtual
        returns (IERC20 token, uint256 rewardPerSecond, uint256 lastUpdateTimestamp, uint256 endTimestamp)
    {
        return (_token, _rewardsPerSecond, _rewarder.lastUpdateTimestamp, _endTimestamp);
    }

    function getPendingReward(address account, uint256 balance, uint256 totalSupply)
        public
        view
        virtual
        returns (IERC20, uint256)
    {
        uint256 totalRewards = _rewarder.getTotalRewards(_rewardsPerSecond, _endTimestamp);

        return (_token, _rewarder.getPendingReward(account, balance, totalSupply, totalRewards));
    }

    function setRewardPerSecond(uint256 rewardPerSecond) public virtual onlyOwner {
        if (_status == Status.Stopped) revert Rewarder__Stopped();

        uint256 totalUnclaimedRewards = _totalUnclaimedRewards;
        uint256 totalRewards = _getTotalReward(totalUnclaimedRewards);

        totalUnclaimedRewards += totalRewards;

        uint256 remainingReward = _balanceOfThis() - totalUnclaimedRewards;
        uint256 duration = remainingReward / rewardPerSecond;

        uint256 totalSupply = _getTotalSupply();

        _rewarder.updateAccDebtPerShare(totalSupply, totalRewards);

        _rewardsPerSecond = rewardPerSecond;
        _reserve = rewardPerSecond * duration;

        _endTimestamp = block.timestamp + duration;
        _totalUnclaimedRewards = totalUnclaimedRewards;
    }

    function emergencyWithdraw(address account) public virtual onlyOwner {
        if (_status != Status.Stopped) revert Rewarder__NotStopped();

        _reserve = 0;

        _safeTransferTo(account, _balanceOfThis());
    }

    function sweep(IERC20 token, address account) public virtual onlyOwner {
        if (token == _token) revert Rewarder__InvalidToken();

        token.safeTransfer(account, token.balanceOf(address(this)));
    }

    function link(uint256) public virtual {
        if (msg.sender != _caller) revert Rewarder__InvalidCaller();
        if (_status != Status.Unlinked) revert Rewarder__AlreadyLinked();

        _status = Status.Linked;
    }

    function unlink(uint256) public virtual {
        if (msg.sender != _caller) revert Rewarder__InvalidCaller();
        if (_status != Status.Linked) revert Rewarder__NotLinked();

        _status = Status.Stopped;
    }

    function onModify(address account, uint256, uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply)
        public
        virtual
    {
        if (msg.sender != _caller) revert Rewarder__InvalidCaller();
        if (_status != Status.Linked) revert Rewarder__NotLinked();

        _claim(account, oldBalance, newBalance, oldTotalSupply);
    }

    function _balanceOfThis() internal view virtual returns (uint256) {
        return address(_token) == address(0) ? address(this).balance : _token.balanceOf(address(this));
    }

    function _getTotalSupply() internal view virtual returns (uint256);

    function _claim(address account, uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply) internal virtual {
        uint256 totalUnclaimedRewards = _totalUnclaimedRewards;
        uint256 totalRewards = _getTotalReward(totalUnclaimedRewards);

        uint256 rewards = _rewarder.update(account, oldBalance, newBalance, oldTotalSupply, totalRewards);

        _totalUnclaimedRewards = totalUnclaimedRewards + totalRewards - rewards;

        _safeTransferTo(account, rewards);

        emit Claim(account, _token, rewards);
    }

    function _getTotalReward(uint256 totalUnclaimedRewards) internal view virtual returns (uint256) {
        uint256 totalRewards = _rewarder.getTotalRewards(_rewardsPerSecond, _endTimestamp);
        uint256 reserve = _reserve;

        uint256 avalaibleRewards = reserve > totalUnclaimedRewards ? reserve - totalUnclaimedRewards : 0;

        return totalRewards > avalaibleRewards ? avalaibleRewards : totalRewards;
    }

    function _safeTransferTo(address account, uint256 amount) internal virtual {
        if (amount == 0) return;

        if (address(_token) == address(0)) {
            (bool s,) = account.call{value: amount}("");
            if (!s) revert Rewarder__NativeTransferFailed();
        } else {
            _token.safeTransfer(account, amount);
        }

        _reserve -= amount;
    }
}

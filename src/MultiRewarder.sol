// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IMasterChef} from "./interface/IMasterChef.sol";
import {IMoe} from "./interface/IMoe.sol";
import {SafeMath} from "./library/SafeMath.sol";
import {Rewarder} from "./library/Rewarder.sol";
import {Constants} from "./library/Constants.sol";

contract MultiRewarder is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Rewarder for Rewarder.Parameter;

    error SimpleRewarder__NativeTransferFailed();
    error SimpleRewarder__InvalidCaller();
    error SimpleRewarder__AlreadyLinked();

    event Claim(address indexed account, uint256 pid, address indexed token, uint256 reward);

    struct Parameter {
        Rewarder.Parameter rewarder;
        IERC20 token;
        uint256 tokenPerSecond;
        uint256 endTimestamp;
        uint256 reserve;
        uint256 totalUnclaimedRewards;
    }

    address private immutable _veMoe;
    IMasterChef private immutable _masterChef;

    mapping(uint256 => Parameter) private _parameters;
    mapping(IERC20 => uint256) private _totalReserves;

    constructor(address veMoe, IMasterChef masterChef, address initialOwner) Ownable(initialOwner) {
        _veMoe = veMoe;
        _masterChef = masterChef;
    }

    function setRewardPerSecond(uint256 pid, uint256 rewardPerSecond) external onlyOwner {
        Parameter storage parameter = _parameters[pid];

        IERC20 token = parameter.token;

        uint256 totalRewards = parameter.rewarder.getTotalRewards(parameter.tokenPerSecond, parameter.endTimestamp);
        uint256 reserve = parameter.reserve;

        totalRewards = totalRewards > reserve ? reserve : totalRewards;

        uint256 unusedRewardBalance = _balanceOfThis(token) - _totalReserves[token];
        uint256 duration = unusedRewardBalance / rewardPerSecond;

        uint256 totalSupply = _masterChef.getTotalDeposit(pid);

        parameter.rewarder.updateAccDebtPerShare(totalSupply, totalRewards);

        parameter.endTimestamp = block.timestamp + duration;
        parameter.tokenPerSecond = rewardPerSecond;

        parameter.reserve += unusedRewardBalance;
        _totalReserves[token] += unusedRewardBalance;
    }

    function onModify(address account, uint256 pid, uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply)
        external
    {
        if (msg.sender != address(_veMoe)) revert SimpleRewarder__InvalidCaller();

        Parameter storage parameter = _parameters[pid];
        Rewarder.Parameter storage rewarder = parameter.rewarder;

        uint256 endTimestamp = parameter.endTimestamp;

        if (endTimestamp == 0) return;

        uint256 totalRewards = rewarder.getTotalRewards(parameter.tokenPerSecond, parameter.endTimestamp);
        uint256 accountRewards = rewarder.update(account, oldBalance, newBalance, oldTotalSupply, totalRewards);

        parameter.totalUnclaimedRewards += totalRewards - accountRewards;

        _safeTransferTo(account, parameter.token, accountRewards);
    }

    function _balanceOfThis(IERC20 token) private view returns (uint256) {
        return address(token) == address(0) ? address(this).balance : token.balanceOf(address(this));
    }

    function _safeTransferTo(address account, IERC20 token, uint256 amount) private {
        uint256 totalReserve = _totalReserves[token];
        amount = amount > totalReserve ? totalReserve : amount;

        if (amount == 0) return;

        if (address(token) == address(0)) {
            (bool s,) = account.call{value: amount}("");
            if (!s) revert SimpleRewarder__NativeTransferFailed();
        } else {
            token.safeTransfer(account, amount);
        }

        _totalReserves[token] -= amount;
    }
}

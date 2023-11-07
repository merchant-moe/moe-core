// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {SafeMath} from "./library/SafeMath.sol";
import {Rewarder} from "./library/Rewarder.sol";
import {Constants} from "./library/Constants.sol";
import {Amounts} from "./library/Amounts.sol";
import {IMoe} from "./interface/IMoe.sol";
import {IVeMoe} from "./interface/IVeMoe.sol";
import {IMasterChef} from "./interface/IMasterChef.sol";
import {IRewarder} from "./interface/IRewarder.sol";

contract MasterChef is Ownable, IMasterChef {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Rewarder for Rewarder.Parameter;
    using Amounts for Amounts.Parameter;

    IMoe private immutable _moe;
    IVeMoe private immutable _veMoe;

    uint256 private _moePerSecond;

    Farm[] private _farms;

    constructor(IMoe moe, IVeMoe veMoe, address initialOwner) Ownable(initialOwner) {
        _moe = moe;
        _veMoe = veMoe;
    }

    function getMoe() external view override returns (IMoe) {
        return _moe;
    }

    function getVeMoe() external view override returns (IVeMoe) {
        return _veMoe;
    }

    function getDeposit(uint256 pid, address account) external view override returns (uint256) {
        return _farms[pid].amounts.getAmountOf(account);
    }

    function getTotalDeposit(uint256 pid) external view override returns (uint256) {
        return _farms[pid].amounts.getTotalAmount();
    }

    function getPendingRewards(uint256 pid, address account)
        external
        view
        override
        returns (uint256 moeReward, IERC20 extraToken, uint256 extraAmount)
    {
        Farm storage farm = _farms[pid];
        Rewarder.Parameter storage rewarder = farm.rewarder;
        IRewarder extraRewarder = farm.extraRewarder;

        moeReward = rewarder.getPendingReward(farm.amounts, account, _getRewardForPid(rewarder, pid));

        if (address(extraRewarder) != address(0)) {
            Amounts.Parameter storage amounts = farm.amounts;

            (extraToken, extraAmount) =
                extraRewarder.getPendingReward(account, amounts.getAmountOf(account), amounts.getTotalAmount());
        }
    }

    function getToken(uint256 pid) external view override returns (IERC20) {
        return _farms[pid].token;
    }

    function getLastUpdateTimestamp(uint256 pid) external view override returns (uint256) {
        return _farms[pid].rewarder.lastUpdateTimestamp;
    }

    function getExtraRewarder(uint256 pid) external view override returns (IRewarder) {
        return _farms[pid].extraRewarder;
    }

    function getMoePerSecond() external view override returns (uint256) {
        return _moePerSecond;
    }

    function deposit(uint256 pid, uint256 amount) external override {
        _modify(pid, msg.sender, int256(amount));

        if (amount > 0) _farms[pid].token.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 pid, uint256 amount) external override {
        _modify(pid, msg.sender, -int256(amount));

        if (amount > 0) _farms[pid].token.safeTransfer(msg.sender, amount);
    }

    function claim(uint256[] calldata pids) external override {
        for (uint256 i; i < pids.length; ++i) {
            _modify(pids[i], msg.sender, 0);
        }
    }

    function emergencyWithdraw(uint256 pid) external override {
        Farm storage farm = _farms[pid];

        uint256 balance = farm.amounts.getAmountOf(msg.sender);

        farm.amounts.update(msg.sender, -int256(balance));

        farm.token.safeTransfer(msg.sender, balance);

        emit Modify(pid, msg.sender, -int256(balance), 0);
    }

    function setMoePerSecond(uint256 moePerSecond) external override onlyOwner {
        _updateAll();

        _moePerSecond = moePerSecond;

        emit MoePerSecondSet(moePerSecond);
    }

    function add(IERC20 token, uint256 startTimestamp, IRewarder extraRewarder) external override onlyOwner {
        if (startTimestamp < block.timestamp) revert MasterChef__InvalidStartTimestamp();

        uint256 pid = _farms.length;

        Farm storage farm = _farms.push();

        farm.token = token;
        farm.rewarder.lastUpdateTimestamp = startTimestamp;

        if (address(extraRewarder) != address(0)) _setExtraRewarder(pid, extraRewarder);

        emit FarmAdded(pid, token, startTimestamp);
    }

    function setExtraRewarder(uint256 pid, IRewarder extraRewarder) external override onlyOwner {
        _setExtraRewarder(pid, extraRewarder);
    }

    function updateAll() external override {
        _updateAll();
    }

    function _getRewardForPid(Rewarder.Parameter storage rewarder, uint256 pid) private view returns (uint256) {
        return _getRewardForPid(pid, rewarder.getTotalRewards(_moePerSecond), _veMoe.getTotalVotes());
    }

    function _getRewardForPid(uint256 pid, uint256 totalRewards, uint256 totalVote) private view returns (uint256) {
        return totalVote == 0 ? 0 : totalRewards * _veMoe.getVotes(pid) / totalVote;
    }

    function _setExtraRewarder(uint256 pid, IRewarder extraRewarder) private {
        IRewarder oldExtraRewarder = _farms[pid].extraRewarder;

        if (address(oldExtraRewarder) != address(0)) oldExtraRewarder.unlink();
        if (address(extraRewarder) != address(0)) extraRewarder.link(pid);

        _farms[pid].extraRewarder = extraRewarder;

        emit ExtraRewarderSet(pid, extraRewarder);
    }

    function _updateAll() private {
        uint256 length = _farms.length;

        uint256 totalVotes = _veMoe.getTotalVotes();
        uint256 moePerSecond = _moePerSecond;

        for (uint256 i; i < length; ++i) {
            Farm storage farm = _farms[i];
            Rewarder.Parameter storage rewarder = farm.rewarder;

            uint256 totalRewards = rewarder.getTotalRewards(moePerSecond);
            rewarder.updateAccDebtPerShare(farm.amounts.getTotalAmount(), _getRewardForPid(i, totalRewards, totalVotes));
        }
    }

    function _modify(uint256 pid, address account, int256 deltaAmount) private {
        Farm storage farm = _farms[pid];
        Rewarder.Parameter storage rewarder = farm.rewarder;
        IRewarder extraRewarder = farm.extraRewarder;

        (uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply,) = farm.amounts.update(account, deltaAmount);

        uint256 totalMoeRewardForPid = _getRewardForPid(rewarder, pid);
        uint256 moeReward = rewarder.update(account, oldBalance, newBalance, oldTotalSupply, totalMoeRewardForPid);

        if (moeReward > 0) moeReward = _moe.mint(msg.sender, moeReward);

        if (address(extraRewarder) != address(0)) {
            (IERC20 token, uint256 amount) = extraRewarder.claim(account, oldBalance, newBalance, oldTotalSupply);

            if (amount > 0) emit ExtraRewardClaimed(account, pid, token, amount);
        }

        emit Modify(pid, account, deltaAmount, moeReward);
    }
}

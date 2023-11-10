// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Math} from "./library/Math.sol";
import {Rewarder} from "./library/Rewarder.sol";
import {Constants} from "./library/Constants.sol";
import {Amounts} from "./library/Amounts.sol";
import {IMoe} from "./interface/IMoe.sol";
import {IVeMoe} from "./interface/IVeMoe.sol";
import {IMasterChef} from "./interface/IMasterChef.sol";
import {IMasterChefRewarder} from "./interface/IMasterChefRewarder.sol";

contract MasterChef is Ownable, IMasterChef {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using Rewarder for Rewarder.Parameter;
    using Amounts for Amounts.Parameter;

    IMoe private immutable _moe;
    IVeMoe private immutable _veMoe;
    uint256 private immutable _treasuryShare;

    address private _treasury;
    uint96 private _moePerSecond;

    Farm[] private _farms;

    constructor(IMoe moe, IVeMoe veMoe, address treasury, uint256 treasuryShare, address initialOwner)
        Ownable(initialOwner)
    {
        assert(treasuryShare <= Constants.PRECISION);

        _moe = moe;
        _veMoe = veMoe;
        _treasuryShare = treasuryShare;

        _setTreasury(treasury);
    }

    function getMoe() external view override returns (IMoe) {
        return _moe;
    }

    function getVeMoe() external view override returns (IVeMoe) {
        return _veMoe;
    }

    function getTreasury() external view override returns (address) {
        return _treasury;
    }

    function getTreasuryShare() external view override returns (uint256) {
        return _treasuryShare;
    }

    function getNumberOfFarms() external view override returns (uint256) {
        return _farms.length;
    }

    function getDeposit(uint256 pid, address account) external view override returns (uint256) {
        return _farms[pid].amounts.getAmountOf(account);
    }

    function getTotalDeposit(uint256 pid) external view override returns (uint256) {
        return _farms[pid].amounts.getTotalAmount();
    }

    function getPendingRewards(address account, uint256[] calldata pids)
        external
        view
        override
        returns (uint256[] memory moeRewards, IERC20[] memory extraTokens, uint256[] memory extraRewards)
    {
        moeRewards = new uint256[](pids.length);
        extraTokens = new IERC20[](pids.length);
        extraRewards = new uint256[](pids.length);

        for (uint256 i; i < pids.length; ++i) {
            uint256 pid = pids[i];

            Farm storage farm = _farms[pid];
            Rewarder.Parameter storage rewarder = farm.rewarder;
            IMasterChefRewarder extraRewarder = farm.extraRewarder;

            moeRewards[i] = rewarder.getPendingReward(farm.amounts, account, _getRewardForPid(rewarder, pid));

            if (address(extraRewarder) != address(0)) {
                Amounts.Parameter storage amounts = farm.amounts;

                (extraTokens[i], extraRewards[i]) =
                    extraRewarder.getPendingReward(account, amounts.getAmountOf(account), amounts.getTotalAmount());
            }
        }
    }

    function getToken(uint256 pid) external view override returns (IERC20) {
        return _farms[pid].token;
    }

    function getLastUpdateTimestamp(uint256 pid) external view override returns (uint256) {
        return _farms[pid].rewarder.lastUpdateTimestamp;
    }

    function getExtraRewarder(uint256 pid) external view override returns (IMasterChefRewarder) {
        return _farms[pid].extraRewarder;
    }

    function getMoePerSecond() external view override returns (uint256) {
        return _moePerSecond;
    }

    function getMoePerSecondForPid(uint256 pid) external view returns (uint256) {
        if (!_veMoe.isInTopPoolIds(pid)) return 0;

        uint256 totalVotes = _veMoe.getTotalVotes();

        return totalVotes == 0 ? 0 : _moePerSecond * _veMoe.getVotes(pid) / totalVotes;
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

        emit PositionModified(pid, msg.sender, -int256(balance), 0);
    }

    function setMoePerSecond(uint96 moePerSecond) external override onlyOwner {
        _updateAll(_veMoe.getTopPoolIds());

        _moePerSecond = moePerSecond;

        emit MoePerSecondSet(moePerSecond);
    }

    function add(IERC20 token, uint256 startTimestamp, IMasterChefRewarder extraRewarder) external override onlyOwner {
        if (startTimestamp < block.timestamp) revert MasterChef__InvalidStartTimestamp();

        uint256 pid = _farms.length;

        Farm storage farm = _farms.push();

        farm.token = token;
        farm.rewarder.lastUpdateTimestamp = startTimestamp;

        if (address(extraRewarder) != address(0)) _setExtraRewarder(pid, extraRewarder);

        token.balanceOf(address(this)); // sanity check

        emit FarmAdded(pid, token, startTimestamp);
    }

    function setExtraRewarder(uint256 pid, IMasterChefRewarder extraRewarder) external override onlyOwner {
        _setExtraRewarder(pid, extraRewarder);
    }

    function setTreasury(address treasury) external override onlyOwner {
        _setTreasury(treasury);
    }

    function updateAll(uint256[] calldata pids) external override {
        _updateAll(pids);
    }

    function _getRewardForPid(Rewarder.Parameter storage rewarder, uint256 pid) private view returns (uint256) {
        if (!_veMoe.isInTopPoolIds(pid)) return 0;

        return _getRewardForPid(pid, rewarder.getTotalRewards(_moePerSecond), _veMoe.getTotalVotes());
    }

    function _getRewardForPid(uint256 pid, uint256 totalRewards, uint256 totalVote) private view returns (uint256) {
        return totalVote == 0 ? 0 : totalRewards * _veMoe.getVotes(pid) / totalVote;
    }

    function _setExtraRewarder(uint256 pid, IMasterChefRewarder extraRewarder) private {
        IMasterChefRewarder oldExtraRewarder = _farms[pid].extraRewarder;

        if (address(oldExtraRewarder) != address(0)) oldExtraRewarder.unlink(pid);
        if (address(extraRewarder) != address(0)) extraRewarder.link(pid);

        _farms[pid].extraRewarder = extraRewarder;

        emit ExtraRewarderSet(pid, extraRewarder);
    }

    function _updateAll(uint256[] memory pids) private {
        uint256 nbOfFarms = _farms.length;
        uint256 length = pids.length;

        uint256 totalVotes = _veMoe.getTopPidsTotalVotes();
        uint256 moePerSecond = _moePerSecond;

        for (uint256 i; i < length; ++i) {
            uint256 pid = pids[i];

            if (pid >= nbOfFarms) revert MasterChef__InvalidPid(pid);

            Farm storage farm = _farms[pid];
            Rewarder.Parameter storage rewarder = farm.rewarder;

            uint256 totalRewards = rewarder.getTotalRewards(moePerSecond);
            rewarder.updateAccDebtPerShare(
                farm.amounts.getTotalAmount(), _getRewardForPid(pid, totalRewards, totalVotes)
            );
        }
    }

    function _modify(uint256 pid, address account, int256 deltaAmount) private {
        Farm storage farm = _farms[pid];
        Rewarder.Parameter storage rewarder = farm.rewarder;
        IMasterChefRewarder extraRewarder = farm.extraRewarder;

        (uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply,) = farm.amounts.update(account, deltaAmount);

        uint256 totalMoeRewardForPid = _getRewardForPid(rewarder, pid);

        if (totalMoeRewardForPid > 0) {
            uint256 treasuryAmount = totalMoeRewardForPid * _treasuryShare / Constants.PRECISION;
            totalMoeRewardForPid -= treasuryAmount;

            _moe.mint(_treasury, treasuryAmount);
            totalMoeRewardForPid = _moe.mint(address(this), totalMoeRewardForPid);
        }

        uint256 moeReward = rewarder.update(account, oldBalance, newBalance, oldTotalSupply, totalMoeRewardForPid);

        if (moeReward > 0) IERC20(_moe).safeTransfer(account, moeReward);

        if (address(extraRewarder) != address(0)) {
            extraRewarder.onModify(account, pid, oldBalance, newBalance, oldTotalSupply);
        }

        emit PositionModified(pid, account, deltaAmount, moeReward);
    }

    function _setTreasury(address treasury) private {
        if (treasury == address(0)) revert MasterChef__InvalidTreasury();

        _treasury = treasury;

        emit TreasurySet(treasury);
    }
}

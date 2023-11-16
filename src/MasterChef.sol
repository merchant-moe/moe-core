// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    Ownable2StepUpgradeable,
    OwnableUpgradeable,
    Initializable
} from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

import {Math} from "./libraries/Math.sol";
import {Rewarder} from "./libraries/Rewarder.sol";
import {Constants} from "./libraries/Constants.sol";
import {Amounts} from "./libraries/Amounts.sol";
import {IMoe} from "./interfaces/IMoe.sol";
import {IVeMoe} from "./interfaces/IVeMoe.sol";
import {IMasterChef} from "./interfaces/IMasterChef.sol";
import {IMasterChefRewarder} from "./interfaces/IMasterChefRewarder.sol";

/**
 * @title Master Chef Contract
 * @dev The MasterChef allows users to deposit tokens to earn MOE tokens distributed as liquidity mining rewards.
 * The MOE token is minted by the MasterChef contract and distributed to the users.
 * A share of the rewards is sent to the treasury.
 * The weight of each pool is determined by the amount of votes in the VeMOE contract and by the top pool ids.
 * On top of the MOE rewards, the MasterChef can also distribute extra rewards in other tokens using extra rewarders.
 */
contract MasterChef is Ownable2StepUpgradeable, IMasterChef {
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

    /**
     * @dev Constructor for the MasterChef contract.
     * @param moe The address of the MOE token.
     * @param veMoe The address of the VeMOE contract.
     * @param treasuryShare The share of the rewards that will be sent to the treasury.
     */
    constructor(IMoe moe, IVeMoe veMoe, uint256 treasuryShare) {
        _disableInitializers();

        if (treasuryShare > Constants.PRECISION) revert MasterChef__InvalidTreasuryShare();

        _moe = moe;
        _veMoe = veMoe;
        _treasuryShare = treasuryShare;
    }

    /**
     * @dev Initializes the MasterChef contract.
     * @param initialOwner The initial owner of the contract.
     * @param treasury The initial treasury.
     */
    function initialize(address initialOwner, address treasury) external initializer {
        __Ownable_init(initialOwner);

        _setTreasury(treasury);
    }

    /**
     * @dev Returns the address of the MOE token.
     * @return The address of the MOE token.
     */
    function getMoe() external view override returns (IMoe) {
        return _moe;
    }

    /**
     * @dev Returns the address of the VeMOE contract.
     * @return The address of the VeMOE contract.
     */
    function getVeMoe() external view override returns (IVeMoe) {
        return _veMoe;
    }

    /**
     * @dev Returns the address of the treasury.
     * @return The address of the treasury.
     */
    function getTreasury() external view override returns (address) {
        return _treasury;
    }

    /**
     * @dev Returns the share of the rewards that will be sent to the treasury.
     * @return The share of the rewards that will be sent to the treasury.
     */
    function getTreasuryShare() external view override returns (uint256) {
        return _treasuryShare;
    }

    /**
     * @dev Returns the number of farms.
     * @return The number of farms.
     */
    function getNumberOfFarms() external view override returns (uint256) {
        return _farms.length;
    }

    /**
     * @dev Returns the deposit amount of an account on a farm.
     * @param pid The pool ID of the farm.
     * @param account The account to check for the deposit amount.
     * @return The deposit amount of the account on the farm.
     */
    function getDeposit(uint256 pid, address account) external view override returns (uint256) {
        return _farms[pid].amounts.getAmountOf(account);
    }

    /**
     * @dev Returns the total deposit amount of a farm.
     * @param pid The pool ID of the farm.
     * @return The total deposit amount of the farm.
     */
    function getTotalDeposit(uint256 pid) external view override returns (uint256) {
        return _farms[pid].amounts.getTotalAmount();
    }

    /**
     * @dev Returns the pending rewards for a given account on a list of farms.
     * @param account The account to check for pending rewards.
     * @param pids The pool IDs of the farms.
     * @return moeRewards The MOE rewards for the account on the farms.
     * @return extraTokens The extra tokens from the extra rewarders.
     * @return extraRewards The extra rewards amounts from the extra rewarders.
     */
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

    /**
     * @dev Returns the token of a farm.
     * @param pid The pool ID of the farm.
     * @return The token of the farm.
     */
    function getToken(uint256 pid) external view override returns (IERC20) {
        return _farms[pid].token;
    }

    /**
     * @dev Returns the last update timestamp of a farm.
     * @param pid The pool ID of the farm.
     * @return The last update timestamp of the farm.
     */
    function getLastUpdateTimestamp(uint256 pid) external view override returns (uint256) {
        return _farms[pid].rewarder.lastUpdateTimestamp;
    }

    /**
     * @dev Returns the extra rewarder of a farm.
     * @param pid The pool ID of the farm.
     * @return The extra rewarder of the farm.
     */
    function getExtraRewarder(uint256 pid) external view override returns (IMasterChefRewarder) {
        return _farms[pid].extraRewarder;
    }

    /**
     * @dev Returns the MOE per second.
     * @return The MOE per second.
     */
    function getMoePerSecond() external view override returns (uint256) {
        return _moePerSecond;
    }

    /**
     * @dev Returns the MOE per second for a given pool ID.
     * If the pool ID is not in the top pool IDs, it will return 0.
     * Else, it will return the MOE per second multiplied by the proportion of votes for this pool ID.
     * @param pid The pool ID.
     * @return The MOE per second for the pool ID.
     */
    function getMoePerSecondForPid(uint256 pid) external view returns (uint256) {
        if (!_veMoe.isInTopPoolIds(pid)) return 0;

        uint256 totalVotes = _veMoe.getTotalVotes();

        return totalVotes == 0 ? 0 : _moePerSecond * _veMoe.getVotes(pid) / totalVotes;
    }

    /**
     * @dev Deposits tokens to a farm.
     * @param pid The pool ID of the farm.
     * @param amount The amount of tokens to deposit.
     */
    function deposit(uint256 pid, uint256 amount) external override {
        _modify(pid, msg.sender, amount.toInt256());

        if (amount > 0) _farms[pid].token.safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @dev Withdraws tokens from a farm.
     * @param pid The pool ID of the farm.
     * @param amount The amount of tokens to withdraw.
     */
    function withdraw(uint256 pid, uint256 amount) external override {
        _modify(pid, msg.sender, -amount.toInt256());

        if (amount > 0) _farms[pid].token.safeTransfer(msg.sender, amount);
    }

    /**
     * @dev Claims the rewards from a list of farms.
     * @param pids The pool IDs of the farms.
     */
    function claim(uint256[] calldata pids) external override {
        for (uint256 i; i < pids.length; ++i) {
            _modify(pids[i], msg.sender, 0);
        }
    }

    /**
     * @dev Emergency withdraws tokens from a farm, without claiming any rewards.
     * @param pid The pool ID of the farm.
     */
    function emergencyWithdraw(uint256 pid) external override {
        Farm storage farm = _farms[pid];

        uint256 balance = farm.amounts.getAmountOf(msg.sender);
        int256 deltaAmount = -balance.toInt256();

        farm.amounts.update(msg.sender, deltaAmount);

        farm.token.safeTransfer(msg.sender, balance);

        emit PositionModified(pid, msg.sender, deltaAmount, 0);
    }

    /**
     * @dev Updates all the farms in the pids list.
     * @param pids The pool IDs to update.
     */
    function updateAll(uint256[] calldata pids) external override {
        _updateAll(pids);
    }

    /**
     * @dev Sets the MOE per second.
     * It will update all the farms that are in the top pool IDs.
     * @param moePerSecond The new MOE per second.
     */
    function setMoePerSecond(uint96 moePerSecond) external override onlyOwner {
        _updateAll(_veMoe.getTopPoolIds());

        _moePerSecond = moePerSecond;

        emit MoePerSecondSet(moePerSecond);
    }

    /**
     * @dev Adds a farm.
     * @param token The token of the farm.
     * @param extraRewarder The extra rewarder of the farm.
     */
    function add(IERC20 token, IMasterChefRewarder extraRewarder) external override onlyOwner {
        uint256 pid = _farms.length;

        Farm storage farm = _farms.push();

        farm.token = token;
        farm.rewarder.lastUpdateTimestamp = block.timestamp;

        if (address(extraRewarder) != address(0)) _setExtraRewarder(pid, extraRewarder);

        token.balanceOf(address(this)); // sanity check

        emit FarmAdded(pid, token);
    }

    /**
     * @dev Sets the extra rewarder of a farm.
     * @param pid The pool ID of the farm.
     * @param extraRewarder The new extra rewarder of the farm.
     */
    function setExtraRewarder(uint256 pid, IMasterChefRewarder extraRewarder) external override onlyOwner {
        _setExtraRewarder(pid, extraRewarder);
    }

    /**
     * @dev Sets the treasury.
     * @param treasury The new treasury.
     */
    function setTreasury(address treasury) external override onlyOwner {
        _setTreasury(treasury);
    }

    /**
     * @dev Returns the reward for a given pool ID.
     * If the pool ID is not in the top pool IDs, it will return 0.
     * Else, it will return the reward multiplied by the proportion of votes for this pool ID.
     * @param rewarder The storage pointer to the rewarder.
     * @param pid The pool ID.
     * @return The reward for the pool ID.
     */
    function _getRewardForPid(Rewarder.Parameter storage rewarder, uint256 pid) private view returns (uint256) {
        if (!_veMoe.isInTopPoolIds(pid)) return 0;

        return _getRewardForPid(pid, rewarder.getTotalRewards(_moePerSecond), _veMoe.getTotalVotes());
    }

    /**
     * @dev Returns the reward for a given pool ID.
     * The weight of the pool ID is determined by the proportion of votes for this pool ID.
     * @param pid The pool ID.
     * @param totalRewards The total rewards.
     * @param totalVotes The total votes.
     * @return The reward for the pool ID.
     */
    function _getRewardForPid(uint256 pid, uint256 totalRewards, uint256 totalVotes) private view returns (uint256) {
        return totalVotes == 0 ? 0 : totalRewards * _veMoe.getVotes(pid) / totalVotes;
    }

    /**
     * @dev Sets the extra rewarder of a farm.
     * Will call link/unlink to make sure the rewarders are properly set/unset.
     * It is very important that a rewarder that was previously linked can't be linked again.
     * @param pid The pool ID of the farm.
     * @param extraRewarder The new extra rewarder of the farm.
     */
    function _setExtraRewarder(uint256 pid, IMasterChefRewarder extraRewarder) private {
        IMasterChefRewarder oldExtraRewarder = _farms[pid].extraRewarder;

        if (address(oldExtraRewarder) != address(0)) oldExtraRewarder.unlink(pid);
        if (address(extraRewarder) != address(0)) extraRewarder.link(pid);

        _farms[pid].extraRewarder = extraRewarder;

        emit ExtraRewarderSet(pid, extraRewarder);
    }

    /**
     * @dev Updates all the farms in the pids list.
     * @param pids The pool IDs to update.
     */
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

    /**
     * @dev Modifies the position of an account on a farm.
     * @param pid The pool ID of the farm.
     * @param account The account to modify the position of.
     * @param deltaAmount The delta amount to modify the position with.
     */
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

    /**
     * @dev Sets the treasury.
     * @param treasury The new treasury.
     */
    function _setTreasury(address treasury) private {
        if (treasury == address(0)) revert MasterChef__InvalidTreasury();

        _treasury = treasury;

        emit TreasurySet(treasury);
    }
}

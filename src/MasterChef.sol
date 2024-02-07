// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

import {Math} from "./libraries/Math.sol";
import {Rewarder} from "./libraries/Rewarder.sol";
import {Constants} from "./libraries/Constants.sol";
import {Amounts} from "./libraries/Amounts.sol";
import {IMoe} from "./interfaces/IMoe.sol";
import {IVeMoe} from "./interfaces/IVeMoe.sol";
import {IMasterChef} from "./interfaces/IMasterChef.sol";
import {IMasterChefRewarder} from "./interfaces/IMasterChefRewarder.sol";
import {IRewarderFactory, IBaseRewarder} from "./interfaces/IRewarderFactory.sol";

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
    using SafeERC20 for IMoe;
    using Math for uint256;
    using Rewarder for Rewarder.Parameter;
    using Amounts for Amounts.Parameter;

    IMoe private immutable _moe;
    IVeMoe private immutable _veMoe;
    IRewarderFactory private immutable _rewarderFactory;

    uint256 private immutable _treasuryShare;

    address private _treasury;
    address private _gap0; // unused, but needed for the storage layout to be the same as the previous contract
    address private _gap1; // unused, but needed for the storage layout to be the same as the previous contract

    uint96 private _moePerSecond;

    Farm[] private _farms;

    /**
     * @dev Constructor for the MasterChef contract.
     * @param moe The address of the MOE token.
     * @param veMoe The address of the VeMOE contract.
     * @param factory The address of the rewarder factory.
     * @param treasuryShare The share of the rewards that will be sent to the treasury.
     */
    constructor(IMoe moe, IVeMoe veMoe, IRewarderFactory factory, uint256 treasuryShare) {
        _disableInitializers();

        if (treasuryShare > Constants.PRECISION) revert MasterChef__InvalidShares();

        _moe = moe;
        _veMoe = veMoe;
        _rewarderFactory = factory;

        _treasuryShare = treasuryShare;
    }

    /**
     * @dev Initializes the MasterChef contract.
     * @param initialOwner The initial owner of the contract.
     * @param treasury The initial treasury.
     * @param futureFunding The address of the future funding vesting contract.
     * @param team The address of the team vesting contract.
     * @param futureFundingAmount The amount of MOE tokens to pre-mint for the future funding vesting contract.
     * @param teamAmount The amount of MOE tokens to pre-mint for the team vesting contract.
     */
    function initialize(
        address initialOwner,
        address treasury,
        address futureFunding,
        address team,
        uint256 futureFundingAmount,
        uint256 teamAmount
    ) external reinitializer(2) {
        __Ownable_init(initialOwner);

        _setTreasury(treasury);

        uint256 mintedToFutureFunding =
            futureFundingAmount > 0 ? _moe.mint(address(futureFunding), futureFundingAmount) : 0;
        uint256 mintedToTeam = teamAmount > 0 ? _moe.mint(address(team), teamAmount) : 0;

        if (mintedToFutureFunding != futureFundingAmount || mintedToTeam != teamAmount) {
            revert MasterChef__MintFailed();
        }
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
     * @dev Returns the address of the rewarder factory.
     * @return The address of the rewarder factory.
     */
    function getRewarderFactory() external view override returns (IRewarderFactory) {
        return _rewarderFactory;
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
            Amounts.Parameter storage amounts = farm.amounts;

            uint256 balance = amounts.getAmountOf(account);
            uint256 totalSupply = amounts.getTotalAmount();

            {
                (, uint256 moeRewardForPid) = _calculateAmounts(_getRewardForPid(rewarder, pid, totalSupply));

                moeRewards[i] = rewarder.getPendingReward(account, balance, totalSupply, moeRewardForPid);
            }

            IMasterChefRewarder extraRewarder = farm.extraRewarder;

            if (address(extraRewarder) != address(0)) {
                (extraTokens[i], extraRewards[i]) = extraRewarder.getPendingReward(account, balance, totalSupply);
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
     * Else, it will return the MOE per second multiplied by the weight of the pool ID over the total weight.
     * @param pid The pool ID.
     * @return The MOE per second for the pool ID.
     */
    function getMoePerSecondForPid(uint256 pid) external view override returns (uint256) {
        return _getRewardForPid(pid, _moePerSecond, _veMoe.getTotalWeight());
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
        if (moePerSecond > Constants.MAX_MOE_PER_SECOND) revert MasterChef__InvalidMoePerSecond();

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
     * @dev Blocks the renouncing of ownership.
     */
    function renounceOwnership() public pure override {
        revert MasterChef__CannotRenounceOwnership();
    }

    /**
     * @dev Returns the reward for a given pool ID.
     * If the pool ID is not in the top pool IDs, it will return 0.
     * Else, it will return the reward multiplied by the weight of the pool ID over the total weight.
     * @param rewarder The storage pointer to the rewarder.
     * @param pid The pool ID.
     * @param totalSupply The total supply.
     * @return The reward for the pool ID.
     */
    function _getRewardForPid(Rewarder.Parameter storage rewarder, uint256 pid, uint256 totalSupply)
        private
        view
        returns (uint256)
    {
        return _getRewardForPid(pid, rewarder.getTotalRewards(_moePerSecond, totalSupply), _veMoe.getTotalWeight());
    }

    /**
     * @dev Returns the reward for a given pool ID.
     * If the pool ID is not in the top pool IDs, it will return 0.
     * Else, it will return the reward multiplied by the weight of the pool ID over the total weight.
     * @param pid The pool ID.
     * @param totalRewards The total rewards.
     * @param totalWeight The total weight.
     * @return The reward for the pool ID.
     */
    function _getRewardForPid(uint256 pid, uint256 totalRewards, uint256 totalWeight) private view returns (uint256) {
        return totalWeight == 0 ? 0 : totalRewards * _veMoe.getWeight(pid) / totalWeight;
    }

    /**
     * @dev Sets the extra rewarder of a farm.
     * Will call link/unlink to make sure the rewarders are properly set/unset.
     * It is very important that a rewarder that was previously linked can't be linked again.
     * @param pid The pool ID of the farm.
     * @param extraRewarder The new extra rewarder of the farm.
     */
    function _setExtraRewarder(uint256 pid, IMasterChefRewarder extraRewarder) private {
        if (
            address(extraRewarder) != address(0)
                && _rewarderFactory.getRewarderType(extraRewarder) != IRewarderFactory.RewarderType.MasterChefRewarder
        ) {
            revert MasterChef__NotMasterchefRewarder();
        }

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
        uint256 length = pids.length;

        uint256 totalWeight = _veMoe.getTotalWeight();
        uint256 moePerSecond = _moePerSecond;

        for (uint256 i; i < length; ++i) {
            uint256 pid = pids[i];

            Farm storage farm = _farms[pid];
            Rewarder.Parameter storage rewarder = farm.rewarder;

            uint256 totalSupply = farm.amounts.getTotalAmount();
            uint256 totalRewards = rewarder.getTotalRewards(moePerSecond, totalSupply);

            uint256 totalMoeRewardForPid = _getRewardForPid(pid, totalRewards, totalWeight);
            uint256 moeRewardForPid = _mintMoe(totalMoeRewardForPid);

            rewarder.updateAccDebtPerShare(totalSupply, moeRewardForPid);
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

        uint256 totalMoeRewardForPid = _getRewardForPid(rewarder, pid, oldTotalSupply);
        uint256 moeRewardForPid = _mintMoe(totalMoeRewardForPid);

        uint256 moeReward = rewarder.update(account, oldBalance, newBalance, oldTotalSupply, moeRewardForPid);

        if (moeReward > 0) _moe.safeTransfer(account, moeReward);

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
        if (treasury == address(0)) revert MasterChef__ZeroAddress();

        _treasury = treasury;

        emit TreasurySet(treasury);
    }

    /**
     * @dev Mints MOE tokens to the treasury and to this contract.
     * @param amount The amount of MOE tokens to mint.
     * @return The amount of MOE tokens minted for liquidity mining.
     */
    function _mintMoe(uint256 amount) private returns (uint256) {
        if (amount == 0) return 0;

        (uint256 treasuryAmount, uint256 liquidityMiningAmount) = _calculateAmounts(amount);

        _moe.mint(_treasury, treasuryAmount);
        return _moe.mint(address(this), liquidityMiningAmount);
    }

    /**
     * @dev Calculates the amounts of MOE tokens to mint for each recipient.
     * @param amount The amount of MOE tokens to mint.
     * @return treasuryAmount The amount of MOE tokens to mint for the treasury.
     * @return liquidityMiningAmount The amount of MOE tokens to mint for liquidity mining.
     */
    function _calculateAmounts(uint256 amount)
        private
        view
        returns (uint256 treasuryAmount, uint256 liquidityMiningAmount)
    {
        treasuryAmount = amount * _treasuryShare / Constants.PRECISION;
        liquidityMiningAmount = amount - treasuryAmount;
    }
}

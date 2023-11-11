// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Math} from "./library/Math.sol";
import {Rewarder} from "./library/Rewarder.sol";
import {Amounts} from "./library/Amounts.sol";
import {Constants} from "./library/Constants.sol";
import {IVeMoeRewarder} from "./interface/IVeMoeRewarder.sol";
import {IMoeStaking} from "./interface/IMoeStaking.sol";
import {IMasterChef} from "./interface/IMasterChef.sol";
import {IVeMoe} from "./interface/IVeMoe.sol";

/**
 * @title VeMoe Contract
 * @dev The VeMoe Contract allows users to vote on pool weights in the MasterChef contract.
 * Protocols can create bribe contracts to incentivize users to vote on their pools.
 */
contract VeMoe is Ownable, IVeMoe {
    using Math for uint256;
    using Rewarder for Rewarder.Parameter;
    using Amounts for Amounts.Parameter;
    using EnumerableSet for EnumerableSet.UintSet;

    IMoeStaking private immutable _moeStaking;
    IMasterChef private immutable _masterChef;
    uint256 private immutable _maxVeMoePerMoe;

    uint256 private _topPidsTotalVotes;
    EnumerableSet.UintSet private _topPids;

    uint256 private _veMoePerSecondPerMoe;
    Rewarder.Parameter private _veRewarder;

    // pid to Vote
    Amounts.Parameter private _votes;

    mapping(address => User) private _users;
    mapping(IVeMoeRewarder => mapping(uint256 => uint256)) private _bribesTotalVotes;

    /**
     * @dev Constructor for VeMoe contract.
     * @param moeStaking The MOE Staking contract.
     * @param masterChef The MasterChef contract.
     * @param maxVeMoePerMoe The maximum veMOE per MOE.
     * @param initialOwner The initial owner of the contract.
     */
    constructor(IMoeStaking moeStaking, IMasterChef masterChef, uint256 maxVeMoePerMoe, address initialOwner)
        Ownable(initialOwner)
    {
        _moeStaking = moeStaking;
        _masterChef = masterChef;
        _maxVeMoePerMoe = maxVeMoePerMoe;
    }

    /**
     * @dev Returns the MOE Staking contract.
     * @return The MOE Staking contract.
     */
    function getMoeStaking() external view override returns (IMoeStaking) {
        return _moeStaking;
    }

    /**
     * @dev Returns the MasterChef contract.
     * @return The MasterChef contract.
     */
    function getMasterChef() external view override returns (IMasterChef) {
        return _masterChef;
    }

    /**
     * @dev Returns the total veMOE of the specified account.
     * @param account The address of the account.
     * @return veMoe The total veMOE of the account.
     */
    function balanceOf(address account) external view override returns (uint256 veMoe) {
        User storage user = _users[account];

        uint256 balance = _moeStaking.getDeposit(account);

        uint256 totalVested = _veRewarder.getTotalRewards(_veMoePerSecondPerMoe);
        uint256 userVested = _veRewarder.getPendingReward(account, balance, Constants.PRECISION, totalVested);

        (veMoe,) = _getVeMoe(user, balance, balance, userVested);
    }

    /**
     * @dev Returns veMoePerSecondPerMoe and maxVeMoePerMoe parameters.
     * @return veMoePerSecondPerMoe The veMOE per second.
     * @return maxVeMoePerMoe The maximum veMOE per MOE.
     */
    function getVeMoeParameters()
        external
        view
        override
        returns (uint256 veMoePerSecondPerMoe, uint256 maxVeMoePerMoe)
    {
        return (_veMoePerSecondPerMoe, _maxVeMoePerMoe);
    }

    /**
     * @dev Returns the total votes of a pool.
     * @param pid The pool ID.
     * @return The total votes of the pool.
     */
    function getVotes(uint256 pid) external view override returns (uint256) {
        return _votes.getAmountOf(pid);
    }

    /**
     * @dev Returns the total votes of all pools.
     * @return The total votes of all pools.
     */
    function getTotalVotes() external view override returns (uint256) {
        return _votes.getTotalAmount();
    }

    /**
     * @dev Returns the total votes of a pool for a bribe contract.
     * @param bribe The bribe contract.
     * @param pid The pool ID.
     * @return The total votes of the pool for the bribe contract.
     */
    function getBribesTotalVotes(IVeMoeRewarder bribe, uint256 pid) external view override returns (uint256) {
        return _bribesTotalVotes[bribe][pid];
    }

    /**
     * @dev Returns the bribes contract of a pool for an account.
     * Will return address(0) if the account has not set a bribes contract for the pool.
     * @param account The address of the account.
     * @param pid The pool ID.
     * @return The bribes contract of the pool for the account.
     */
    function getBribesOf(address account, uint256 pid) external view override returns (IVeMoeRewarder) {
        return _users[account].bribes[pid];
    }

    /**
     * @dev Returns the votes of an account for a pool.
     * @param account The address of the account.
     * @param pid The pool ID.
     * @return The votes of the account for the pool.
     */
    function getVotesOf(address account, uint256 pid) external view override returns (uint256) {
        return _users[account].votes.getAmountOf(pid);
    }

    /**
     * @dev Returns the total votes of an account for all pools.
     * @param account The address of the account.
     * @return The total votes of the account for all pools.
     */
    function getTotalVotesOf(address account) external view override returns (uint256) {
        return _users[account].votes.getTotalAmount();
    }

    /**
     * @dev Returns the top pool IDs.
     * @return The top pool IDs.
     */
    function getTopPoolIds() external view override returns (uint256[] memory) {
        return _topPids.values();
    }

    /**
     * @dev Returns whether a pool ID is in the top pool IDs.
     * @param pid The pool ID.
     * @return Whether the pool ID is in the top pool IDs.
     */
    function isInTopPoolIds(uint256 pid) external view override returns (bool) {
        return _topPids.contains(pid);
    }

    /**
     * @dev Returns all the top pool IDs.
     * @return The top pool IDs.
     */
    function getTopPidsTotalVotes() external view override returns (uint256) {
        return _topPidsTotalVotes;
    }

    /**
     * @dev Returns the pending rewards for an account for each pool in the pids list.
     * @param account The address of the account.
     * @param pids The list of pool IDs.
     * @return tokens The list of tokens.
     * @return pendingRewards The list of pending rewards.
     */
    function getPendingRewards(address account, uint256[] calldata pids)
        external
        view
        override
        returns (IERC20[] memory tokens, uint256[] memory pendingRewards)
    {
        uint256 length = pids.length;

        tokens = new IERC20[](length);
        pendingRewards = new uint256[](length);

        User storage user = _users[account];

        for (uint256 i; i < length; ++i) {
            uint256 pid = pids[i];

            IVeMoeRewarder bribe = user.bribes[pid];

            if (address(bribe) != address(0)) {
                uint256 userVotes = user.votes.getAmountOf(pid);
                uint256 totalVotes = _bribesTotalVotes[bribe][pid];

                (tokens[i], pendingRewards[i]) = bribe.getPendingReward(account, userVotes, totalVotes);
            }
        }
    }

    /**
     * @dev Claims the pending rewards in bribe contracts for each pool in the pids list.
     * @param pids The list of pool IDs.
     */
    function claim(uint256[] calldata pids) external override {
        User storage user = _users[msg.sender];

        for (uint256 i; i < pids.length; ++i) {
            uint256 pid = pids[i];

            IVeMoeRewarder bribe = _users[msg.sender].bribes[pid];

            if (address(bribe) != address(0)) {
                uint256 userVotes = user.votes.getAmountOf(pid);
                uint256 totalVotes = _bribesTotalVotes[bribe][pid];

                bribe.onModify(msg.sender, pid, userVotes, userVotes, totalVotes);
            }
        }
    }

    /**
     * @dev Votes for the pools in the pids list.
     * Will update the top pool IDs in the MasterChef contract.
     * @param pids The list of pool IDs.
     * @param deltaAmounts The list of delta amounts.
     */
    function vote(uint256[] calldata pids, int256[] calldata deltaAmounts) external override {
        if (pids.length != deltaAmounts.length) revert VeMoe__InvalidLength();

        uint256 numberOfFarm = _masterChef.getNumberOfFarms();

        _masterChef.updateAll(_topPids.values());

        User storage user = _users[msg.sender];

        uint256 balance = _moeStaking.getDeposit(msg.sender);

        _claim(msg.sender, balance, balance);

        uint256 userTotalVeMoe = user.veMoe;
        uint256 topPidsTotalVotes = _topPidsTotalVotes;

        for (uint256 i; i < pids.length; ++i) {
            int256 deltaAmount = deltaAmounts[i];
            uint256 pid = pids[i];

            if (pid >= numberOfFarm) revert VeMoe__InvalidPid(pid);

            (uint256 userOldVotes, uint256 userNewVotes,, uint256 userNewTotalVotes) =
                user.votes.update(pid, deltaAmount);

            if (userNewTotalVotes > userTotalVeMoe) revert VeMoe__InsufficientVeMoe(userTotalVeMoe, userNewTotalVotes);

            _votes.update(pid, deltaAmount);

            if (_topPids.contains(pid)) topPidsTotalVotes = topPidsTotalVotes.addDelta(deltaAmount);

            IVeMoeRewarder bribe = user.bribes[pid];

            if (address(bribe) != address(0)) {
                uint256 totalVotes = _bribesTotalVotes[bribe][pid];
                _bribesTotalVotes[bribe][pid] = totalVotes.addDelta(deltaAmount);

                bribe.onModify(msg.sender, pid, userOldVotes, userNewVotes, totalVotes);
            }
        }

        _topPidsTotalVotes = topPidsTotalVotes;

        emit Vote(msg.sender, pids, deltaAmounts);
    }

    /**
     * @dev Sets the bribes contract for each pool in the pids list.
     * @param pids The list of pool IDs.
     * @param bribes The list of bribes contracts.
     */
    function setBribes(uint256[] calldata pids, IVeMoeRewarder[] calldata bribes) external override {
        if (pids.length != bribes.length) revert VeMoe__InvalidLength();

        User storage user = _users[msg.sender];

        for (uint256 i; i < pids.length; ++i) {
            uint256 pid = pids[i];

            IVeMoeRewarder newBribe = bribes[i];
            IVeMoeRewarder oldBribe = user.bribes[pid];

            if (oldBribe == newBribe) continue;

            uint256 userVotes = user.votes.getAmountOf(pid);

            user.bribes[pid] = newBribe;

            uint256 oldBribesTotalVotes;
            uint256 newBribesTotalVotes;

            if (address(oldBribe) != address(0)) {
                oldBribesTotalVotes = _bribesTotalVotes[oldBribe][pid];
                _bribesTotalVotes[oldBribe][pid] = oldBribesTotalVotes - userVotes;
            }
            if (address(newBribe) != address(0)) {
                newBribesTotalVotes = _bribesTotalVotes[newBribe][pid];
                _bribesTotalVotes[newBribe][pid] = newBribesTotalVotes + userVotes;
            }

            // Done after updating _bribesTotalVotes to avoid reentrancy attack
            if (address(oldBribe) != address(0)) oldBribe.onModify(msg.sender, pid, userVotes, 0, oldBribesTotalVotes);
            if (address(newBribe) != address(0)) newBribe.onModify(msg.sender, pid, 0, userVotes, newBribesTotalVotes);
        }

        emit BribesSet(msg.sender, pids, bribes);
    }

    /**
     * @dev Emergency function to unset the bribes contract for each pool in the pids list, forfeiting the rewards.
     * @param pids The list of pool IDs.
     */
    function emergencyUnsetBribes(uint256[] calldata pids) external override {
        User storage user = _users[msg.sender];

        for (uint256 i; i < pids.length; ++i) {
            uint256 pid = pids[i];

            IVeMoeRewarder bribe = user.bribes[pid];

            if (address(bribe) == address(0)) revert VeMoe__NoBribeForPid(pid);

            uint256 userVotes = user.votes.getAmountOf(pid);
            _bribesTotalVotes[bribe][pid] -= userVotes;

            delete user.bribes[pid];
        }

        emit BribesSet(msg.sender, pids, new IVeMoeRewarder[](pids.length));
    }

    /**
     * @dev Called by the caller contract to update the veMOE of an account.
     * @param account The account to update.
     * @param oldBalance The old balance of the account.
     * @param newBalance The new balance of the account.
     */
    function onModify(address account, uint256 oldBalance, uint256 newBalance, uint256, uint256) external override {
        if (msg.sender != address(_moeStaking)) revert VeMoe__InvalidCaller();

        _claim(account, oldBalance, newBalance);
    }

    /**
     * @dev Sets the top pool IDs.
     * @param pids The list of pool IDs.
     */
    function setTopPoolIds(uint256[] calldata pids) external override onlyOwner {
        uint256 length = pids.length;

        if (length > Constants.MAX_NUMBER_OF_FARMS) revert VeMoe__TooManyPoolIds();

        uint256[] memory oldIds = _topPids.values();

        if (oldIds.length > 0) {
            _masterChef.updateAll(oldIds);

            for (uint256 i = oldIds.length; i > 0;) {
                _topPids.remove(oldIds[--i]);
            }
        }

        uint256 numberOfFarm = _masterChef.getNumberOfFarms();

        uint256 totalVotes;
        for (uint256 i; i < length; ++i) {
            uint256 pid = pids[i];

            if (pid >= numberOfFarm) revert VeMoe__InvalidPid(pid);
            if (!_topPids.add(pid)) revert VeMoe__DuplicatePoolId(pid);

            uint256 votes = _votes.getAmountOf(pid);
            totalVotes += votes;
        }

        _topPidsTotalVotes = totalVotes;

        emit TopPoolIdsSet(pids);
    }

    /**
     * @dev Sets the veMOE per second.
     * @param veMoePerSecondPerMoe The veMOE per second.
     */
    function setVeMoePerSecondPerMoe(uint256 veMoePerSecondPerMoe) external override onlyOwner {
        _veRewarder.updateAccDebtPerShare(Constants.PRECISION, _veRewarder.getTotalRewards(_veMoePerSecondPerMoe));

        _veMoePerSecondPerMoe = veMoePerSecondPerMoe;

        emit VeMoePerSecondPerMoeSet(veMoePerSecondPerMoe);
    }

    /**
     * @dev Claims the pending veMOE of an account.
     * @param account The account to claim veMOE for.
     * @param oldBalance The old balance of the account.
     * @param newBalance The new balance of the account.
     */
    function _claim(address account, uint256 oldBalance, uint256 newBalance) private {
        User storage user = _users[account];

        uint256 totalVested = _veRewarder.getTotalRewards(_veMoePerSecondPerMoe);
        uint256 userVested = _veRewarder.update(account, oldBalance, newBalance, Constants.PRECISION, totalVested);

        (uint256 newVeMoe, int256 deltaVeMoe) = _getVeMoe(user, oldBalance, newBalance, userVested);

        user.veMoe = newVeMoe;

        emit Claim(account, deltaVeMoe);
    }

    /**
     * @dev Returns the veMOE of an account.
     * @param user The user to check.
     * @param oldBalance The old balance of the account.
     * @param newBalance The new balance of the account.
     * @param userVested The vested veMOE of the account.
     * @return newVeMoe The new veMOE of the account.
     * @return deltaVeMoe The delta veMOE of the account.
     */
    function _getVeMoe(User storage user, uint256 oldBalance, uint256 newBalance, uint256 userVested)
        private
        view
        returns (uint256 newVeMoe, int256 deltaVeMoe)
    {
        uint256 oldVeMoe = user.veMoe;

        if (newBalance >= oldBalance) {
            newVeMoe = oldVeMoe + userVested;

            uint256 maxVeMoe = oldBalance * _maxVeMoePerMoe / Constants.PRECISION;

            newVeMoe = newVeMoe > maxVeMoe ? maxVeMoe : newVeMoe;
        } else {
            if (user.votes.getTotalAmount() > 0) revert VeMoe__CannotUnstakeWithVotes();

            newVeMoe = 0;
        }

        unchecked {
            if (newVeMoe > uint256(type(int256).max)) revert VeMoe__VeMoeOverflow();
            deltaVeMoe = int256(newVeMoe - oldVeMoe);
        }
    }
}

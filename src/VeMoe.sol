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

contract VeMoe is Ownable, IVeMoe {
    using Math for uint256;
    using Rewarder for Rewarder.Parameter;
    using Amounts for Amounts.Parameter;
    using EnumerableSet for EnumerableSet.UintSet;

    IMoeStaking private immutable _moeStaking;
    IMasterChef private immutable _masterChef;

    uint256 private _topPidsTotalVotes;
    EnumerableSet.UintSet private _topPids;

    uint256 private _veMoePerSecond;
    uint256 private _maxVeMoePerMoe;

    Rewarder.Parameter private _veRewarder;

    // pid to Vote
    Amounts.Parameter private _votes;

    mapping(address => User) private _users;
    mapping(IVeMoeRewarder => mapping(uint256 => uint256)) private _bribesTotalVotes;

    constructor(IMoeStaking moeStaking, IMasterChef masterChef, address initialOwner) Ownable(initialOwner) {
        _moeStaking = moeStaking;
        _masterChef = masterChef;
    }

    function getMoeStaking() external view override returns (IMoeStaking) {
        return _moeStaking;
    }

    function getMasterChef() external view override returns (IMasterChef) {
        return _masterChef;
    }

    function balanceOf(address account) external view override returns (uint256 veMoe) {
        User storage user = _users[account];

        uint256 balance = _moeStaking.getDeposit(account);

        uint256 totalVested = _veRewarder.getTotalRewards(_veMoePerSecond);
        uint256 userVested = _veRewarder.getPendingReward(account, balance, Constants.PRECISION, totalVested);

        (veMoe,) = _getVeMoe(user, balance, balance, userVested);
    }

    function getVeMoeParameters() external view override returns (uint256 veMoePerSecond, uint256 maxVeMoePerMoe) {
        return (_veMoePerSecond, _maxVeMoePerMoe);
    }

    function getVotes(uint256 pid) external view override returns (uint256) {
        return _votes.getAmountOf(pid);
    }

    function getTotalVotes() external view override returns (uint256) {
        return _votes.getTotalAmount();
    }

    function getBribesTotalVotes(IVeMoeRewarder bribe, uint256 pid) external view override returns (uint256) {
        return _bribesTotalVotes[bribe][pid];
    }

    function getBribesOf(address account, uint256 pid) external view override returns (IVeMoeRewarder) {
        return _users[account].bribes[pid];
    }

    function getVotesOf(address account, uint256 pid) external view override returns (uint256) {
        return _users[account].votes.getAmountOf(pid);
    }

    function getTotalVotesOf(address account) external view override returns (uint256) {
        return _users[account].votes.getTotalAmount();
    }

    function getTopPoolIds() external view override returns (uint256[] memory) {
        return _topPids.values();
    }

    function isInTopPoolIds(uint256 pid) external view override returns (bool) {
        return _topPids.contains(pid);
    }

    function getTopPidsTotalVotes() external view override returns (uint256) {
        return _topPidsTotalVotes;
    }

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

    function claim(uint256[] calldata pids) external override {
        uint256 balance = _moeStaking.getDeposit(msg.sender);
        User storage user = _users[msg.sender];

        _claim(msg.sender, balance, balance);

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

            if (address(oldBribe) != address(0)) oldBribe.onModify(msg.sender, pid, userVotes, 0, oldBribesTotalVotes);
            if (address(newBribe) != address(0)) newBribe.onModify(msg.sender, pid, 0, userVotes, newBribesTotalVotes);
        }

        emit BribesSet(msg.sender, pids, bribes);
    }

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

    function onModify(address account, uint256 oldBalance, uint256 newBalance, uint256, uint256) external override {
        if (msg.sender != address(_moeStaking)) revert VeMoe__InvalidCaller();

        _claim(account, oldBalance, newBalance);
    }

    function setTopPoolIds(uint256[] calldata pids) external override onlyOwner {
        uint256 length = pids.length;

        if (length > Constants.MAX_NUMBER_OF_FARMS) revert VeMoe__TooManyPoolIds();

        uint256[] memory oldIds = _topPids.values();

        if (oldIds.length > 0) {
            _masterChef.updateAll(oldIds);

            for (uint256 i; i < oldIds.length; ++i) {
                _topPids.remove(oldIds[i]);
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

    function setVeMoePerSecond(uint256 veMoePerSecond) external override onlyOwner {
        _veRewarder.updateAccDebtPerShare(Constants.PRECISION, _veRewarder.getTotalRewards(_veMoePerSecond));

        _veMoePerSecond = veMoePerSecond;

        emit VeMoePerSecondSet(veMoePerSecond);
    }

    function setMaxVeMoePerMoe(uint256 maxVeMoePerMoe) external override onlyOwner {
        if (maxVeMoePerMoe < _maxVeMoePerMoe) revert VeMoe__OnlyIncreaseMaxVeMoePerMoe();

        _maxVeMoePerMoe = maxVeMoePerMoe;

        emit MaxVeMoePerMoeSet(maxVeMoePerMoe);
    }

    function _claim(address account, uint256 oldBalance, uint256 newBalance) private {
        User storage user = _users[account];

        uint256 totalVested = _veRewarder.getTotalRewards(_veMoePerSecond);
        uint256 userVested = _veRewarder.update(account, oldBalance, newBalance, Constants.PRECISION, totalVested);

        (uint256 newVeMoe, int256 deltaVeMoe) = _getVeMoe(user, oldBalance, newBalance, userVested);

        user.veMoe = newVeMoe;

        emit Claim(account, deltaVeMoe);
    }

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

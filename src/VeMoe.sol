// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {SafeMath} from "./library/SafeMath.sol";
import {Rewarder} from "./library/Rewarder.sol";
import {Amounts} from "./library/Amounts.sol";
import {Constants} from "./library/Constants.sol";
import {IRewarder} from "./interface/IRewarder.sol";
import {IMasterChef} from "./interface/IMasterChef.sol";
import {IRewarder} from "./interface/IRewarder.sol";
import {IVeMoe} from "./interface/IVeMoe.sol";

contract VeMoe is Ownable, IVeMoe {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Rewarder for Rewarder.Parameter;
    using Amounts for Amounts.Parameter;
    using EnumerableSet for EnumerableSet.UintSet;

    IERC20 private immutable _moe;
    IMasterChef private immutable _masterChef;

    uint256 private _veMoePerSecond;
    uint256 private _maxVeMoePerMoe;

    uint256 private _topPidsTotalVotes;
    EnumerableSet.UintSet private _topPids;

    VeRewarder private _veRewarder;
    Reward[] private _rewards;

    // pid to Vote
    Amounts.Parameter private _votes;

    mapping(address => User) private _users;
    mapping(IRewarder => mapping(uint256 => uint256)) private _bribesTotalVotes;

    constructor(IERC20 moe, IMasterChef masterChef, address initialOwner) Ownable(initialOwner) {
        _moe = moe;
        _masterChef = masterChef;
    }

    function getVeMoe(address account) external view returns (uint256) {
        User storage user = _users[account];
        VeRewarder storage veRewarder = _veRewarder;

        Rewarder.Parameter storage rewarder = veRewarder.rewarder;

        uint256 totalAddedVeAmount = rewarder.getTotalRewards(_veMoePerSecond);
        uint256 pendingVeAmount = rewarder.getPendingReward(veRewarder.amounts, account, totalAddedVeAmount);

        uint256 newVeMoe = user.veMoe + pendingVeAmount;
        uint256 maxVeMoe = veRewarder.amounts.getAmountOf(account) * _maxVeMoePerMoe / Constants.PRECISION;

        return newVeMoe > maxVeMoe ? maxVeMoe : newVeMoe;
    }

    function getVeMoeParameters() external view returns (uint256 veMoePerSecond, uint256 maxVeMoePerMoe) {
        return (_veMoePerSecond, _maxVeMoePerMoe);
    }

    function getTotalDeposit() external view returns (uint256) {
        return _veRewarder.amounts.getTotalAmount();
    }

    function getVotes(uint256 pid) external view override returns (uint256) {
        return _votes.getAmountOf(pid);
    }

    function getTotalVotes() external view override returns (uint256) {
        return _votes.getTotalAmount();
    }

    function getBribesTotalVotes(IRewarder bribe, uint256 pid) external view returns (uint256) {
        return _bribesTotalVotes[bribe][pid];
    }

    function getBribesOf(address account, uint256 pid) external view returns (IRewarder) {
        return _users[account].bribes[pid];
    }

    function getVotesOf(address account, uint256 pid) external view returns (uint256) {
        return _users[account].votes.getAmountOf(pid);
    }

    function getTotalVotesOf(address account) external view returns (uint256) {
        return _users[account].votes.getTotalAmount();
    }

    function getTopPoolIds() external view override returns (uint256[] memory) {
        return _topPids.values();
    }

    function isInTopPoolIds(uint256 pid) external view override returns (bool) {
        return _topPids.contains(pid);
    }

    function getTopPidsTotalVotes() external view returns (uint256) {
        return _topPidsTotalVotes;
    }

    function stake(uint256 amount) external {
        _modify(msg.sender, int256(amount));

        if (amount > 0) _moe.safeTransferFrom(msg.sender, address(this), amount);
    }

    function unstake(uint256 amount) external {
        _modify(msg.sender, -int256(amount));

        if (amount > 0) _moe.safeTransfer(msg.sender, amount);
    }

    function claim() external {
        _modify(msg.sender, 0);
    }

    function vote(uint256[] calldata pids, int256[] calldata deltaAmounts) external {
        if (pids.length != deltaAmounts.length) revert VeMoe__InvalidLength();

        _masterChef.updateAll(_topPids.values());

        User storage user = _users[msg.sender];

        for (uint256 i; i < pids.length; ++i) {
            int256 deltaAmount = deltaAmounts[i];
            uint256 pid = pids[i];

            (uint256 oldUserVotes, uint256 newUserVotes,,) = user.votes.update(pid, deltaAmount);
            _votes.update(pid, deltaAmount);

            if (_topPids.contains(pid)) _topPidsTotalVotes.addDelta(deltaAmount);

            if (deltaAmount >= 0) {
                _bribesTotalVotes[user.bribes[pid]][pid] += uint256(deltaAmount);
            } else {
                _bribesTotalVotes[user.bribes[pid]][pid] -= uint256(-deltaAmount);
            }

            IRewarder bribe = user.bribes[pid];

            if (address(bribe) != address(0)) {
                uint256 totalVotes = _bribesTotalVotes[bribe][pid];

                _bribesTotalVotes[bribe][pid] = totalVotes.addDelta(deltaAmount);

                bribe.onModify(msg.sender, pid, oldUserVotes, newUserVotes, totalVotes); // todo should use the totalVotes on this bribes, not the total
            }
        }

        if (user.votes.getTotalAmount() > user.veMoe) revert VeMoe__InsufficientVeMoe();

        emit Vote(msg.sender, pids, deltaAmounts);
    }

    function setBribes(uint256[] calldata pids, IRewarder[] calldata bribes) external {
        if (pids.length != bribes.length) revert VeMoe__InvalidLength();

        User storage user = _users[msg.sender];

        for (uint256 i; i < pids.length; ++i) {
            uint256 pid = pids[i];

            IRewarder newBribe = bribes[i];
            IRewarder oldBribe = user.bribes[pid];

            if (oldBribe == newBribe) continue;

            uint256 userVotes = user.votes.getAmountOf(pid);

            user.bribes[pid] = newBribe;

            if (address(oldBribe) != address(0)) {
                uint256 totalVotes = _bribesTotalVotes[oldBribe][pid];
                _bribesTotalVotes[oldBribe][pid] = totalVotes - userVotes;

                oldBribe.onModify(msg.sender, pid, userVotes, 0, totalVotes);
            }
            if (address(newBribe) != address(0)) {
                uint256 totalVotes = _bribesTotalVotes[newBribe][pid];
                _bribesTotalVotes[newBribe][pid] = totalVotes + userVotes;

                newBribe.onModify(msg.sender, pid, 0, userVotes, totalVotes);
            }
        }

        emit BribesSet(msg.sender, pids, bribes);
    }

    function claimBribes(uint256[] calldata pids) external {
        User storage user = _users[msg.sender];

        for (uint256 i; i < pids.length; ++i) {
            uint256 pid = pids[i];

            IRewarder bribe = user.bribes[pid];

            if (address(bribe) != address(0)) {
                uint256 userVotes = user.votes.getAmountOf(pid);
                uint256 totalVotes = _bribesTotalVotes[bribe][pid];

                bribe.onModify(msg.sender, pid, userVotes, userVotes, totalVotes);
            }
        }

        emit BribesSet(msg.sender, pids, new IRewarder[](pids.length));
    }

    function emergencyUnsetBribe(uint256[] calldata pids) external {
        User storage user = _users[msg.sender];

        for (uint256 i; i < pids.length; ++i) {
            uint256 pid = pids[i];

            IRewarder bribe = user.bribes[pid];

            if (address(bribe) == address(0)) revert VeMoe__NoBribeForPid(pid);

            uint256 userVotes = user.votes.getAmountOf(pid);
            _bribesTotalVotes[bribe][pid] -= userVotes;

            delete user.bribes[pid];
        }

        emit BribesSet(msg.sender, pids, new IRewarder[](pids.length));
    }

    function setTopPoolIds(uint256[] calldata pids) external onlyOwner {
        uint256 length = pids.length;

        if (length > Constants.MAX_NUMBER_OF_FARMS) revert VeMoe__TooManyPoolIds();

        uint256 oldLength = _topPids.length();
        while (oldLength > 0) {
            _topPids.remove(_topPids.at(--oldLength));
        }

        uint256 totalVotes;
        for (uint256 i; i < length; ++i) {
            uint256 pid = pids[i];

            if (!_topPids.add(pid)) revert VeMoe__InvalidLength();

            uint256 votes = _votes.getAmountOf(pid);
            totalVotes += votes;
        }

        _topPidsTotalVotes = totalVotes;

        emit TopPoolIdsSet(pids);
    }

    function _modify(address account, int256 deltaAmount) private {
        (uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply, uint256 newTotalSupply) =
            _updateUser(account, deltaAmount);

        _claim(account, oldBalance, newBalance, oldTotalSupply, newTotalSupply);
    }

    function _updateUser(address account, int256 deltaAmount)
        private
        returns (uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply, uint256 newTotalSupply)
    {
        User storage user = _users[account];
        Rewarder.Parameter storage rewarder = _veRewarder.rewarder;

        (oldBalance, newBalance, oldTotalSupply, newTotalSupply) = _veRewarder.amounts.update(account, deltaAmount);

        uint256 totalAddedVeAmount = rewarder.getTotalRewards(_veMoePerSecond);
        uint256 addedVeAmount = rewarder.update(account, oldBalance, newBalance, oldTotalSupply, totalAddedVeAmount);

        uint256 oldVeMoe = user.veMoe;
        uint256 newVeMoe;

        if (deltaAmount >= 0) {
            newVeMoe = oldVeMoe + addedVeAmount;
            uint256 maxVeMoe = oldBalance * _maxVeMoePerMoe / Constants.PRECISION;

            newVeMoe = newVeMoe > maxVeMoe ? maxVeMoe : newVeMoe;
        } else {
            if (user.votes.getTotalAmount() > 0) revert VeMoe__CannotUnstakeWithVotes();

            newVeMoe = 0;
        }

        user.veMoe = newVeMoe;
        user.lastUpdateTimestamp = block.timestamp;

        emit Modify(account, deltaAmount, int256(newVeMoe) - int256(oldVeMoe));
    }

    function _claim(
        address account,
        uint256 oldBalance,
        uint256 newBalance,
        uint256 oldTotalSupply,
        uint256 newTotalSupply
    ) private {
        uint256 length = _rewards.length;

        if (length == 0) return;

        uint256[] memory allRewards = new uint256[](length);
        address[] memory allTokens = new address[](length);

        for (uint256 i; i < length; ++i) {
            Reward storage reward = _rewards[i];

            IERC20 token = reward.token;

            uint256 reserve = reward.reserve;
            uint256 balance = token.balanceOf(address(this)) - (token == _moe ? newTotalSupply : 0);

            uint256 totalRewards = balance - reserve;

            uint256 rewards = reward.rewarder.update(account, oldBalance, newBalance, oldTotalSupply, totalRewards);

            allRewards[i] = rewards;
            allTokens[i] = address(token);

            reward.reserve = balance - rewards;

            if (rewards > 0) token.safeTransfer(account, rewards);
        }

        emit Claim(account, allTokens, allRewards);
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IMoePair} from "./dex/interfaces/IMoePair.sol";
import {IMoe} from "./interfaces/IMoe.sol";
import {IRewarderFactory, IBaseRewarder} from "./interfaces/IRewarderFactory.sol";
import {IMasterChef, IMasterChefRewarder} from "./interfaces/IMasterChef.sol";
import {IVeMoe, IVeMoeRewarder} from "./interfaces/IVeMoe.sol";
import {IJoeStaking, IJoeStakingRewarder} from "./interfaces/IJoeStaking.sol";
import {IMoeStaking} from "./interfaces/IMoeStaking.sol";
import {IStableMoe} from "./interfaces/IStableMoe.sol";
import {Constants} from "./libraries/Constants.sol";

contract MoeLens {
    struct FarmData {
        address masterChef;
        address moe;
        uint256 totalVotes;
        uint256 totalWeight;
        uint256 alpha;
        uint256 totalMoePerSec;
        uint256 totalNumberOfFarms;
        uint256 userTotalVeMoe;
        uint256 userTotalVotes;
        Farm[] farms;
    }

    struct MoeStakingData {
        address moeStakingAddress;
        address veMoeAddress;
        address sMoeAddress;
        uint256 totalStaked;
        uint256 totalVotes;
        uint256 totalWeight;
        uint256 alpha;
        uint256 userStaked;
        uint256 userTotalVeMoe;
        uint256 userTotalVotes;
        Reward[] userRewards;
    }

    struct VeMoeData {
        address moeStakingAddress;
        address veMoeAddress;
        uint256 totalVotes;
        uint256 totalWeight;
        uint256 alpha;
        uint256 maxVeMoe;
        uint256 veMoePerSecondPerMoe;
        uint256[] topPoolsIds;
        Vote[] votes;
        uint256 userTotalVeMoe;
        uint256 userTotalVotes;
    }

    struct VeMoeRewarderData {
        address rewarderFactory;
        uint256 totalNumberOfRewarders;
        Rewarder[] rewarders;
    }

    struct JoeStakingData {
        address joeStakingAddress;
        address joeAddress;
        address rewarderAddress;
        uint256 totalStaked;
        uint256 userStaked;
        Reward userReward;
    }

    struct Farm {
        uint256 pid;
        bool isRewardable;
        uint256 votesOnFarm;
        uint256 moePerSec;
        uint256 totalVotesOnFarm;
        uint256 totalWeightOnFarm;
        Token lpToken;
        uint256 totalStaked;
        uint256 totalSupply;
        Reserves reserves;
        Rewarder rewarder;
        uint256 userVotesOnFarm;
        uint256 userAmount;
        uint256 userPendingMoeReward;
    }

    struct Vote {
        uint256 pid;
        uint256 totalVotesOnFarm;
        uint256 totalWeightOnFarm;
        Rewarder rewarder;
        uint256 userVotesOnFarm;
        uint256 userPendingReward;
    }

    struct Rewarder {
        bool isSet;
        bool isStarted;
        bool isEnded;
        uint256 pid;
        uint256 totalDeposited;
        Reward reward;
        uint256 rewardPerSec;
        uint256 lastUpdateTimestamp;
        uint256 endUpdateTimestamp;
    }

    struct Reward {
        Token token;
        uint256 userPendingAmount;
    }

    struct Reserves {
        Token token0;
        Token token1;
        uint256 reserve0;
        uint256 reserve1;
    }

    struct Token {
        address token;
        uint256 decimals;
        string symbol;
    }

    IMasterChef private immutable _masterchef;
    IMoe private immutable _moe;
    IVeMoe private immutable _veMoe;
    IStableMoe private immutable _stableMoe;
    IMoeStaking private immutable _moeStaking;
    IJoeStaking private immutable _joeStaking;
    IRewarderFactory private immutable _rewarderFactory;

    string private _nativeSymbol;

    constructor(IMasterChef masterchef, IJoeStaking joeStaking, string memory nativeSymbol) {
        _masterchef = masterchef;
        _nativeSymbol = nativeSymbol;
        _joeStaking = joeStaking;

        _moe = masterchef.getMoe();
        _veMoe = masterchef.getVeMoe();
        _rewarderFactory = masterchef.getRewarderFactory();

        _moeStaking = _veMoe.getMoeStaking();
        _stableMoe = IStableMoe(_moeStaking.getSMoe());
    }

    function getFarmData(uint256 start, uint256 nb, address user) external view returns (FarmData memory farms) {
        uint256 nbFarms = _masterchef.getNumberOfFarms();

        nb = start >= nbFarms ? 0 : (start + nb > nbFarms ? nbFarms - start : nb);

        farms = FarmData({
            masterChef: address(_masterchef),
            moe: address(_moe),
            totalVotes: _veMoe.getTotalVotes(),
            totalWeight: _veMoe.getTotalWeight(),
            alpha: _veMoe.getAlpha(),
            totalMoePerSec: _masterchef.getMoePerSecond(),
            totalNumberOfFarms: nbFarms,
            userTotalVeMoe: _veMoe.balanceOf(user),
            userTotalVotes: _veMoe.getTotalVotesOf(user),
            farms: new Farm[](nb)
        });

        for (uint256 i; i < nb; ++i) {
            try this.getFarmDataAt(start + i, user) returns (Farm memory farm) {
                farms.farms[i] = farm;
            } catch {}
        }
    }

    function getFarmDataAt(uint256 pid, address user) external view returns (Farm memory farm) {
        farm.pid = pid;
        farm.isRewardable = _veMoe.isInTopPoolIds(pid);
        farm.votesOnFarm = _veMoe.getVotes(pid);
        farm.moePerSec = _masterchef.getMoePerSecondForPid(pid);
        farm.totalVotesOnFarm = _veMoe.getVotes(pid);
        farm.totalWeightOnFarm = _veMoe.getWeight(pid);

        address lpToken = address(_masterchef.getToken(pid));
        uint256 lpDecimals = IERC20Metadata(lpToken).decimals();

        farm.lpToken = Token({token: lpToken, symbol: IERC20Metadata(lpToken).symbol(), decimals: lpDecimals});

        farm.totalStaked = _masterchef.getTotalDeposit(pid);
        farm.totalSupply = IERC20Metadata(lpToken).totalSupply();

        try this.getPoolDataAt(lpToken) returns (Reserves memory reserves) {
            farm.reserves = reserves;
        } catch {}

        farm.userVotesOnFarm = _veMoe.getVotesOf(user, pid);

        farm.userAmount = _masterchef.getDeposit(pid, user);

        (uint256 moeReward,, uint256 extraReward) = getMasterChefPendingRewardsAt(user, pid);

        farm.userPendingMoeReward = moeReward;

        IMasterChefRewarder rewarder = _masterchef.getExtraRewarder(pid);

        if (address(rewarder) != address(0)) {
            (IERC20 token, uint256 rewardPerSecond, uint256 lastUpdateTimestamp, uint256 endTimestamp) =
                rewarder.getRewarderParameter();

            Reward memory reward;

            try this.getRewardData(address(token), extraReward) returns (Reward memory r) {
                reward = r;
            } catch {}

            farm.rewarder = Rewarder({
                isSet: true,
                isStarted: lastUpdateTimestamp <= block.timestamp,
                isEnded: endTimestamp <= block.timestamp,
                pid: pid,
                totalDeposited: farm.totalStaked,
                reward: reward,
                rewardPerSec: rewardPerSecond,
                lastUpdateTimestamp: lastUpdateTimestamp,
                endUpdateTimestamp: endTimestamp
            });
        }
    }

    function getPoolDataAt(address lpToken) external view returns (Reserves memory reserves) {
        (uint256 reserve0, uint256 reserve1,) = IMoePair(lpToken).getReserves();

        address token0Address = IMoePair(lpToken).token0();
        address token1Address = IMoePair(lpToken).token1();

        uint256 decimals0 = IERC20Metadata(token0Address).decimals();
        uint256 decimals1 = IERC20Metadata(token1Address).decimals();

        reserves.token0 =
            Token({token: token0Address, symbol: IERC20Metadata(token0Address).symbol(), decimals: decimals0});

        reserves.token1 =
            Token({token: token1Address, symbol: IERC20Metadata(token1Address).symbol(), decimals: decimals1});

        reserves.reserve0 = reserve0;
        reserves.reserve1 = reserve1;
    }

    function getMasterChefPendingRewardsAt(address user, uint256 pid)
        public
        view
        returns (uint256 moeReward, address extraToken, uint256 extraReward)
    {
        uint256[] memory pids = new uint256[](1);
        pids[0] = pid;

        (uint256[] memory moeRewards, IERC20[] memory extraTokens, uint256[] memory extraRewards) =
            _masterchef.getPendingRewards(user, pids);

        return (moeRewards[0], address(extraTokens[0]), extraRewards[0]);
    }

    function getStakingData(address user) external view returns (MoeStakingData memory staking) {
        (IERC20[] memory tokens, uint256[] memory amounts) = _stableMoe.getPendingRewards(user);

        Reward[] memory rewards = new Reward[](tokens.length);

        for (uint256 i; i < tokens.length; ++i) {
            try this.getRewardData(address(tokens[i]), amounts[i]) returns (Reward memory reward) {
                rewards[i] = reward;
            } catch {}
        }

        staking = MoeStakingData({
            moeStakingAddress: address(_moeStaking),
            veMoeAddress: address(_veMoe),
            sMoeAddress: address(_stableMoe),
            totalStaked: _moeStaking.getTotalDeposit(),
            totalVotes: _veMoe.getTotalVotes(),
            totalWeight: _veMoe.getTotalWeight(),
            alpha: _veMoe.getAlpha(),
            userStaked: _moeStaking.getDeposit(user),
            userTotalVeMoe: _veMoe.balanceOf(user),
            userTotalVotes: _veMoe.getTotalVotesOf(user),
            userRewards: rewards
        });
    }

    function getRewardData(address token, uint256 amount) external view returns (Reward memory reward) {
        string memory symbol = address(token) == address(0) ? _nativeSymbol : IERC20Metadata(address(token)).symbol();
        uint256 decimals = address(token) == address(0) ? 18 : IERC20Metadata(address(token)).decimals();

        reward = Reward({token: Token({token: token, symbol: symbol, decimals: decimals}), userPendingAmount: amount});
    }

    function getVeMoeData(uint256 start, uint256 nb, address user) public view returns (VeMoeData memory data) {
        uint256 nbFarms = _masterchef.getNumberOfFarms();

        nb = start >= nbFarms ? 0 : (start + nb > nbFarms ? nbFarms - start : nb);

        uint256 balance = _veMoe.balanceOf(user);

        data = VeMoeData({
            moeStakingAddress: address(_moeStaking),
            veMoeAddress: address(_veMoe),
            totalVotes: _veMoe.getTotalVotes(),
            totalWeight: _veMoe.getTotalWeight(),
            alpha: _veMoe.getAlpha(),
            maxVeMoe: balance * _veMoe.getMaxVeMoePerMoe() / Constants.PRECISION,
            veMoePerSecondPerMoe: _veMoe.getVeMoePerSecondPerMoe(),
            topPoolsIds: _veMoe.getTopPoolIds(),
            votes: new Vote[](nb),
            userTotalVeMoe: balance,
            userTotalVotes: _veMoe.getTotalVotesOf(user)
        });

        for (uint256 i; i < nb; ++i) {
            try this.getVeMoeDataAt(start + i, user) returns (Vote memory vote) {
                data.votes[i] = vote;
            } catch {}
        }
    }

    function getVeMoeDataAt(uint256 pid, address user) public view returns (Vote memory vote) {
        vote.pid = pid;
        vote.userVotesOnFarm = _veMoe.getVotesOf(user, pid);
        vote.totalVotesOnFarm = _veMoe.getVotes(pid);
        vote.totalWeightOnFarm = _veMoe.getWeight(pid);

        IVeMoeRewarder bribe = _veMoe.getBribesOf(user, pid);

        if (address(bribe) != address(0)) {
            (IERC20 token, uint256 rewardPerSecond, uint256 lastUpdateTimestamp, uint256 endTimestamp) =
                bribe.getRewarderParameter();

            Reward memory reward;

            uint256[] memory pids = new uint256[](1);
            pids[0] = pid;

            (, uint256[] memory extraRewards) = _veMoe.getPendingRewards(user, pids);

            try this.getRewardData(address(token), extraRewards[0]) returns (Reward memory r) {
                reward = r;
            } catch {}

            vote.rewarder = Rewarder({
                isSet: true,
                isStarted: lastUpdateTimestamp <= block.timestamp,
                isEnded: endTimestamp <= block.timestamp,
                pid: pid,
                totalDeposited: _veMoe.getBribesTotalVotes(bribe, pid),
                reward: reward,
                rewardPerSec: rewardPerSecond,
                lastUpdateTimestamp: lastUpdateTimestamp,
                endUpdateTimestamp: endTimestamp
            });
        }
    }

    function getVeMoeRewarderData(uint256 start, uint256 nb) external view returns (VeMoeRewarderData memory data) {
        uint256 nbRewarders = _rewarderFactory.getRewarderCount(IRewarderFactory.RewarderType.VeMoeRewarder);

        nb = start >= nbRewarders ? 0 : (start + nb > nbRewarders ? nbRewarders - start : nb);

        data = VeMoeRewarderData({
            rewarderFactory: address(_rewarderFactory),
            totalNumberOfRewarders: nbRewarders,
            rewarders: new Rewarder[](nb)
        });

        for (uint256 i; i < nb; ++i) {
            try this.getVeMoeRewarderDataAt(start + i) returns (Rewarder memory rewarder) {
                data.rewarders[i] = rewarder;
            } catch {}
        }
    }

    function getVeMoeRewarderDataAt(uint256 index) external view returns (Rewarder memory rewarder) {
        IBaseRewarder rewarderContract =
            _rewarderFactory.getRewarderAt(IRewarderFactory.RewarderType.VeMoeRewarder, index);

        (IERC20 token, uint256 rewardPerSecond, uint256 lastUpdateTimestamp, uint256 endTimestamp) =
            rewarderContract.getRewarderParameter();

        uint256 pid = rewarderContract.getPid();

        Reward memory reward;
        try this.getRewardData(address(token), 0) returns (Reward memory r) {
            reward = r;
        } catch {}

        rewarder = Rewarder({
            isSet: false, // Placeholder
            isStarted: lastUpdateTimestamp <= block.timestamp,
            isEnded: endTimestamp <= block.timestamp,
            pid: pid,
            totalDeposited: _veMoe.getBribesTotalVotes(IVeMoeRewarder(address(rewarderContract)), pid),
            reward: reward,
            rewardPerSec: rewardPerSecond,
            lastUpdateTimestamp: lastUpdateTimestamp,
            endUpdateTimestamp: endTimestamp
        });
    }

    function getJoeStakingData(address user) external view returns (JoeStakingData memory data) {
        Reward memory reward;

        (, uint256 amount) = _joeStaking.getPendingReward(user);

        try this.getRewardData(address(_moe), amount) returns (Reward memory r) {
            reward = r;
        } catch {}

        data = JoeStakingData({
            joeStakingAddress: address(_joeStaking),
            joeAddress: address(_moe),
            rewarderAddress: address(_joeStaking.getRewarder()),
            totalStaked: _joeStaking.getTotalDeposit(),
            userStaked: _joeStaking.getDeposit(user),
            userReward: reward
        });
    }
}

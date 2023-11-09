// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IRewarder} from "./IRewarder.sol";

import {Amounts} from "../library/Amounts.sol";

import {Rewarder} from "../library/Rewarder.sol";

interface IVeMoe {
    error VeMoe__InvalidLength();
    error VeMoe__InsufficientVeMoe();
    error VeMoe__InvalidCaller();
    error VeMoe__CannotUnstakeWithVotes();
    error VeMoe__NoBribeForPid(uint256 pid);
    error VeMoe__TooManyPoolIds();
    error VeMoe__RewardAlreadyAdded();
    error VeMoe__VeMoeOverflow();

    struct User {
        uint256 veMoe;
        Amounts.Parameter votes;
        mapping(uint256 => IRewarder) bribes;
    }

    struct Reward {
        Rewarder.Parameter rewarder;
        IERC20 token;
        uint256 reserve;
    }

    event BribesSet(address indexed account, uint256[] pids, IRewarder[] bribes);

    event Claim(address indexed account, int256 deltaVeMoe);

    event RewardAdded(address indexed token);

    event TopPoolIdsSet(uint256[] topPoolIds);

    event Vote(address account, uint256[] pids, int256[] deltaVeAmounts);

    function balanceOf(address account) external view returns (uint256 veMoe);

    function claim(uint256[] memory pids) external;

    function emergencyUnsetBribe(uint256[] memory pids) external;

    function getBribesOf(address account, uint256 pid) external view returns (IRewarder);

    function getBribesTotalVotes(IRewarder bribe, uint256 pid) external view returns (uint256);

    function getTopPidsTotalVotes() external view returns (uint256);

    function getTopPoolIds() external view returns (uint256[] memory);

    function getTotalVotes() external view returns (uint256);

    function getTotalVotesOf(address account) external view returns (uint256);

    function getVeMoeParameters() external view returns (uint256 veMoePerSecond, uint256 maxVeMoePerMoe);

    function getVotes(uint256 pid) external view returns (uint256);

    function getVotesOf(address account, uint256 pid) external view returns (uint256);

    function isInTopPoolIds(uint256 pid) external view returns (bool);

    function onModify(address account, uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply, uint256)
        external;

    function setBribes(uint256[] memory pids, IRewarder[] memory bribes) external;

    function setTopPoolIds(uint256[] memory pids) external;

    function vote(uint256[] memory pids, int256[] memory deltaAmounts) external;
}

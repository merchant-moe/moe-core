// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMultiRewarder} from "./IMultiRewarder.sol";
import {Amounts} from "../library/Amounts.sol";
import {Rewarder} from "../library/Rewarder.sol";

interface IVeMoe {
    error VeMoe__InvalidLength();
    error VeMoe__InsufficientVeMoe();
    error VeMoe__InvalidCaller();
    error VeMoe__CannotUnstakeWithVotes();
    error VeMoe__NoBribeForPid(uint256 pid);

    struct User {
        uint256 veMoe;
        uint256 lastUpdateTimestamp;
        uint256 boostedEndTimestamp;
        Amounts.Parameter votes;
        mapping(uint256 => IMultiRewarder) bribes;
    }

    struct VeRewarder {
        Amounts.Parameter amounts;
        Rewarder.Parameter rewarder;
    }

    struct Reward {
        Rewarder.Parameter rewarder;
        IERC20 token;
        uint256 reserve;
    }

    event Modify(address indexed account, int256 deltaAmount, int256 deltaVeMoe);

    event Claim(address indexed account, address[] tokens, uint256[] rewards);

    event Vote(address account, uint256[] pids, int256[] deltaVeAmounts);

    event BribesSet(address indexed account, uint256[] pids, IMultiRewarder[] bribes);

    function getVotes(uint256 pid) external view returns (uint256);

    function getTotalVotes() external view returns (uint256);
}

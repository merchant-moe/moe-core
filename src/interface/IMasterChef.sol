// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IRewarder} from "./IRewarder.sol";
import {IMoe} from "./IMoe.sol";
import {IVeMoe} from "./IVeMoe.sol";
import {Rewarder} from "../library/Rewarder.sol";
import {Amounts} from "../library/Amounts.sol";

interface IMasterChef {
    error MasterChef__InvalidStartTimestamp();

    struct Farm {
        Amounts.Parameter amounts;
        Rewarder.Parameter rewarder;
        IERC20 token;
        IRewarder extraRewarder;
    }

    event PositionModified(uint256 indexed pid, address indexed account, int256 deltaAmount, uint256 moeReward);

    event ExtraRewardClaimed(address indexed account, uint256 indexed pid, IERC20 indexed token, uint256 amount);

    event MoePerSecondSet(uint256 moePerSecond);

    event FarmAdded(uint256 indexed pid, IERC20 indexed token, uint256 startTimestamp);

    event ExtraRewarderSet(uint256 indexed pid, IRewarder extraRewarder);

    function add(IERC20 token, uint256 startTimestamp, IRewarder extraRewarder) external;

    function claim(uint256[] memory pids) external;

    function deposit(uint256 pid, uint256 amount) external;

    function emergencyWithdraw(uint256 pid) external;

    function getDeposit(uint256 pid, address account) external view returns (uint256);

    function getLastUpdateTimestamp(uint256 pid) external view returns (uint256);

    function getPendingRewards(uint256 pid, address account)
        external
        view
        returns (uint256 moeReward, IERC20 extraToken, uint256 extraReward);

    function getExtraRewarder(uint256 pid) external view returns (IRewarder);

    function getMoe() external view returns (IMoe);

    function getMoePerSecond() external view returns (uint256);

    function getToken(uint256 pid) external view returns (IERC20);

    function getTotalDeposit(uint256 pid) external view returns (uint256);

    function getVeMoe() external view returns (IVeMoe);

    function setExtraRewarder(uint256 pid, IRewarder extraRewarder) external;

    function setMoePerSecond(uint256 moePerSecond) external;

    function updateAll() external;

    function withdraw(uint256 pid, uint256 amount) external;
}

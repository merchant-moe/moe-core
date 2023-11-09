// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRewarder {
    error Rewarder__NativeTransferFailed();
    error Rewarder__InvalidCaller();
    error Rewarder__NotStopped();
    error Rewarder__Stopped();
    error Rewarder__AlreadyStopped();
    error Rewarder__NotNativeToken();
    error Rewarder__InvalidToken();
    error Rewarder__InsufficientReward(uint256 remainingReward, uint256 expectedReward);
    error Rewarder__InvalidDuration();

    event Claim(address indexed account, IERC20 indexed token, uint256 reward);

    event RewardPerSecondSet(uint256 rewardPerSecond, uint256 endTimestamp);

    function getCaller() external view returns (address);

    function getRewarderParameter()
        external
        view
        returns (IERC20 token, uint256 rewardPerSecond, uint256 lastUpdateTimestamp, uint256 endTimestamp);

    function getPendingReward(address account, uint256 balance, uint256 totalSupply)
        external
        view
        returns (IERC20 token, uint256 pendingReward);

    function isStopped() external view returns (bool);

    function setRewardPerSecond(uint256 rewardPerSecond, uint256 expectedDuration) external;

    function stop() external;

    function sweep(IERC20 token, address account) external;

    function onModify(address account, uint256 pid, uint256 oldBalance, uint256 newBalance, uint256 totalSupply)
        external;
}

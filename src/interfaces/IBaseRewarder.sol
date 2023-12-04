// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBaseRewarder {
    error BaseRewarder__NativeTransferFailed();
    error BaseRewarder__InvalidCaller();
    error BaseRewarder__Stopped();
    error BaseRewarder__AlreadyStopped();
    error BaseRewarder__NotNativeRewarder();
    error BaseRewarder__ZeroAmount();
    error BaseRewarder__InsufficientReward(uint256 remainingReward, uint256 expectedReward);
    error BaseRewarder__InvalidDuration();
    error BaseRewarder__InvalidPid(uint256 pid);
    error BaseRewarder__InvalidStartTimestamp(uint256 startTimestamp);

    event Claim(address indexed account, IERC20 indexed token, uint256 reward);

    event RewardParameterUpdated(uint256 rewardPerSecond, uint256 startTimestamp, uint256 endTimestamp);

    event Stopped();

    event Swept(IERC20 indexed token, address indexed account, uint256 amount);

    function getToken() external view returns (IERC20);

    function getCaller() external view returns (address);

    function getPid() external view returns (uint256);

    function getRewarderParameter()
        external
        view
        returns (IERC20 token, uint256 rewardPerSecond, uint256 lastUpdateTimestamp, uint256 endTimestamp);

    function getPendingReward(address account, uint256 balance, uint256 totalSupply)
        external
        view
        returns (IERC20 token, uint256 pendingReward);

    function isStopped() external view returns (bool);

    function initialize(address initialOwner) external;

    function setRewardPerSecond(uint256 rewardPerSecond, uint256 expectedDuration) external;

    function setRewarderParameters(uint256 rewardPerSecond, uint256 startTimestamp, uint256 expectedDuration)
        external;

    function stop() external;

    function sweep(IERC20 token, address account) external;

    function onModify(address account, uint256 pid, uint256 oldBalance, uint256 newBalance, uint256 totalSupply)
        external
        returns (uint256);
}

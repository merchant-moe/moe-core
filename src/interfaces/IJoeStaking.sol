// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IJoeStaking {
    event PositionModified(address indexed account, int256 deltaAmount);

    function getJoe() external view returns (address);

    function getRewarder() external view returns (address);

    function getDeposit(address account) external view returns (uint256);

    function getTotalDeposit() external view returns (uint256);

    function getPendingReward(address account) external view returns (IERC20, uint256);

    function stake(uint256 amount) external;

    function unstake(uint256 amount) external;

    function claim() external;
}
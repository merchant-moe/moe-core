// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IRewarder} from "./IRewarder.sol";
import {Amounts} from "../library/Amounts.sol";
import {Rewarder} from "../library/Rewarder.sol";

interface IMoeStaking {
    event PositionModified(address indexed account, int256 deltaAmount);

    function getMoe() external view returns (address);

    function getVeMoe() external view returns (address);

    function getSMoe() external view returns (address);

    function getDeposit(address account) external view returns (uint256);

    function getTotalDeposit() external view returns (uint256);

    function stake(uint256 amount) external;

    function unstake(uint256 amount) external;

    function claim() external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBaseRewarder} from "./IBaseRewarder.sol";

interface IJoeStakingRewarder is IBaseRewarder {
    function setAidropParameters(uint256 amount, uint256 timestamp) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IBaseRewarder} from "../interfaces/IBaseRewarder.sol";

interface IRewarderFactory {
    error RewarderFactory__ZeroAddress();
    error RewarderFactory__InvalidRewarderType();
    error RewarderFactory__InvalidPid();

    enum RewarderType {
        InvalidRewarder,
        MasterChefRewarder,
        VeMoeRewarder,
        JoeStakingRewarder
    }

    event RewarderCreated(
        RewarderType indexed rewarderType, IERC20 indexed token, uint256 indexed pid, IBaseRewarder rewarder
    );

    event RewarderImplementationSet(RewarderType indexed rewarderType, IBaseRewarder indexed implementation);

    function getRewarderImplementation(RewarderType rewarderType) external view returns (IBaseRewarder);

    function getRewarderCount(RewarderType rewarderType) external view returns (uint256);

    function getRewarderAt(RewarderType rewarderType, uint256 index) external view returns (IBaseRewarder);

    function getRewarderType(IBaseRewarder rewarder) external view returns (RewarderType);

    function setRewarderImplementation(RewarderType rewarderType, IBaseRewarder implementation) external;

    function createRewarder(RewarderType rewarderType, IERC20 token, uint256 pid) external returns (IBaseRewarder);
}

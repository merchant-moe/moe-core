// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IBaseRewarder} from "../interfaces/IBaseRewarder.sol";

interface IRewarderFactory {
    error RewarderFactory__ZeroAddress();

    event MasterchefRewarderImplementationUpdated(IBaseRewarder indexed implementation);

    event VeMoeRewarderImplementationUpdated(IBaseRewarder indexed implementation);

    event MasterchefRewarderCreated(IBaseRewarder indexed rewarder);

    event VeMoeRewarderCreated(IBaseRewarder indexed rewarder);

    function getMasterchefRewarderImplementation() external view returns (IBaseRewarder);

    function getVeMoeRewarderImplementation() external view returns (IBaseRewarder);

    function getMasterchefRewarderCount() external view returns (uint256);

    function getVeMoeRewarderCount() external view returns (uint256);

    function getMasterchefRewarderAt(uint256 index) external view returns (IBaseRewarder);

    function getVeMoeRewarderAt(uint256 index) external view returns (IBaseRewarder);

    function isMasterchefRewarder(IBaseRewarder rewarder) external view returns (bool);

    function isVeMoeRewarder(IBaseRewarder rewarder) external view returns (bool);

    function setMasterchefRewarderImplementation(IBaseRewarder implementation) external;

    function setVeMoeRewarderImplementation(IBaseRewarder implementation) external;

    function createMasterchefRewarder(IERC20 token, uint256 pid) external returns (IBaseRewarder);

    function createVeMoeRewarder(IERC20 token, uint256 pid) external returns (IBaseRewarder);
}

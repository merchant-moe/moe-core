// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMoe} from "./IMoe.sol";
import {IVeMoe} from "./IVeMoe.sol";
import {IStableMoe} from "./IStableMoe.sol";

interface IMoeStaking {
    event PositionModified(address indexed account, int256 deltaAmount);

    function getMoe() external view returns (IMoe);

    function getVeMoe() external view returns (IVeMoe);

    function getSMoe() external view returns (IStableMoe);

    function getDeposit(address account) external view returns (uint256);

    function getTotalDeposit() external view returns (uint256);

    function stake(uint256 amount) external;

    function unstake(uint256 amount) external;

    function claim() external;
}

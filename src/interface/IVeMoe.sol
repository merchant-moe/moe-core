// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVeMoe is IERC20 {
    function getVotes(uint256 pid) external view returns (uint256);
    function getTotalVotes() external view returns (uint256);
}

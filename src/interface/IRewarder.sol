// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRewarder {
    function getPendingReward(address account, uint256 balance, uint256 totalSupply)
        external
        view
        returns (IERC20 token, uint256 pendingReward);
    function claim(address account, uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply)
        external
        returns (IERC20 token, uint256 reward);
    function link(uint256 pid) external;
    function unlink() external;
}

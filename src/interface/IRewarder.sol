// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRewarder {
    error Rewarder__NativeTransferFailed();
    error Rewarder__InvalidCaller();
    error Rewarder__AlreadyLinked();
    error Rewarder__NotLinked();
    error Rewarder__NotStopped();
    error Rewarder__Stopped();
    error Rewarder__NotNativeToken();
    error Rewarder__InvalidToken();

    enum Status {
        Unlinked,
        Linked,
        Stopped
    }

    event Claim(address indexed account, IERC20 indexed token, uint256 reward);

    function getPendingReward(address account, uint256 balance, uint256 totalSupply)
        external
        view
        returns (IERC20 token, uint256 pendingReward);

    function onModify(address account, uint256 pid, uint256 oldBalance, uint256 newBalance, uint256 totalSupply)
        external;

    function link(uint256 pid) external;

    function unlink(uint256 pid) external;
}

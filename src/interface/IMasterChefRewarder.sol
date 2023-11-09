// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IRewarder} from "./IRewarder.sol";

interface IMasterChefRewarder is IRewarder {
    error MasterChefRewarder__InvalidPid(uint256 pid);
    error MasterChefRewarder__AlreadyLinked();
    error MasterChefRewarder__NotLinked();
    error MasterChefRewarder__UseUnlink();

    enum Status {
        Unlinked,
        Linked,
        Stopped
    }

    function getPid() external view returns (uint256);

    function link(uint256 pid) external;

    function unlink(uint256 pid) external;
}

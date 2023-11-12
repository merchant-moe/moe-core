// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBaseRewarder} from "./IBaseRewarder.sol";

interface IMasterChefRewarder is IBaseRewarder {
    error MasterChefRewarder__AlreadyLinked();
    error MasterChefRewarder__NotLinked();
    error MasterChefRewarder__UseUnlink();

    enum Status {
        Unlinked,
        Linked,
        Stopped
    }

    function link(uint256 pid) external;

    function unlink(uint256 pid) external;
}

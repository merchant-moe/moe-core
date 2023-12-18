// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMasterChefRewarder} from "../interfaces/IMasterChefRewarder.sol";
import {IMasterChef} from "../interfaces/IMasterChef.sol";
import {BaseRewarder, IBaseRewarder} from "./BaseRewarder.sol";

/**
 * @title MasterChef Rewarder Contract
 * @dev Contract for distributing rewards to stakers in the MasterChef contract.
 */
contract MasterChefRewarder is BaseRewarder, IMasterChefRewarder {
    Status internal _status;

    /**
     * @dev Constructor for MasterChefRewarder contract.
     * @param caller The address of the contract that will call the onModify function.
     */
    constructor(address caller) BaseRewarder(caller) {}

    /**
     * @dev Links the rewarder to the MasterChef contract.
     * Can only be called by the caller contract and only once.
     * @param pid The pool ID of the staking pool.
     */
    function link(uint256 pid) public override {
        if (msg.sender != _caller) revert BaseRewarder__InvalidCaller();
        if (_status != Status.Unlinked) revert MasterChefRewarder__AlreadyLinked();
        if (pid != _pid()) revert BaseRewarder__InvalidPid(pid);
        if (_isStopped) revert BaseRewarder__Stopped();

        _status = Status.Linked;
    }

    /**
     * @dev Unlinks the rewarder from the MasterChef contract.
     * Can only be called by the caller contract and only once.
     * @param pid The pool ID of the staking pool.
     */
    function unlink(uint256 pid) public override {
        if (msg.sender != _caller) revert BaseRewarder__InvalidCaller();
        if (pid != _pid()) revert BaseRewarder__InvalidPid(pid);
        if (_status != Status.Linked) revert MasterChefRewarder__NotLinked();

        _status = Status.Stopped;
        _isStopped = true;
    }

    /**
     * @dev Reverts as the MasterChefRewarder contract should be stopped by the unlink function.
     */
    function stop() public pure override(IBaseRewarder, BaseRewarder) {
        revert MasterChefRewarder__UseUnlink();
    }

    /**
     * @dev Called by the caller contract to update the rewards for a given account.
     * If the rewarder is not linked, the function will revert.
     * @param account The account to update rewards for.
     * @param pid The pool ID of the staking pool.
     * @param oldBalance The old balance of the account.
     * @param newBalance The new balance of the account.
     * @param oldTotalSupply The old total supply of the staking pool.
     * @return reward The amount of rewards sent to the account.
     */
    function onModify(address account, uint256 pid, uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply)
        public
        override(BaseRewarder, IBaseRewarder)
        returns (uint256 reward)
    {
        if (_status != Status.Linked) revert MasterChefRewarder__NotLinked();

        reward = BaseRewarder.onModify(account, pid, oldBalance, newBalance, oldTotalSupply);

        _claim(account, reward);
    }

    /**
     * @dev Returns the total supply of the staking pool.
     * @return The total supply of the staking pool.
     */
    function _getTotalSupply() internal view override returns (uint256) {
        return _status != Status.Linked ? 0 : IMasterChef(_caller).getTotalDeposit(_pid());
    }
}

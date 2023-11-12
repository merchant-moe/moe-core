// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Math} from "./libraries/Math.sol";
import {Amounts} from "./libraries/Amounts.sol";
import {IMoeStaking} from "./interfaces/IMoeStaking.sol";
import {IVeMoe} from "./interfaces/IVeMoe.sol";
import {IStableMoe} from "./interfaces/IStableMoe.sol";

/**
 * @title Moe Staking Contract
 * @dev The Moe Staking Contract allows users to stake MOE tokens to sMoe and veMoe.
 * veMoe will allow users to vote on pool weights in the MasterChef contract.
 * sMOE will allow users to receive rewards from the volume of the DEX.
 */
contract MoeStaking is IMoeStaking {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using Amounts for Amounts.Parameter;

    IERC20 private immutable _moe;
    IVeMoe private immutable _veMoe;
    IStableMoe private immutable _sMoe;

    Amounts.Parameter private _amounts;

    /**
     * @dev Constructor for MoeStaking contract.
     * @param moe The MOE token.
     * @param veMoe The veMOE token.
     * @param sMoe The sMOE token.
     */
    constructor(IERC20 moe, IVeMoe veMoe, IStableMoe sMoe) {
        _moe = moe;
        _veMoe = veMoe;
        _sMoe = sMoe;
    }

    /**
     * @dev Returns the MOE token.
     * @return The MOE token.
     */
    function getMoe() external view override returns (address) {
        return address(_moe);
    }

    /**
     * @dev Returns the veMOE token.
     * @return The veMOE token.
     */
    function getVeMoe() external view override returns (address) {
        return address(_veMoe);
    }

    /**
     * @dev Returns the sMOE token.
     * @return The sMOE token.
     */
    function getSMoe() external view override returns (address) {
        return address(_sMoe);
    }

    /**
     * @dev Returns the amount of MOE tokens staked by an account.
     * @param account The account to check.
     * @return The amount of MOE tokens staked by the account.
     */
    function getDeposit(address account) external view override returns (uint256) {
        return _amounts.getAmountOf(account);
    }

    /**
     * @dev Returns the total amount of MOE tokens staked.
     * @return The total amount of MOE tokens staked.
     */
    function getTotalDeposit() external view override returns (uint256) {
        return _amounts.getTotalAmount();
    }

    /**
     * @dev Stakes MOE tokens.
     * @param amount The amount of MOE tokens to stake.
     */
    function stake(uint256 amount) external override {
        _modify(msg.sender, int256(amount));

        if (amount > 0) _moe.safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @dev Unstakes MOE tokens.
     * @param amount The amount of MOE tokens to unstake.
     */
    function unstake(uint256 amount) external override {
        _modify(msg.sender, -int256(amount));

        if (amount > 0) _moe.safeTransfer(msg.sender, amount);
    }

    /**
     * @dev Claims rewards from veMOE and sMOE.
     */
    function claim() external override {
        _modify(msg.sender, 0);
    }

    /**
     * @dev Modifies the staking position of an account.
     * Will update the veMOE and sMOE positions of the account.
     * @param account The account to modify.
     * @param deltaAmount The delta amount to modify.
     */
    function _modify(address account, int256 deltaAmount) private {
        (uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply, uint256 newTotalSupply) =
            _amounts.update(account, deltaAmount);

        _veMoe.onModify(account, oldBalance, newBalance, oldTotalSupply, newTotalSupply);
        _sMoe.onModify(account, oldBalance, newBalance, oldTotalSupply, newTotalSupply);

        emit PositionModified(account, deltaAmount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Math} from "./library/Math.sol";
import {Amounts} from "./library/Amounts.sol";
import {IMoeStaking} from "./interface/IMoeStaking.sol";

interface IRewarder {
    function onModify(
        address account,
        uint256 oldBalance,
        uint256 newBalance,
        uint256 oldTotalSupply,
        uint256 newTotalSupply
    ) external;
}

contract MoeStaking is IMoeStaking {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using Amounts for Amounts.Parameter;

    IERC20 private immutable _moe;
    IRewarder private immutable _veMoe;
    IRewarder private immutable _sMoe;

    Amounts.Parameter private _amounts;

    constructor(IERC20 moe, IRewarder veMoe, IRewarder sMoe) {
        _moe = moe;
        _veMoe = veMoe;
        _sMoe = sMoe;
    }

    function getMoe() external view override returns (address) {
        return address(_moe);
    }

    function getVeMoe() external view override returns (address) {
        return address(_veMoe);
    }

    function getSMoe() external view override returns (address) {
        return address(_sMoe);
    }

    function getDeposit(address account) external view override returns (uint256) {
        return _amounts.getAmountOf(account);
    }

    function getTotalDeposit() external view override returns (uint256) {
        return _amounts.getTotalAmount();
    }

    function stake(uint256 amount) external override {
        _modify(msg.sender, int256(amount));

        _moe.safeTransferFrom(msg.sender, address(this), amount);
    }

    function unstake(uint256 amount) external override {
        _modify(msg.sender, -int256(amount));

        _moe.safeTransfer(msg.sender, amount);
    }

    function claim() external override {
        _modify(msg.sender, 0);
    }

    function _modify(address account, int256 deltaAmount) private {
        (uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply, uint256 newTotalSupply) =
            _amounts.update(account, deltaAmount);

        _veMoe.onModify(account, oldBalance, newBalance, oldTotalSupply, newTotalSupply);
        _sMoe.onModify(account, oldBalance, newBalance, oldTotalSupply, newTotalSupply);

        emit PositionModified(account, deltaAmount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IVestingContract} from "./interfaces/IVestingContract.sol";

/**
 * @title Vesting Contract
 * @dev This contract implements a vesting contract. Only the owner of the master chef contract can set the beneficiary
 * and only the beneficiary can release the vested tokens.
 */
contract VestingContract is IVestingContract {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    address private immutable _masterChef;

    IERC20 private immutable _token;
    uint256 private immutable _start;
    uint256 private immutable _duration;

    address private _beneficiary;
    uint88 private _released;
    bool private _revoked;

    /**
     * @dev Constructor for the Vesting Contract.
     * @param masterChef_ The address of the master chef contract.
     * @param token_ The address of the token contract.
     * @param start_ The timestamp at which the vesting starts.
     * @param duration_ The duration of the vesting.
     */
    constructor(address masterChef_, IERC20 token_, uint256 start_, uint256 duration_) {
        _masterChef = masterChef_;
        _token = token_;
        _start = start_;
        _duration = duration_;
    }

    /**
     * @dev Returns the address of the master chef contract.
     * @return The address of the master chef contract.
     */
    function masterChef() public view virtual override returns (address) {
        return _masterChef;
    }

    /**
     * @dev Returns the address of the token contract.
     * @return The address of the token contract.
     */
    function token() public view virtual override returns (IERC20) {
        return _token;
    }

    /**
     * @dev Returns the timestamp at which the vesting starts.
     * @return The timestamp at which the vesting starts.
     */
    function start() public view virtual override returns (uint256) {
        return _start;
    }

    /**
     * @dev Returns the duration of the vesting.
     * @return The duration of the vesting.
     */
    function duration() public view virtual override returns (uint256) {
        return _duration;
    }

    /**
     * @dev Returns the timestamp at which the vesting ends.
     * @return The timestamp at which the vesting ends.
     */
    function end() public view virtual override returns (uint256) {
        return _start + _duration;
    }

    /**
     * @dev Returns the address of the beneficiary.
     * @return The address of the beneficiary.
     */
    function beneficiary() public view virtual override returns (address) {
        return _beneficiary;
    }

    /**
     * @dev Returns whether the vesting contract has been revoked.
     * @return Whether the vesting contract has been revoked.
     */
    function revoked() public view virtual override returns (bool) {
        return _revoked;
    }

    /**
     * @dev Returns the amount of tokens that have been released.
     * @return The amount of tokens that have been released.
     */
    function released() public view virtual override returns (uint256) {
        return _released;
    }

    /**
     * @dev Returns the amount of tokens that can be released.
     * @return The amount of tokens that can be released.
     */
    function releasable() public view virtual override returns (uint256) {
        return vestedAmount(block.timestamp) - released();
    }

    /**
     * @dev Returns the amount of tokens that have been vested at the specified timestamp.
     * @param timestamp The timestamp at which the amount of vested tokens will be calculated.
     * @return The amount of tokens that have been vested at the specified timestamp.
     */
    function vestedAmount(uint256 timestamp) public view virtual override returns (uint256) {
        return _vestingSchedule(_token.balanceOf(address(this)) + released(), timestamp);
    }

    /**
     * @dev Releases the vested tokens to the beneficiary.
     */
    function release() public virtual override {
        if (msg.sender != _beneficiary) revert VestingContract__NotBeneficiary();

        uint256 amount = releasable();
        _released += amount.toUint88();

        _token.safeTransfer(_beneficiary, amount);

        emit Released(_beneficiary, amount);
    }

    /**
     * @dev Sets the beneficiary.
     * @param newBeneficiary The address of the new beneficiary.
     */
    function setBeneficiary(address newBeneficiary) public virtual override {
        if (msg.sender != Ownable(_masterChef).owner()) revert VestingContract__NotMasterChefOwner();

        _beneficiary = newBeneficiary;

        emit BeneficiarySet(newBeneficiary);
    }

    /**
     * @dev Revokes the vesting contract.
     */
    function revoke() public virtual {
        address owner = Ownable(_masterChef).owner();

        if (msg.sender != owner) revert VestingContract__NotMasterChefOwner();

        uint256 released_ = released();
        uint256 balance = _token.balanceOf(address(this));
        uint256 vested = _vestingSchedule(balance + released_, block.timestamp);

        _revoked = true;

        _token.safeTransfer(owner, balance + released_ - vested);

        emit Revoked();
    }

    /**
     * @dev Calculates the amount of tokens that have been vested at the specified timestamp.
     * @param total The total amount of tokens to be vested.
     * @param timestamp The timestamp at which the amount of vested tokens will be calculated.
     * @return The amount of tokens that have been vested at the specified timestamp.
     */
    function _vestingSchedule(uint256 total, uint256 timestamp) internal view virtual returns (uint256) {
        if (_revoked) return total;

        if (timestamp < start()) {
            return 0;
        } else if (timestamp >= end()) {
            return total;
        } else {
            return (total * (timestamp - start())) / duration();
        }
    }
}

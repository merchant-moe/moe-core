// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVestingContract {
    error VestingContract__NotBeneficiary();
    error VestingContract__NotMasterChefOwner();
    error VestingContract__AlreadyRevoked();
    error VestingContract__InvalidCliffDuration();

    event BeneficiarySet(address beneficiary);

    event Released(address beneficiary, uint256 amount);

    event Revoked();

    function masterChef() external view returns (address);

    function token() external view returns (IERC20);

    function start() external view returns (uint256);

    function cliffDuration() external view returns (uint256);

    function vestingDuration() external view returns (uint256);

    function end() external view returns (uint256);

    function beneficiary() external view returns (address);

    function revoked() external view returns (bool);

    function released() external view returns (uint256);

    function releasable() external view returns (uint256);

    function vestedAmount(uint256 timestamp) external view returns (uint256);

    function release() external;

    function setBeneficiary(address newBeneficiary) external;

    function revoke() external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMoeRegulator {
    error MoeRegulator__NoUpdateNeeded();
    error MoeRegulator__NoRateFound();
    error MoeRegulator__UpdateFailed();

    function SAFE() external view returns (address);

    function MASTERCHEF() external view returns (address);

    function MOE_RATES() external view returns (bytes memory);

    function getScheduledRate(uint256 timestamp) external pure returns (uint32 date, uint64 moePerSecond);

    function canUpdateMoePerSecond() external view returns (bool updateNeeded);

    function updateMoePerSecond() external;
}

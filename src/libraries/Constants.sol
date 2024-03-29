// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Constants Library
 * @dev A library that defines various constants used throughout the codebase.
 */
library Constants {
    uint256 internal constant ACC_PRECISION_BITS = 64;
    uint256 internal constant PRECISION = 1e18;
    uint8 internal constant NEW_ACC_PRECISION_BITS = 128;

    uint256 internal constant MAX_NUMBER_OF_FARMS = 32;
    uint256 internal constant MAX_NUMBER_OF_REWARDS = 32;

    uint256 internal constant MAX_MOE_PER_SECOND = 10e18;
}

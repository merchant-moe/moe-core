// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Math
 * @dev Library for mathematical operations with overflow and underflow checks.
 */
library Math {
    error Math__UnderOverflow();

    uint256 internal constant MAX_INT256 = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    /**
     * @dev Adds a signed integer to an unsigned integer with overflow check.
     * The result must be greater than or equal to 0 and less than or equal to MAX_INT256.
     * @param x Unsigned integer to add to.
     * @param delta Signed integer to add.
     * @return y The result of the addition.
     */
    function addDelta(uint256 x, int256 delta) internal pure returns (uint256 y) {
        uint256 success;

        assembly {
            y := add(x, delta)

            success := iszero(or(gt(x, MAX_INT256), gt(y, MAX_INT256)))
        }

        if (success == 0) revert Math__UnderOverflow();
    }

    /**
     * @dev Safely converts an unsigned integer to a signed integer.
     * @param x Unsigned integer to convert.
     * @return y Signed integer result.
     */
    function toInt256(uint256 x) internal pure returns (int256 y) {
        if (x > MAX_INT256) revert Math__UnderOverflow();

        return int256(x);
    }
}

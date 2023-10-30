// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library SafeMath {
    error SafeMath__Overflow();

    function addDelta(uint256 x, int256 delta) internal pure returns (uint256 y) {
        uint256 success;

        assembly {
            y := add(x, delta)

            success := iszero(or(and(sgt(delta, 0), lt(y, x)), and(slt(delta, 0), gt(y, x))))
        }

        if (success == 0) revert SafeMath__Overflow();
    }
}

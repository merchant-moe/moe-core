// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../../src/library/SafeMath.sol";

contract SafeMathTest is Test {
    function test_fuzz_AddDelta(uint256 x, int256 delta) public returns (uint256 y) {
        int256 edgeLow = x > uint256(type(int256).max) ? type(int256).min : int256(x);
        int256 edgeHigh =
            type(uint256).max - x > uint256(type(int256).max) ? type(int256).max : int256(type(uint256).max - x);

        delta = bound(delta, edgeLow, edgeHigh);

        if (delta >= 0) {
            y = x + uint256(delta);
        } else {
            if (delta == type(int256).min) y = x - uint256(type(int256).max) - 1;
            else y = x - uint256(-delta);
        }

        assertEq(SafeMath.addDelta(x, delta), y, "test_AddDelta::1");
    }

    function test_fuzz_revert_AddDelta(uint256 x, int256 delta) public {
        if (delta < 0) {
            x = bound(x, 0, _abs(delta) - 1);
        } else {
            delta = delta == 0 ? int256(1) : delta;
            x = bound(x, type(uint256).max - _abs(delta) + 1, type(uint256).max);
        }

        vm.expectRevert(SafeMath.SafeMath__Overflow.selector);
        SafeMath.addDelta(x, delta);
    }

    function _abs(int256 x) internal pure returns (uint256) {
        if (x < 0) return x == type(int256).min ? uint256(type(int256).max) + 1 : uint256(-x);
        else return uint256(x);
    }
}

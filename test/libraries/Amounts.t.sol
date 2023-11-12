// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../src/libraries/Amounts.sol";

contract AmountsTest is Test {
    Amounts.Parameter amounts;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function test_Update(address account, int256 deltaAmount) public {
        deltaAmount = bound(deltaAmount, 0, type(int256).max);

        (uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply, uint256 newTotalSupply) =
            Amounts.update(amounts, account, deltaAmount);

        assertEq(Amounts.getAmountOf(amounts, account), newBalance, "test_Update::1");
        assertEq(Amounts.getTotalAmount(amounts), newTotalSupply, "test_Update::2");
        assertEq(oldBalance, 0, "test_Update::3");
        assertEq(oldTotalSupply, 0, "test_Update::4");
    }

    struct Balance {
        uint256 oldBalance;
        uint256 newBalance;
        uint256 oldTotalSupply;
        uint256 newTotalSupply;
    }

    function test_UpdateMultiple(int256 deltaAmount1A, int256 deltaAmount2A, int256 deltaAmount1B, int256 deltaAmount2B)
        public
    {
        deltaAmount1A = bound(deltaAmount1A, 0, type(int256).max - 3);
        deltaAmount1B = bound(deltaAmount1B, 0, type(int256).max - deltaAmount1A - 2);

        deltaAmount2A = bound(deltaAmount2A, -deltaAmount1A, type(int256).max - deltaAmount1A - deltaAmount1B - 1);
        deltaAmount2B =
            bound(deltaAmount2B, -deltaAmount1B, type(int256).max - deltaAmount1A - deltaAmount1B - deltaAmount2A);

        Balance memory balanceA;
        Balance memory balanceB;

        (balanceA.oldBalance, balanceA.newBalance, balanceA.oldTotalSupply, balanceA.newTotalSupply) =
            Amounts.update(amounts, alice, deltaAmount1A);

        (balanceB.oldBalance, balanceB.newBalance, balanceB.oldTotalSupply, balanceB.newTotalSupply) =
            Amounts.update(amounts, bob, deltaAmount1B);

        assertEq(Amounts.getAmountOf(amounts, alice), uint256(deltaAmount1A), "test_UpdateMultiple::1");
        assertEq(Amounts.getAmountOf(amounts, bob), uint256(deltaAmount1B), "test_UpdateMultiple::2");
        assertEq(Amounts.getTotalAmount(amounts), uint256(deltaAmount1A + deltaAmount1B), "test_UpdateMultiple::3");

        assertEq(balanceA.oldBalance, 0, "test_UpdateMultiple::4");
        assertEq(balanceB.oldBalance, 0, "test_UpdateMultiple::5");
        assertEq(balanceA.oldTotalSupply, 0, "test_UpdateMultiple::6");
        assertEq(balanceB.oldTotalSupply, uint256(deltaAmount1A), "test_UpdateMultiple::7");
        assertEq(balanceA.newBalance, uint256(deltaAmount1A), "test_UpdateMultiple::8");
        assertEq(balanceB.newBalance, uint256(deltaAmount1B), "test_UpdateMultiple::9");
        assertEq(balanceA.newTotalSupply, uint256(deltaAmount1A), "test_UpdateMultiple::10");
        assertEq(balanceB.newTotalSupply, uint256(deltaAmount1A + deltaAmount1B), "test_UpdateMultiple::11");

        (balanceA.oldBalance, balanceA.newBalance, balanceA.oldTotalSupply, balanceA.newTotalSupply) =
            Amounts.update(amounts, alice, deltaAmount2A);

        assertEq(Amounts.getAmountOf(amounts, alice), uint256(deltaAmount1A + deltaAmount2A), "test_UpdateMultiple::12");
        assertEq(Amounts.getAmountOf(amounts, bob), uint256(deltaAmount1B), "test_UpdateMultiple::13");
        assertEq(
            Amounts.getTotalAmount(amounts),
            uint256(deltaAmount1A + deltaAmount1B + deltaAmount2A),
            "test_UpdateMultiple::14"
        );
        assertEq(
            Amounts.getTotalAmount(amounts),
            Amounts.getAmountOf(amounts, alice) + Amounts.getAmountOf(amounts, bob),
            "test_UpdateMultiple::15"
        );

        assertEq(balanceA.oldBalance, uint256(deltaAmount1A), "test_UpdateMultiple::16");
        assertEq(balanceA.oldTotalSupply, uint256(deltaAmount1A + deltaAmount1B), "test_UpdateMultiple::17");
        assertEq(balanceA.newBalance, uint256(deltaAmount1A + deltaAmount2A), "test_UpdateMultiple::18");
        assertEq(
            balanceA.newTotalSupply, uint256(deltaAmount1A + deltaAmount1B + deltaAmount2A), "test_UpdateMultiple::19"
        );

        (balanceB.oldBalance, balanceB.newBalance, balanceB.oldTotalSupply, balanceB.newTotalSupply) =
            Amounts.update(amounts, bob, deltaAmount2B);

        assertEq(Amounts.getAmountOf(amounts, alice), uint256(deltaAmount1A + deltaAmount2A), "test_UpdateMultiple::20");
        assertEq(Amounts.getAmountOf(amounts, bob), uint256(deltaAmount1B + deltaAmount2B), "test_UpdateMultiple::21");
        assertEq(
            Amounts.getTotalAmount(amounts),
            uint256(deltaAmount1A + deltaAmount1B + deltaAmount2A + deltaAmount2B),
            "test_UpdateMultiple::22"
        );

        assertEq(balanceB.oldBalance, uint256(deltaAmount1B), "test_UpdateMultiple::23");
        assertEq(
            balanceB.oldTotalSupply, uint256(deltaAmount1A + deltaAmount1B + deltaAmount2A), "test_UpdateMultiple::24"
        );
        assertEq(balanceB.newBalance, uint256(deltaAmount1B + deltaAmount2B), "test_UpdateMultiple::25");
        assertEq(
            balanceB.newTotalSupply,
            uint256(deltaAmount1A + deltaAmount1B + deltaAmount2A + deltaAmount2B),
            "test_UpdateMultiple::26"
        );
    }
}

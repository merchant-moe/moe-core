// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../../src/library/Bank.sol";

contract BankTest is Test {
    Bank.Parameter bank;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function test_Update(address account, int256 deltaAmount) public {
        deltaAmount = bound(deltaAmount, 0, type(int256).max);

        (uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply, uint256 newTotalSupply) =
            Bank.update(bank, account, deltaAmount);

        assertEq(bank.balances[account], newBalance, "test_Update::1");
        assertEq(bank.totalSupply, newTotalSupply, "test_Update::2");
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
            Bank.update(bank, alice, deltaAmount1A);

        (balanceB.oldBalance, balanceB.newBalance, balanceB.oldTotalSupply, balanceB.newTotalSupply) =
            Bank.update(bank, bob, deltaAmount1B);

        assertEq(bank.balances[alice], uint256(deltaAmount1A), "test_UpdateMultiple::1");
        assertEq(bank.balances[bob], uint256(deltaAmount1B), "test_UpdateMultiple::2");
        assertEq(bank.totalSupply, uint256(deltaAmount1A + deltaAmount1B), "test_UpdateMultiple::3");

        assertEq(balanceA.oldBalance, 0, "test_UpdateMultiple::4");
        assertEq(balanceB.oldBalance, 0, "test_UpdateMultiple::5");
        assertEq(balanceA.oldTotalSupply, 0, "test_UpdateMultiple::6");
        assertEq(balanceB.oldTotalSupply, uint256(deltaAmount1A), "test_UpdateMultiple::7");
        assertEq(balanceA.newBalance, uint256(deltaAmount1A), "test_UpdateMultiple::8");
        assertEq(balanceB.newBalance, uint256(deltaAmount1B), "test_UpdateMultiple::9");
        assertEq(balanceA.newTotalSupply, uint256(deltaAmount1A), "test_UpdateMultiple::10");
        assertEq(balanceB.newTotalSupply, uint256(deltaAmount1A + deltaAmount1B), "test_UpdateMultiple::11");

        (balanceA.oldBalance, balanceA.newBalance, balanceA.oldTotalSupply, balanceA.newTotalSupply) =
            Bank.update(bank, alice, deltaAmount2A);

        assertEq(bank.balances[alice], uint256(deltaAmount1A + deltaAmount2A), "test_UpdateMultiple::12");
        assertEq(bank.balances[bob], uint256(deltaAmount1B), "test_UpdateMultiple::13");
        assertEq(bank.totalSupply, uint256(deltaAmount1A + deltaAmount1B + deltaAmount2A), "test_UpdateMultiple::14");
        assertEq(bank.totalSupply, bank.balances[alice] + bank.balances[bob], "test_UpdateMultiple::15");

        assertEq(balanceA.oldBalance, uint256(deltaAmount1A), "test_UpdateMultiple::16");
        assertEq(balanceA.oldTotalSupply, uint256(deltaAmount1A + deltaAmount1B), "test_UpdateMultiple::17");
        assertEq(balanceA.newBalance, uint256(deltaAmount1A + deltaAmount2A), "test_UpdateMultiple::18");
        assertEq(
            balanceA.newTotalSupply, uint256(deltaAmount1A + deltaAmount1B + deltaAmount2A), "test_UpdateMultiple::19"
        );

        (balanceB.oldBalance, balanceB.newBalance, balanceB.oldTotalSupply, balanceB.newTotalSupply) =
            Bank.update(bank, bob, deltaAmount2B);

        assertEq(bank.balances[alice], uint256(deltaAmount1A + deltaAmount2A), "test_UpdateMultiple::20");
        assertEq(bank.balances[bob], uint256(deltaAmount1B + deltaAmount2B), "test_UpdateMultiple::21");
        assertEq(
            bank.totalSupply,
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

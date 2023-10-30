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

    function test_Gas() public {
        address account = alice;
        int256 deltaAmount = 1e18;

        Bank.update(bank, account, deltaAmount);

        deltaAmount = -0.5e18;

        Bank.update(bank, account, deltaAmount);

        Bank.update(bank, account, 0);
    }

    function test_UpdateMultiple(int256 deltaAmount1A, int256 deltaAmount2A, int256 deltaAmount1B, int256 deltaAmount2B)
        public
    {
        deltaAmount1A = bound(deltaAmount1A, 0, type(int256).max);
        deltaAmount1B = bound(deltaAmount1B, 0, type(int256).max);

        deltaAmount2A = bound(deltaAmount2A, -deltaAmount1A, type(int256).max - deltaAmount1A);
        deltaAmount2B = bound(deltaAmount2B, -deltaAmount1B, type(int256).max - deltaAmount1B);

        (uint256 oldBalanceA, uint256 newBalanceA, uint256 oldTotalSupplyA, uint256 newTotalSupplyA) =
            Bank.update(bank, alice, deltaAmount1A);

        (uint256 oldBalanceB, uint256 newBalanceB, uint256 oldTotalSupplyB, uint256 newTotalSupplyB) =
            Bank.update(bank, bob, deltaAmount1B);

        assertEq(bank.balances[alice], newBalanceA, "test_UpdateMultiple::1");
        assertEq(bank.balances[bob], newBalanceB, "test_UpdateMultiple::2");
        assertEq(bank.totalSupply, newTotalSupplyB, "test_UpdateMultiple::3");
        assertEq(bank.totalSupply, newBalanceA + newBalanceB, "test_UpdateMultiple::4");
        assertEq(oldBalanceA, 0, "test_UpdateMultiple::5");
        assertEq(oldBalanceB, 0, "test_UpdateMultiple::6");
        assertEq(oldTotalSupplyA, 0, "test_UpdateMultiple::7");
        assertEq(oldTotalSupplyB, newTotalSupplyA, "test_UpdateMultiple::8");

        (oldBalanceA, newBalanceA, oldTotalSupplyA, newTotalSupplyA) = Bank.update(bank, alice, deltaAmount2A);

        assertEq(bank.balances[alice], newBalanceA, "test_UpdateMultiple::9");
        assertEq(bank.balances[bob], newBalanceB, "test_UpdateMultiple::10");
        assertEq(bank.totalSupply, newTotalSupplyA, "test_UpdateMultiple::11");
        assertEq(bank.totalSupply, newBalanceA + newBalanceB, "test_UpdateMultiple::12");

        (oldBalanceB, newBalanceB, oldTotalSupplyB, newTotalSupplyB) = Bank.update(bank, bob, deltaAmount2B);

        assertEq(bank.balances[alice], newBalanceA, "test_UpdateMultiple::13");
        assertEq(bank.balances[bob], newBalanceB, "test_UpdateMultiple::14");
        assertEq(bank.totalSupply, newTotalSupplyB, "test_UpdateMultiple::15");
        assertEq(bank.totalSupply, newBalanceA + newBalanceB, "test_UpdateMultiple::16");
    }
}

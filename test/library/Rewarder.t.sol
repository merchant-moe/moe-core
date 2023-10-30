// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../../src/library/Rewarder.sol";

contract RewarderTest is Test {
    Bank.Parameter bank;
    Rewarder.Parameter rewarder;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        Bank.update(bank, alice, 1e18);
        Bank.update(bank, bob, 2e18);
    }

    function test_getTotalRewards(uint256 rewardPerSecond, uint256 deltaTime) public {
        rewardPerSecond = bound(rewardPerSecond, 0, 1e36);
        deltaTime = bound(deltaTime, 0, 1e20);

        rewarder.lastUpdateTimestamp = block.timestamp - 1;
        uint256 totalRewards = Rewarder.getTotalRewards(rewarder, rewardPerSecond);

        assertEq(totalRewards, rewardPerSecond, "test_getTotalRewards::1");

        rewarder.lastUpdateTimestamp = block.timestamp;
        totalRewards = Rewarder.getTotalRewards(rewarder, rewardPerSecond);

        assertEq(totalRewards, 0, "test_getTotalRewards::2");

        rewarder.lastUpdateTimestamp = block.timestamp + 1;
        totalRewards = Rewarder.getTotalRewards(rewarder, rewardPerSecond);

        assertEq(totalRewards, 0, "test_getTotalRewards::3");

        vm.warp(rewarder.lastUpdateTimestamp + deltaTime);

        totalRewards = Rewarder.getTotalRewards(rewarder, rewardPerSecond);

        assertEq(totalRewards, deltaTime * rewardPerSecond, "test_getTotalRewards::4");
    }

    function test_UpdateAccDebtPerShare() public {
        uint256 totalSupply = 1e18;
        uint256 totalRewards = 10e18;

        uint256 addDebtPerShare = Rewarder.updateAccDebtPerShare(rewarder, totalSupply, totalRewards);

        assertEq(
            rewarder.accDebtPerShare,
            (totalRewards << Constants.ACC_PRECISION_BITS) / totalSupply,
            "test_UpdateAccDebtPerShare::1"
        );
        assertEq(
            Rewarder.getDebtPerShare(totalSupply, totalRewards),
            rewarder.accDebtPerShare,
            "test_UpdateAccDebtPerShare::2"
        );
        assertEq(rewarder.lastUpdateTimestamp, block.timestamp, "test_UpdateAccDebtPerShare::3");

        totalSupply = 5e18;
        totalRewards = 5e18;

        vm.warp(block.timestamp + 1);

        Rewarder.updateAccDebtPerShare(rewarder, totalSupply, totalRewards);

        assertEq(
            rewarder.accDebtPerShare,
            addDebtPerShare + (totalRewards << Constants.ACC_PRECISION_BITS) / totalSupply,
            "test_UpdateAccDebtPerShare::4"
        );
        assertEq(
            Rewarder.getDebtPerShare(totalSupply, totalRewards),
            rewarder.accDebtPerShare - addDebtPerShare,
            "test_UpdateAccDebtPerShare::5"
        );
        assertEq(rewarder.lastUpdateTimestamp, block.timestamp, "test_UpdateAccDebtPerShare::6");
    }

    function test_Update() public {
        uint256 totalRewards = 10e18;

        uint256 expectedRewardsAlice = Rewarder.getPendingReward(rewarder, bank, alice, totalRewards);

        uint256 aliceRewards;
        {
            (uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply,) = Bank.update(bank, alice, 1e18);

            aliceRewards = Rewarder.update(rewarder, alice, oldBalance, newBalance, oldTotalSupply, totalRewards);
            uint256 aliceDebt = rewarder.debt[alice];

            assertEq(aliceRewards, 10e18 * oldBalance / oldTotalSupply, "test_Update::1");
            assertEq(aliceRewards, expectedRewardsAlice, "test_Update::2");
            assertEq(aliceDebt, 2 * aliceRewards, "test_Update::3");

            expectedRewardsAlice = Rewarder.getPendingReward(rewarder, bank, alice, 0);

            uint256 aliceRewards2 =
                Rewarder.update(rewarder, alice, bank.balances[alice], bank.balances[alice], bank.totalSupply, 0);

            assertEq(aliceRewards2, 0, "test_Update::4");
            assertEq(aliceRewards2, expectedRewardsAlice, "test_Update::5");
            assertEq(rewarder.debt[alice], aliceDebt, "test_Update::6");
        }

        uint256 expectedRewardsBob = Rewarder.getPendingReward(rewarder, bank, bob, 0);

        uint256 bobRewards = Rewarder.update(rewarder, bob, bank.balances[bob], bank.balances[bob], bank.totalSupply, 0);

        assertEq(bobRewards, 2 * aliceRewards, "test_Update::7");
        assertEq(bobRewards, expectedRewardsBob, "test_Update::8");
        assertEq(rewarder.debt[bob], bobRewards, "test_Update::9");

        totalRewards = 5e18;

        expectedRewardsAlice = Rewarder.getPendingReward(rewarder, bank, alice, totalRewards);
        expectedRewardsBob = Rewarder.getPendingReward(rewarder, bank, bob, totalRewards);

        bobRewards =
            Rewarder.update(rewarder, bob, bank.balances[bob], bank.balances[bob], bank.totalSupply, totalRewards);
        aliceRewards = Rewarder.update(rewarder, alice, bank.balances[alice], bank.balances[alice], bank.totalSupply, 0);

        assertEq(bank.balances[alice], bank.balances[bob], "test_Update::10");
        assertEq(aliceRewards, 5e18 * bank.balances[alice] / bank.totalSupply, "test_Update::11");
        assertEq(aliceRewards, expectedRewardsAlice, "test_Update::12");
        assertEq(bobRewards, expectedRewardsBob, "test_Update::13");
        assertEq(bobRewards, aliceRewards, "test_Update::14");
        assertEq(rewarder.debt[alice], rewarder.debt[bob], "test_Update::15");
    }

    function test_UpdateAfterEmergencyWithdrawal() public {
        uint256 totalRewards = 10e18;

        uint256 rewards =
            Rewarder.update(rewarder, alice, bank.balances[alice], bank.balances[alice], bank.totalSupply, totalRewards);

        assertGt(rewards, 0, "test_UpdateAfterEmergencyWithdrawal::1");

        // emergency withdrawal
        Bank.update(bank, bob, -int256(bank.balances[bob]));

        uint256 expectedRewards = Rewarder.getPendingReward(rewarder, bank, bob, totalRewards);

        (uint256 oldBalance, uint256 newBalance, uint256 oldTotalSupply,) = Bank.update(bank, bob, 1e18);
        uint256 bobRewards = Rewarder.update(rewarder, bob, oldBalance, newBalance, oldTotalSupply, totalRewards);

        assertEq(bobRewards, expectedRewards, "test_UpdateAfterEmergencyWithdrawal::2");
        assertEq(bobRewards, 0, "test_UpdateAfterEmergencyWithdrawal::3");
    }
}

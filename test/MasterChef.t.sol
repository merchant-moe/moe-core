// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/MasterChef.sol";
import "../src/Moe.sol";
import "./mocks/MockVeMoe.sol";
import "./mocks/MockERC20.sol";
import "../src/SimpleRewarder.sol";

contract MasterChefTest is Test {
    MasterChef masterChef;
    IMoe moe;
    MockVeMoe veMoe;

    IERC20 tokenA;
    IERC20 tokenB;

    IERC20 rewardToken;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        veMoe = new MockVeMoe();

        tokenA = IERC20(new MockERC20("Token A", "TA", 18));
        tokenB = IERC20(new MockERC20("Token B", "TB", 18));

        rewardToken = IERC20(new MockERC20("Reward Token", "RT", 6));

        uint256 nonce = vm.getNonce(address(this));

        address masterChefAddress = computeCreateAddress(address(this), nonce + 1);

        moe = IMoe(address(new Moe(masterChefAddress)));

        masterChef = new MasterChef(moe, IVeMoe(address(veMoe)), address(this));

        vm.label(address(moe), "moe");
        vm.label(address(veMoe), "veMoe");
        vm.label(address(tokenA), "tokenA");
        vm.label(address(tokenB), "tokenB");
        vm.label(address(rewardToken), "rewardToken");
        vm.label(address(masterChef), "masterChef");

        masterChef.add(tokenA, block.timestamp, IRewarder(address(0)));
        masterChef.add(tokenB, block.timestamp, IRewarder(address(0)));

        deal(address(tokenA), address(alice), 1e18);
        deal(address(tokenB), address(alice), 2e18);

        deal(address(tokenA), address(bob), 9e18);
        deal(address(tokenB), address(bob), 8e18);

        vm.startPrank(alice);
        tokenA.approve(address(masterChef), type(uint256).max);
        tokenB.approve(address(masterChef), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        tokenA.approve(address(masterChef), type(uint256).max);
        tokenB.approve(address(masterChef), type(uint256).max);
        vm.stopPrank();
    }

    function test_SetUp() public {
        assertEq(address(masterChef.getMoe()), address(moe), "test_SetUp::1");
        assertEq(address(masterChef.getVeMoe()), address(veMoe), "test_SetUp::2");
        assertEq(address(moe.getMinter()), address(masterChef), "test_SetUp::3");
        assertEq(address(masterChef.getToken(0)), address(tokenA), "test_SetUp::4");
        assertEq(address(masterChef.getToken(1)), address(tokenB), "test_SetUp::5");
    }

    function test_Deposit() public {
        vm.prank(alice);
        masterChef.deposit(0, 1e18);

        assertEq(masterChef.getDeposit(0, alice), 1e18, "test_Deposit::1");
        assertEq(masterChef.getTotalDeposit(0), 1e18, "test_Deposit::2");
        assertEq(tokenA.balanceOf(address(alice)), 0, "test_Deposit::3");
        assertEq(tokenA.balanceOf(address(masterChef)), 1e18, "test_Deposit::4");

        vm.prank(bob);
        masterChef.deposit(0, 9e18);

        assertEq(masterChef.getDeposit(0, bob), 9e18, "test_Deposit::5");
        assertEq(masterChef.getTotalDeposit(0), 10e18, "test_Deposit::6");
        assertEq(tokenA.balanceOf(address(bob)), 0, "test_Deposit::7");
        assertEq(tokenA.balanceOf(address(masterChef)), 10e18, "test_Deposit::8");
    }

    function test_Withdraw() public {
        vm.prank(alice);
        masterChef.deposit(0, 1e18);

        vm.prank(bob);
        masterChef.deposit(0, 9e18);

        vm.prank(alice);
        masterChef.withdraw(0, 0.5e18);

        assertEq(masterChef.getDeposit(0, alice), 0.5e18, "test_Withdraw::1");
        assertEq(masterChef.getTotalDeposit(0), 9.5e18, "test_Withdraw::2");
        assertEq(tokenA.balanceOf(alice), 0.5e18, "test_Withdraw::3");
        assertEq(tokenA.balanceOf(address(masterChef)), 9.5e18, "test_Withdraw::4");

        vm.prank(bob);
        masterChef.withdraw(0, 8e18);

        assertEq(masterChef.getDeposit(0, bob), 1e18, "test_Withdraw::5");
        assertEq(masterChef.getTotalDeposit(0), 1.5e18, "test_Withdraw::6");
        assertEq(tokenA.balanceOf(bob), 8e18, "test_Withdraw::7");
        assertEq(tokenA.balanceOf(address(masterChef)), 1.5e18, "test_Withdraw::8");

        vm.prank(alice);
        masterChef.withdraw(0, 0.5e18);

        assertEq(masterChef.getDeposit(0, alice), 0, "test_Withdraw::9");
        assertEq(masterChef.getTotalDeposit(0), 1e18, "test_Withdraw::10");
        assertEq(tokenA.balanceOf(alice), 1e18, "test_Withdraw::11");
        assertEq(tokenA.balanceOf(address(masterChef)), 1e18, "test_Withdraw::12");

        vm.prank(bob);
        masterChef.withdraw(0, 1e18);

        assertEq(masterChef.getDeposit(0, bob), 0, "test_Withdraw::13");
        assertEq(masterChef.getTotalDeposit(0), 0, "test_Withdraw::14");
        assertEq(tokenA.balanceOf(bob), 9e18, "test_Withdraw::15");
        assertEq(tokenA.balanceOf(address(masterChef)), 0, "test_Withdraw::16");

        vm.prank(alice);
        masterChef.deposit(0, 1e18);

        assertEq(masterChef.getDeposit(0, alice), 1e18, "test_Withdraw::17");
        assertEq(masterChef.getTotalDeposit(0), 1e18, "test_Withdraw::18");
        assertEq(masterChef.getDeposit(0, alice), 1e18, "test_Withdraw::19");
        assertEq(masterChef.getTotalDeposit(0), 1e18, "test_Withdraw::20");

        vm.prank(bob);
        masterChef.deposit(0, 9e18);

        assertEq(masterChef.getDeposit(0, bob), 9e18, "test_Withdraw::21");
        assertEq(masterChef.getTotalDeposit(0), 10e18, "test_Withdraw::22");
        assertEq(tokenA.balanceOf(address(bob)), 0, "test_Withdraw::23");
        assertEq(tokenA.balanceOf(address(masterChef)), 10e18, "test_Withdraw::24");
    }

    function test_SetMoePerSecond(uint256 moePerSecond) public {
        masterChef.setMoePerSecond(moePerSecond);

        assertEq(masterChef.getMoePerSecond(), moePerSecond, "test_SetMoePerSecond::1");

        assertEq(masterChef.getLastUpdateTimestamp(0), block.timestamp, "test_SetMoePerSecond::2");
        assertEq(masterChef.getLastUpdateTimestamp(1), block.timestamp, "test_SetMoePerSecond::3");

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        masterChef.setMoePerSecond(moePerSecond);
    }

    function test_Claim() public {
        masterChef.setMoePerSecond(1e18);

        veMoe.setVotes(0, 1e18);
        veMoe.setVotes(1, 1e18);

        vm.startPrank(alice);
        masterChef.deposit(0, 1e18);
        masterChef.deposit(1, 2e18);
        vm.stopPrank();

        vm.startPrank(bob);
        masterChef.deposit(0, 9e18);
        masterChef.deposit(1, 8e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 10);

        uint256[] memory pids = new uint256[](1);

        vm.prank(alice);
        masterChef.deposit(0, 0);

        assertEq(moe.balanceOf(address(alice)), 0.5e18, "test_Claim::1");

        vm.prank(bob);
        masterChef.deposit(0, 0);

        assertEq(moe.balanceOf(address(bob)), 4.5e18, "test_Claim::2");

        vm.warp(block.timestamp + 10);

        pids = new uint256[](2);
        pids[1] = 1;

        vm.prank(alice);
        masterChef.claim(pids);

        assertEq(moe.balanceOf(address(alice)), 3e18, "test_Claim::3");

        vm.prank(bob);
        masterChef.claim(pids);

        assertEq(moe.balanceOf(address(bob)), 17e18, "test_Claim::4");

        vm.prank(alice);
        masterChef.claim(pids);

        assertEq(moe.balanceOf(address(alice)), 3e18, "test_Claim::5");

        vm.prank(bob);
        masterChef.claim(pids);

        assertEq(moe.balanceOf(address(bob)), 17e18, "test_Claim::6");
    }

    function test_Add() public {
        masterChef.add(tokenA, block.timestamp, IRewarder(address(0)));

        SimpleRewarder rewarder = new SimpleRewarder(rewardToken, masterChef, address(this));

        masterChef.add(tokenA, block.timestamp, IRewarder(address(rewarder)));

        assertEq(address(masterChef.getExtraRewarder(3)), address(rewarder), "test_Add::1");

        SimpleRewarder rewarder1 = new SimpleRewarder(rewardToken, masterChef, address(this));
        SimpleRewarder rewarder2 = new SimpleRewarder(rewardToken, masterChef, address(this));

        masterChef.setExtraRewarder(2, IRewarder(address(rewarder1)));

        assertEq(address(masterChef.getExtraRewarder(2)), address(rewarder1), "test_Add::1");

        vm.expectRevert(IRewarder.SimpleRewarder__AlreadyLinked.selector);
        masterChef.setExtraRewarder(2, IRewarder(address(rewarder1)));

        masterChef.setExtraRewarder(2, IRewarder(address(rewarder2)));

        assertEq(address(masterChef.getExtraRewarder(2)), address(rewarder2), "test_Add::2");

        vm.expectRevert(IRewarder.SimpleRewarder__AlreadyLinked.selector);
        masterChef.setExtraRewarder(2, IRewarder(address(rewarder2)));

        masterChef.setExtraRewarder(2, IRewarder(address(0)));

        assertEq(address(masterChef.getExtraRewarder(2)), address(0), "test_Add::3");

        vm.expectRevert(IMasterChef.MasterChef__InvalidStartTimestamp.selector);
        masterChef.add(tokenA, block.timestamp - 1, IRewarder(address(0)));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        masterChef.add(tokenA, block.timestamp, IRewarder(address(0)));
    }

    function test_EmergencyWithdrawal() public {
        masterChef.setMoePerSecond(1e18);

        veMoe.setVotes(0, 1e18);

        vm.prank(alice);
        masterChef.deposit(0, 1e18);

        vm.prank(bob);
        masterChef.deposit(0, 9e18);

        vm.warp(block.timestamp + 10);

        vm.prank(alice);
        masterChef.emergencyWithdraw(0);

        assertEq(moe.balanceOf(address(alice)), 0, "test_EmergencyWithdrawal::1");
        assertEq(tokenA.balanceOf(address(alice)), 1e18, "test_EmergencyWithdrawal::2");

        vm.prank(bob);
        masterChef.claim(new uint256[](1));

        assertApproxEqAbs(moe.balanceOf(address(bob)), 10e18, 1, "test_EmergencyWithdrawal::3");

        vm.prank(alice);
        masterChef.deposit(0, 1e18);

        assertEq(moe.balanceOf(address(alice)), 0, "test_EmergencyWithdrawal::5");

        vm.warp(block.timestamp + 10);

        vm.prank(alice);
        masterChef.claim(new uint256[](1));

        assertApproxEqAbs(moe.balanceOf(address(alice)), 1e18, 1, "test_EmergencyWithdrawal::6");

        vm.prank(bob);
        masterChef.emergencyWithdraw(0);

        vm.prank(alice);
        masterChef.claim(new uint256[](1));

        assertApproxEqAbs(moe.balanceOf(address(alice)), 1e18, 1, "test_EmergencyWithdrawal::6");
    }
}

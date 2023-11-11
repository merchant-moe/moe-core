// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../src/MasterChef.sol";
import "../src/Moe.sol";
import "./mocks/MockVeMoe.sol";
import "./mocks/MockERC20.sol";
import "../src/MasterChefRewarder.sol";

contract MasterChefTest is Test {
    MasterChef masterChef;
    IMoe moe;
    MockVeMoe veMoe;

    IERC20 tokenA;
    IERC20 tokenB;

    IERC20 rewardToken0;
    IERC20 rewardToken1;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        veMoe = new MockVeMoe();

        tokenA = IERC20(new MockERC20("Token A", "TA", 18));
        tokenB = IERC20(new MockERC20("Token B", "TB", 18));

        rewardToken0 = IERC20(new MockERC20("Reward Token", "RT", 18));
        rewardToken1 = IERC20(new MockERC20("Reward Token", "RT", 6));

        uint256 nonce = vm.getNonce(address(this));

        address masterChefAddress = computeCreateAddress(address(this), nonce + 2);

        moe = IMoe(address(new Moe(masterChefAddress, 0, type(uint256).max)));

        masterChef = new MasterChef(moe, IVeMoe(address(veMoe)), 0);

        TransparentUpgradeableProxy proxy =
        new TransparentUpgradeableProxy(address(masterChef), address(this), abi.encodeWithSelector(MasterChef.initialize.selector, address(this), address(this)));

        masterChef = MasterChef(address(proxy));

        vm.label(address(moe), "moe");
        vm.label(address(veMoe), "veMoe");
        vm.label(address(tokenA), "tokenA");
        vm.label(address(tokenB), "tokenB");
        vm.label(address(rewardToken0), "rewardToken0");
        vm.label(address(masterChef), "masterChef");

        masterChef.add(tokenA, IMasterChefRewarder(address(0)));
        masterChef.add(tokenB, IMasterChefRewarder(address(0)));

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
        assertEq(moe.getMaxSupply(), type(uint256).max, "test_SetUp::4");
        assertEq(address(masterChef.getToken(0)), address(tokenA), "test_SetUp::5");
        assertEq(address(masterChef.getToken(1)), address(tokenB), "test_SetUp::6");
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

    function test_SetMoePerSecond(uint96 moePerSecond) public {
        masterChef.setMoePerSecond(moePerSecond);

        assertEq(masterChef.getMoePerSecond(), moePerSecond, "test_SetMoePerSecond::1");

        assertEq(masterChef.getLastUpdateTimestamp(0), block.timestamp, "test_SetMoePerSecond::2");
        assertEq(masterChef.getLastUpdateTimestamp(1), block.timestamp, "test_SetMoePerSecond::3");

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        masterChef.setMoePerSecond(moePerSecond);
    }

    function test_Claim() public {
        masterChef.setMoePerSecond(1e18);

        {
            veMoe.setVotes(0, 1e18);
            veMoe.setVotes(1, 1e18);

            uint256[] memory topPids = new uint256[](2);

            topPids[0] = 0;
            topPids[1] = 1;

            veMoe.setTopPoolIds(topPids);
        }

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
        masterChef.add(tokenA, IMasterChefRewarder(address(0)));

        MasterChefRewarder rewarder = new MasterChefRewarder(rewardToken0, address(masterChef), 3, address(this));

        masterChef.add(tokenA, IMasterChefRewarder(address(rewarder)));

        assertEq(address(masterChef.getExtraRewarder(3)), address(rewarder), "test_Add::1");

        MasterChefRewarder rewarder1 = new MasterChefRewarder(rewardToken0, address(masterChef), 2, address(this));
        MasterChefRewarder rewarder2 = new MasterChefRewarder(rewardToken0, address(masterChef), 2, address(this));

        masterChef.setExtraRewarder(2, IMasterChefRewarder(address(rewarder1)));

        assertEq(address(masterChef.getExtraRewarder(2)), address(rewarder1), "test_Add::2");

        vm.expectRevert(IMasterChefRewarder.MasterChefRewarder__AlreadyLinked.selector);
        masterChef.setExtraRewarder(2, IMasterChefRewarder(address(rewarder1)));

        masterChef.setExtraRewarder(2, IMasterChefRewarder(address(rewarder2)));

        assertEq(address(masterChef.getExtraRewarder(2)), address(rewarder2), "test_Add::3");

        vm.expectRevert(IMasterChefRewarder.MasterChefRewarder__AlreadyLinked.selector);
        masterChef.setExtraRewarder(2, IMasterChefRewarder(address(rewarder2)));

        masterChef.setExtraRewarder(2, IMasterChefRewarder(address(0)));

        assertEq(address(masterChef.getExtraRewarder(2)), address(0), "test_Add::4");

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        masterChef.add(tokenA, IMasterChefRewarder(address(0)));
    }

    function test_EmergencyWithdrawal() public {
        masterChef.setMoePerSecond(1e18);

        veMoe.setVotes(0, 1e18);
        veMoe.setTopPoolIds(new uint256[](1));

        assertEq(masterChef.getMoePerSecondForPid(0), 1e18, "test_EmergencyWithdrawal::1");
        assertEq(masterChef.getMoePerSecondForPid(1), 0, "test_EmergencyWithdrawal::2");

        vm.prank(alice);
        masterChef.deposit(0, 1e18);

        vm.prank(bob);
        masterChef.deposit(0, 9e18);

        vm.warp(block.timestamp + 10);

        vm.prank(alice);
        masterChef.emergencyWithdraw(0);

        assertEq(moe.balanceOf(address(alice)), 0, "test_EmergencyWithdrawal::3");
        assertEq(tokenA.balanceOf(address(alice)), 1e18, "test_EmergencyWithdrawal::4");

        vm.prank(bob);
        masterChef.claim(new uint256[](1));

        assertApproxEqAbs(moe.balanceOf(address(bob)), 10e18, 1, "test_EmergencyWithdrawal::5");

        vm.prank(alice);
        masterChef.deposit(0, 1e18);

        assertEq(moe.balanceOf(address(alice)), 0, "test_EmergencyWithdrawal::6");

        vm.warp(block.timestamp + 10);

        vm.prank(alice);
        masterChef.claim(new uint256[](1));

        assertApproxEqAbs(moe.balanceOf(address(alice)), 1e18, 1, "test_EmergencyWithdrawal::7");

        vm.prank(bob);
        masterChef.emergencyWithdraw(0);

        vm.prank(alice);
        masterChef.claim(new uint256[](1));

        assertApproxEqAbs(moe.balanceOf(address(alice)), 1e18, 1, "test_EmergencyWithdrawal::8");
    }

    function test_TreasuryShare() public {
        veMoe.setVotes(0, 1e18);
        veMoe.setTopPoolIds(new uint256[](1));

        uint256 nonce = vm.getNonce(address(this));
        address masterChefAddress = computeCreateAddress(address(this), nonce + 2);

        moe = IMoe(address(new Moe(masterChefAddress, 0, type(uint256).max)));
        masterChef = new MasterChef(moe, IVeMoe(address(veMoe)), 0.1e18);

        TransparentUpgradeableProxy proxy =
        new TransparentUpgradeableProxy(address(masterChef), address(this), abi.encodeWithSelector(MasterChef.initialize.selector, address(this), address(this)));

        masterChef = MasterChef(address(proxy));

        assertEq(masterChef.getTreasuryShare(), 0.1e18, "test_TreasuryShare::1");
        assertEq(masterChef.getTreasury(), address(this), "test_TreasuryShare::2");

        masterChef.add(tokenA, IMasterChefRewarder(address(0)));
        masterChef.setMoePerSecond(1e18);

        vm.startPrank(alice);
        tokenA.approve(address(masterChef), type(uint256).max);
        masterChef.deposit(0, 1e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 10);

        vm.prank(alice);
        masterChef.claim(new uint256[](1));

        assertEq(moe.balanceOf(address(this)), 1e18, "test_TreasuryShare::3");
        assertEq(moe.balanceOf(address(alice)), 9e18, "test_TreasuryShare::4");

        vm.expectRevert(IMasterChef.MasterChef__InvalidTreasury.selector);
        masterChef.setTreasury(address(0));

        masterChef.setTreasury(address(1));

        assertEq(masterChef.getTreasuryShare(), 0.1e18, "test_TreasuryShare::5");
        assertEq(masterChef.getTreasury(), address(1), "test_TreasuryShare::6");

        vm.expectRevert(IMasterChef.MasterChef__InvalidTreasuryShare.selector);
        new MasterChef(moe, IVeMoe(address(veMoe)), 1e18 + 1);
    }

    function test_ExtraRewarder() public {
        MasterChefRewarder rewarder0 = new MasterChefRewarder(rewardToken0, address(masterChef), 0, address(this));
        MasterChefRewarder rewarder1 = new MasterChefRewarder(rewardToken1, address(masterChef), 1, address(this));

        vm.expectRevert(abi.encodeWithSelector(IBaseRewarder.BaseRewarder__InvalidPid.selector, 2));
        masterChef.add(tokenA, rewarder0);

        MockERC20(address(rewardToken0)).mint(address(rewarder0), 100e18);
        rewarder0.setRewardPerSecond(1e18, 100);

        MockERC20(address(rewardToken1)).mint(address(rewarder1), 400e6);
        rewarder1.setRewardPerSecond(4e6, 100);

        masterChef.setExtraRewarder(0, IMasterChefRewarder(address(rewarder0)));
        masterChef.setExtraRewarder(1, IMasterChefRewarder(address(rewarder1)));

        masterChef.setMoePerSecond(10e18);

        veMoe.setVotes(0, 1e18);
        veMoe.setTopPoolIds(new uint256[](1));

        vm.startPrank(alice);
        masterChef.deposit(0, 1e18);
        masterChef.deposit(1, 2e18);
        vm.stopPrank();

        vm.startPrank(bob);
        masterChef.deposit(0, 9e18);
        masterChef.deposit(1, 8e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 50);

        uint256[] memory pids = new uint256[](2);

        pids[0] = 0;
        pids[1] = 1;

        (uint256[] memory moeRewardAlice, IERC20[] memory extraTokenAlice, uint256[] memory extraRewardAlice) =
            masterChef.getPendingRewards(alice, pids);

        assertEq(moeRewardAlice.length, 2, "test_ExtraRewarder::1");
        assertEq(extraTokenAlice.length, 2, "test_ExtraRewarder::2");
        assertEq(extraRewardAlice.length, 2, "test_ExtraRewarder::3");
        assertApproxEqAbs(moeRewardAlice[0], 50e18, 1, "test_ExtraRewarder::4");
        assertApproxEqAbs(moeRewardAlice[1], 0, 1, "test_ExtraRewarder::5");
        assertEq(address(extraTokenAlice[0]), address(rewardToken0), "test_ExtraRewarder::6");
        assertEq(address(extraTokenAlice[1]), address(rewardToken1), "test_ExtraRewarder::7");
        assertApproxEqAbs(extraRewardAlice[0], 5e18, 1, "test_ExtraRewarder::8");
        assertApproxEqAbs(extraRewardAlice[1], 40e6, 1, "test_ExtraRewarder::9");

        vm.prank(alice);
        masterChef.claim(pids);

        assertEq(moe.balanceOf(address(alice)), moeRewardAlice[0], "test_ExtraRewarder::10");
        assertEq(rewardToken0.balanceOf(address(alice)), extraRewardAlice[0], "test_ExtraRewarder::11");
        assertEq(rewardToken1.balanceOf(address(alice)), extraRewardAlice[1], "test_ExtraRewarder::12");

        (uint256[] memory moeRewardBob, IERC20[] memory extraTokenBob, uint256[] memory extraRewardBob) =
            masterChef.getPendingRewards(bob, pids);

        assertEq(moeRewardBob.length, 2, "test_ExtraRewarder::13");
        assertEq(extraTokenBob.length, 2, "test_ExtraRewarder::14");
        assertEq(extraRewardBob.length, 2, "test_ExtraRewarder::15");
        assertApproxEqAbs(moeRewardBob[0], 450e18, 1, "test_ExtraRewarder::16");
        assertApproxEqAbs(moeRewardBob[1], 0, 1, "test_ExtraRewarder::17");
        assertEq(address(extraTokenBob[0]), address(rewardToken0), "test_ExtraRewarder::18");
        assertEq(address(extraTokenBob[1]), address(rewardToken1), "test_ExtraRewarder::19");
        assertApproxEqAbs(extraRewardBob[0], 45e18, 1, "test_ExtraRewarder::20");
        assertApproxEqAbs(extraRewardBob[1], 160e6, 1, "test_ExtraRewarder::21");

        vm.prank(bob);
        masterChef.claim(pids);

        assertEq(moe.balanceOf(address(bob)), moeRewardBob[0], "test_ExtraRewarder::22");
        assertEq(rewardToken0.balanceOf(address(bob)), extraRewardBob[0], "test_ExtraRewarder::23");
        assertEq(rewardToken1.balanceOf(address(bob)), extraRewardBob[1], "test_ExtraRewarder::24");
    }
}

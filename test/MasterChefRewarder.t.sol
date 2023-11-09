// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/interface/IMasterChef.sol";
import "../src/MasterChefRewarder.sol";
import "../src/SimpleRewarder.sol";
import "./mocks/MockERC20.sol";

contract MasterChefRewarderTest is Test {
    MasterChefRewarder rewarder;
    MockMasterChef masterchef;

    IERC20 tokenA;
    IERC20 tokenB;

    IERC20 rewardToken;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        tokenA = IERC20(new MockERC20("Token A", "TA", 18));
        tokenB = IERC20(new MockERC20("Token B", "TB", 18));

        rewardToken = IERC20(new MockERC20("Reward Token", "RT", 6));
        masterchef = new MockMasterChef();

        rewarder = new MasterChefRewarder(rewardToken, address(masterchef), 0, address(this));
    }

    function test_GetRewarderParameter() public {
        (IERC20 token, uint256 rewardPerSecond, uint256 lastUpdateTimestamp, uint256 endTimestamp) =
            rewarder.getRewarderParameter();

        assertEq(address(token), address(rewardToken), "test_GetRewarderParameter::1");
        assertEq(rewardPerSecond, 0, "test_GetRewarderParameter::2");
        assertEq(lastUpdateTimestamp, 0, "test_GetRewarderParameter::3");
        assertEq(endTimestamp, 0, "test_GetRewarderParameter::4");
    }

    function test_SendNative() public {
        MasterChefRewarder nativeRewarder =
            new MasterChefRewarder(IERC20(address(0)), address(masterchef), 0, address(this));

        (bool s,) = address(nativeRewarder).call{value: 1}("");

        assertTrue(s, "test_SendNative::1");
        assertEq(address(nativeRewarder).balance, 1, "test_SendNative::2");

        (s,) = address(rewarder).call{value: 1}("");

        assertFalse(s, "test_SendNative::3");
    }

    function test_SetRewardPerSecond() public {
        rewarder.setRewardPerSecond(0, 0);

        vm.warp(block.timestamp + 1);

        vm.expectRevert(IRewarder.Rewarder__InvalidDuration.selector);
        rewarder.setRewardPerSecond(1, 0);

        vm.expectRevert(abi.encodeWithSelector(IRewarder.Rewarder__InsufficientReward.selector, 0, 1));
        rewarder.setRewardPerSecond(1, 1);

        MockERC20(address(rewardToken)).mint(address(rewarder), 100e18);

        rewarder.setRewardPerSecond(1e18, 100);

        (, uint256 rewardPerSecond,, uint256 endTimestamp) = rewarder.getRewarderParameter();

        assertEq(rewardPerSecond, 1e18, "test_SetRewardPerSecond::1");
        assertEq(endTimestamp, block.timestamp + 100, "test_SetRewardPerSecond::2");

        vm.warp(block.timestamp + 50);

        vm.expectRevert(abi.encodeWithSelector(IRewarder.Rewarder__InsufficientReward.selector, 50e18, 51e18));
        rewarder.setRewardPerSecond(1e18, 51);

        rewarder.setRewardPerSecond(0.5e18, 100);

        (, rewardPerSecond,, endTimestamp) = rewarder.getRewarderParameter();

        assertEq(rewardPerSecond, 0.5e18, "test_SetRewardPerSecond::3");
        assertEq(endTimestamp, block.timestamp + 100, "test_SetRewardPerSecond::4");

        vm.prank(address(masterchef));
        rewarder.link(0);

        rewarder.setRewardPerSecond(0, 0);

        vm.prank(address(masterchef));
        rewarder.unlink(0);

        vm.expectRevert(IRewarder.Rewarder__Stopped.selector);
        rewarder.setRewardPerSecond(0, 0);
    }

    function test_LinkUnlink() public {
        vm.expectRevert(IRewarder.Rewarder__InvalidCaller.selector);
        rewarder.link(0);

        vm.expectRevert(IRewarder.Rewarder__InvalidCaller.selector);
        rewarder.unlink(0);

        vm.startPrank(address(masterchef));

        vm.expectRevert(abi.encodeWithSelector(IMasterChefRewarder.MasterChefRewarder__InvalidPid.selector, uint256(1)));
        rewarder.link(1);

        vm.expectRevert(abi.encodeWithSelector(IMasterChefRewarder.MasterChefRewarder__InvalidPid.selector, uint256(1)));
        rewarder.unlink(1);

        vm.expectRevert(IMasterChefRewarder.MasterChefRewarder__NotLinked.selector);
        rewarder.unlink(0);

        rewarder.link(0);

        vm.expectRevert(IMasterChefRewarder.MasterChefRewarder__AlreadyLinked.selector);
        rewarder.link(0);

        rewarder.unlink(0);

        vm.expectRevert(IMasterChefRewarder.MasterChefRewarder__AlreadyLinked.selector);
        rewarder.link(0);

        vm.expectRevert(IMasterChefRewarder.MasterChefRewarder__NotLinked.selector);
        rewarder.unlink(0);

        vm.stopPrank();
    }

    function test_OnModify() public {
        vm.startPrank(address(masterchef));

        vm.expectRevert(abi.encodeWithSelector(IMasterChefRewarder.MasterChefRewarder__InvalidPid.selector, uint256(1)));
        rewarder.onModify(alice, 1, 0, 0, 0);

        vm.expectRevert(IMasterChefRewarder.MasterChefRewarder__NotLinked.selector);
        rewarder.onModify(alice, 0, 0, 0, 0);

        rewarder.link(0);

        vm.stopPrank();

        vm.expectRevert(IRewarder.Rewarder__InvalidCaller.selector);
        rewarder.onModify(alice, 0, 0, 0, 0);

        vm.startPrank(address(masterchef));

        rewarder.onModify(alice, 0, 0, 1e18, 1e18);
        rewarder.onModify(bob, 0, 0, 2e18, 3e18);

        masterchef.setTotalDeposit(0, 3e18);

        MockERC20(address(rewardToken)).mint(address(rewarder), 300e18);

        vm.stopPrank();

        rewarder.setRewardPerSecond(3e18, 100);

        vm.warp(block.timestamp + 50);

        (, uint256 rewardA) = rewarder.getPendingReward(alice, 1e18, 3e18);
        (, uint256 rewardB) = rewarder.getPendingReward(bob, 2e18, 3e18);

        assertEq(rewardA, 50e18, "test_OnModify::1");
        assertEq(rewardB, 100e18, "test_OnModify::2");

        vm.startPrank(address(masterchef));

        rewarder.onModify(alice, 0, 1e18, 1e18, 3e18);

        assertEq(rewardToken.balanceOf(alice), 50e18, "test_OnModify::3");
        assertEq(rewardToken.balanceOf(address(rewarder)), 250e18, "test_OnModify::4");

        vm.warp(block.timestamp + 50);

        (, rewardA) = rewarder.getPendingReward(alice, 1e18, 3e18);
        (, rewardB) = rewarder.getPendingReward(bob, 2e18, 3e18);

        assertEq(rewardA, 50e18, "test_OnModify::5");
        assertEq(rewardB, 200e18, "test_OnModify::6");

        vm.warp(block.timestamp + 100);

        (, rewardA) = rewarder.getPendingReward(alice, 1e18, 3e18);
        (, rewardB) = rewarder.getPendingReward(bob, 2e18, 3e18);

        assertEq(rewardA, 50e18, "test_OnModify::5");
        assertEq(rewardB, 200e18, "test_OnModify::6");

        vm.stopPrank();

        assertGt(rewardToken.balanceOf(address(rewarder)), 0, "test_OnModify::7");

        vm.expectRevert(abi.encodeWithSelector(IRewarder.Rewarder__InsufficientReward.selector, 0, 1));
        rewarder.setRewardPerSecond(1, 1);

        MockERC20(address(rewardToken)).mint(address(rewarder), 30e18);

        rewarder.setRewardPerSecond(0.3e18, 50);

        vm.warp(block.timestamp + 25);

        rewarder.setRewardPerSecond(0.1e18, 3 * 75);

        vm.warp(block.timestamp + 3 * 75);

        (, rewardA) = rewarder.getPendingReward(alice, 1e18, 3e18);
        (, rewardB) = rewarder.getPendingReward(bob, 2e18, 3e18);

        assertEq(rewardA, 60e18, "test_OnModify::8");
        assertEq(rewardB, 220e18, "test_OnModify::9");

        rewarder.setRewardPerSecond(0, 0);

        vm.warp(block.timestamp + 100);

        (, rewardA) = rewarder.getPendingReward(alice, 1e18, 3e18);
        (, rewardB) = rewarder.getPendingReward(bob, 2e18, 3e18);

        assertEq(rewardA, 60e18, "test_OnModify::8");
        assertEq(rewardB, 220e18, "test_OnModify::9");

        vm.startPrank(address(masterchef));

        rewarder.onModify(alice, 0, 1e18, 1e18, 3e18);

        assertEq(rewardToken.balanceOf(alice), 110e18, "test_OnModify::10");
        assertEq(rewardToken.balanceOf(address(rewarder)), 220e18, "test_OnModify::11");

        rewarder.onModify(bob, 0, 2e18, 2e18, 3e18);

        assertEq(rewardToken.balanceOf(bob), 220e18, "test_OnModify::12");
        assertEq(rewardToken.balanceOf(address(rewarder)), 0, "test_OnModify::13");

        vm.stopPrank();
    }

    function test_Sweep() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        rewarder.sweep(tokenA, alice);

        MockERC20(address(tokenA)).mint(address(rewarder), 100e18);

        rewarder.sweep(tokenA, alice);

        assertEq(tokenA.balanceOf(alice), 100e18, "test_Sweep::1");
        assertEq(tokenA.balanceOf(address(rewarder)), 0, "test_Sweep::2");

        vm.expectRevert(IRewarder.Rewarder__InvalidToken.selector);
        rewarder.sweep(rewardToken, alice);

        vm.deal(address(rewarder), 1e18);

        vm.expectRevert(IRewarder.Rewarder__NativeTransferFailed.selector);
        rewarder.sweep(IERC20(address(0)), address(rewarder));

        rewarder.sweep(IERC20(address(0)), alice);

        assertEq(address(rewarder).balance, 0, "test_Sweep::3");
        assertEq(address(alice).balance, 1e18, "test_Sweep::4");
    }

    function test_Stop() public {
        MockERC20(address(rewardToken)).mint(address(rewarder), 100e18);

        vm.expectRevert(IMasterChefRewarder.MasterChefRewarder__UseUnlink.selector);
        rewarder.stop();

        vm.prank(address(masterchef));
        rewarder.link(0);

        vm.expectRevert(IMasterChefRewarder.MasterChefRewarder__UseUnlink.selector);
        rewarder.stop();

        assertFalse(rewarder.isStopped(), "test_Stop::1");

        vm.prank(address(masterchef));
        rewarder.unlink(0);

        assertTrue(rewarder.isStopped(), "test_Stop::2");

        vm.expectRevert(IMasterChefRewarder.MasterChefRewarder__UseUnlink.selector);
        rewarder.stop();

        assertEq(rewardToken.balanceOf(alice), 0, "test_Stop::3");
        assertEq(rewardToken.balanceOf(address(rewarder)), 100e18, "test_Stop::4");

        rewarder.sweep(rewardToken, alice);

        assertEq(rewardToken.balanceOf(alice), 100e18, "test_Stop::5");
        assertEq(rewardToken.balanceOf(address(rewarder)), 0, "test_Stop::6");
    }
}

contract MockMasterChef {
    mapping(uint256 => uint256) public getTotalDeposit;

    function setTotalDeposit(uint256 pid, uint256 totalDeposit) external {
        getTotalDeposit[pid] = totalDeposit;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

import "../src/interfaces/IMasterChef.sol";
import "../src/rewarders/MasterChefRewarder.sol";
import "../src/rewarders/BaseRewarder.sol";
import "../src/rewarders/RewarderFactory.sol";
import "../src/transparent/TransparentUpgradeableProxy2Step.sol";
import "./mocks/MockERC20.sol";

contract MasterChefRewarderTest is Test {
    MasterChefRewarder rewarder;
    MockMasterChef masterchef;
    RewarderFactory factory;

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

        address factoryImpl = address(new RewarderFactory());
        factory = RewarderFactory(
            address(
                new TransparentUpgradeableProxy2Step(
                    factoryImpl,
                    ProxyAdmin2Step(address(1)),
                    abi.encodeWithSelector(RewarderFactory.initialize.selector, address(this), new uint8[](0), new address[](0))
                )
            )
        );
        factory.setRewarderImplementation(
            IRewarderFactory.RewarderType.MasterChefRewarder, new MasterChefRewarder(address(masterchef))
        );

        rewarder = MasterChefRewarder(
            payable(address(factory.createRewarder(IRewarderFactory.RewarderType.MasterChefRewarder, rewardToken, 0)))
        );
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
        MasterChefRewarder nativeRewarder = MasterChefRewarder(
            payable(
                address(factory.createRewarder(IRewarderFactory.RewarderType.MasterChefRewarder, IERC20(address(0)), 0))
            )
        );

        (bool s,) = address(nativeRewarder).call{value: 1}("");

        assertTrue(s, "test_SendNative::1");
        assertEq(address(nativeRewarder).balance, 1, "test_SendNative::2");

        (s,) = address(rewarder).call{value: 1}("");

        assertFalse(s, "test_SendNative::3");
    }

    function test_SetRewardPerSecond() public {
        rewarder.setRewardPerSecond(0, 0);

        vm.prank(address(masterchef));
        rewarder.link(0);

        masterchef.setTotalDeposit(0, 1e18);

        vm.warp(block.timestamp + 1);

        vm.expectRevert(IBaseRewarder.BaseRewarder__InvalidDuration.selector);
        rewarder.setRewardPerSecond(1, 0);

        vm.expectRevert(abi.encodeWithSelector(IBaseRewarder.BaseRewarder__InsufficientReward.selector, 0, 1));
        rewarder.setRewardPerSecond(1, 1);

        MockERC20(address(rewardToken)).mint(address(rewarder), 100e18);

        rewarder.setRewardPerSecond(1e18, 100);

        (, uint256 rewardPerSecond,, uint256 endTimestamp) = rewarder.getRewarderParameter();

        assertEq(rewardPerSecond, 1e18, "test_SetRewardPerSecond::1");
        assertEq(endTimestamp, block.timestamp + 100, "test_SetRewardPerSecond::2");

        vm.warp(block.timestamp + 50);

        vm.expectRevert(abi.encodeWithSelector(IBaseRewarder.BaseRewarder__InsufficientReward.selector, 50e18, 51e18));
        rewarder.setRewardPerSecond(1e18, 51);

        rewarder.setRewardPerSecond(0.5e18, 100);

        (, rewardPerSecond,, endTimestamp) = rewarder.getRewarderParameter();

        assertEq(rewardPerSecond, 0.5e18, "test_SetRewardPerSecond::3");
        assertEq(endTimestamp, block.timestamp + 100, "test_SetRewardPerSecond::4");

        rewarder.setRewardPerSecond(0, 0);

        vm.prank(address(masterchef));
        rewarder.unlink(0);

        vm.expectRevert(IBaseRewarder.BaseRewarder__Stopped.selector);
        rewarder.setRewardPerSecond(0, 0);
    }

    function test_LinkUnlink() public {
        vm.expectRevert(IBaseRewarder.BaseRewarder__InvalidCaller.selector);
        rewarder.link(0);

        vm.expectRevert(IBaseRewarder.BaseRewarder__InvalidCaller.selector);
        rewarder.unlink(0);

        vm.startPrank(address(masterchef));

        vm.expectRevert(abi.encodeWithSelector(IBaseRewarder.BaseRewarder__InvalidPid.selector, uint256(1)));
        rewarder.link(1);

        vm.expectRevert(abi.encodeWithSelector(IBaseRewarder.BaseRewarder__InvalidPid.selector, uint256(1)));
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

        vm.expectRevert(IMasterChefRewarder.MasterChefRewarder__NotLinked.selector);
        rewarder.onModify(alice, 0, 0, 0, 0);

        rewarder.link(0);

        vm.expectRevert(abi.encodeWithSelector(IBaseRewarder.BaseRewarder__InvalidPid.selector, uint256(1)));
        rewarder.onModify(alice, 1, 0, 0, 0);

        vm.stopPrank();

        vm.expectRevert(IBaseRewarder.BaseRewarder__InvalidCaller.selector);
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

        assertEq(rewardA, 50e18, "test_OnModify::7");
        assertEq(rewardB, 200e18, "test_OnModify::8");

        vm.stopPrank();

        assertGt(rewardToken.balanceOf(address(rewarder)), 0, "test_OnModify::9");

        vm.expectRevert(abi.encodeWithSelector(IBaseRewarder.BaseRewarder__InsufficientReward.selector, 0, 1));
        rewarder.setRewardPerSecond(1, 1);

        MockERC20(address(rewardToken)).mint(address(rewarder), 30e18);

        rewarder.setRewardPerSecond(0.3e18, 50);

        vm.warp(block.timestamp + 25);

        rewarder.setRewardPerSecond(0.1e18, 3 * 75);

        vm.warp(block.timestamp + 3 * 75);

        (, rewardA) = rewarder.getPendingReward(alice, 1e18, 3e18);
        (, rewardB) = rewarder.getPendingReward(bob, 2e18, 3e18);

        assertEq(rewardA, 60e18, "test_OnModify::10");
        assertEq(rewardB, 220e18, "test_OnModify::11");

        rewarder.setRewardPerSecond(0, 0);

        vm.warp(block.timestamp + 100);

        (, rewardA) = rewarder.getPendingReward(alice, 1e18, 3e18);
        (, rewardB) = rewarder.getPendingReward(bob, 2e18, 3e18);

        assertEq(rewardA, 60e18, "test_OnModify::12");
        assertEq(rewardB, 220e18, "test_OnModify::13");

        vm.startPrank(address(masterchef));

        rewarder.onModify(alice, 0, 1e18, 1e18, 3e18);

        assertEq(rewardToken.balanceOf(alice), 110e18, "test_OnModify::14");
        assertEq(rewardToken.balanceOf(address(rewarder)), 220e18, "test_OnModify::15");

        rewarder.onModify(bob, 0, 2e18, 2e18, 3e18);

        assertEq(rewardToken.balanceOf(bob), 220e18, "test_OnModify::16");
        assertEq(rewardToken.balanceOf(address(rewarder)), 0, "test_OnModify::17");

        vm.stopPrank();
    }

    function test_Sweep() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        rewarder.sweep(tokenA, alice);

        vm.expectRevert(IBaseRewarder.BaseRewarder__ZeroAmount.selector);
        rewarder.sweep(tokenA, alice);

        MockERC20(address(tokenA)).mint(address(rewarder), 100e18);

        rewarder.sweep(tokenA, alice);

        assertEq(tokenA.balanceOf(alice), 100e18, "test_Sweep::1");
        assertEq(tokenA.balanceOf(address(rewarder)), 0, "test_Sweep::2");

        vm.expectRevert(IBaseRewarder.BaseRewarder__ZeroAmount.selector);
        rewarder.sweep(rewardToken, alice);

        MockERC20(address(rewardToken)).mint(address(rewarder), 100e18);

        rewarder.setRewardPerSecond(1e18, 99);
        rewarder.sweep(rewardToken, alice);

        assertEq(rewardToken.balanceOf(alice), 1e18, "test_Sweep::3");
        assertEq(rewardToken.balanceOf(address(rewarder)), 99e18, "test_Sweep::4");

        vm.deal(address(rewarder), 1e18);

        vm.expectRevert(IBaseRewarder.BaseRewarder__NativeTransferFailed.selector);
        rewarder.sweep(IERC20(address(0)), address(rewarder));

        rewarder.sweep(IERC20(address(0)), alice);

        assertEq(address(rewarder).balance, 0, "test_Sweep::5");
        assertEq(address(alice).balance, 1e18, "test_Sweep::6");

        vm.startPrank(address(masterchef));
        rewarder.link(0);
        rewarder.unlink(0);
        vm.stopPrank();

        rewarder.sweep(rewardToken, alice);

        assertEq(rewardToken.balanceOf(alice), 100e18, "test_Sweep::7");
        assertEq(rewardToken.balanceOf(address(rewarder)), 0, "test_Sweep::8");
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

    function test_SetRewarderParameters() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        rewarder.setRewarderParameters(0, 0, 0);

        vm.expectRevert(
            abi.encodePacked(IBaseRewarder.BaseRewarder__InvalidStartTimestamp.selector, block.timestamp - 1)
        );
        rewarder.setRewarderParameters(1e18, block.timestamp - 1, 100);

        vm.expectRevert(abi.encodeWithSelector(IBaseRewarder.BaseRewarder__InvalidDuration.selector));
        rewarder.setRewarderParameters(1e18, block.timestamp, 0);

        vm.expectRevert(abi.encodeWithSelector(IBaseRewarder.BaseRewarder__InsufficientReward.selector, 0, 1));
        rewarder.setRewarderParameters(1, block.timestamp, 1);

        vm.startPrank(address(masterchef));
        masterchef.setTotalDeposit(0, 1e18);
        rewarder.link(0);
        rewarder.onModify(alice, 0, 1e18, 0, 1e18);
        vm.stopPrank();

        MockERC20(address(rewardToken)).mint(address(rewarder), 100e18);

        rewarder.setRewarderParameters(1e18, block.timestamp, 100);

        (, uint256 rewardPerSecond, uint256 startTimestamp, uint256 endTimestamp) = rewarder.getRewarderParameter();

        assertEq(rewardPerSecond, 1e18, "test_SetRewarderParameters::1");
        assertEq(startTimestamp, block.timestamp, "test_SetRewarderParameters::2");
        assertEq(endTimestamp, block.timestamp + 100, "test_SetRewarderParameters::3");

        vm.warp(block.timestamp + 50);

        (, uint256 pendingReward1) = rewarder.getPendingReward(alice, 1e18, 1e18);

        assertEq(pendingReward1, 50e18, "test_SetRewarderParameters::4");

        rewarder.setRewarderParameters(0.5e18, block.timestamp + 50, 100);

        (, rewardPerSecond, startTimestamp, endTimestamp) = rewarder.getRewarderParameter();

        assertEq(rewardPerSecond, 0.5e18, "test_SetRewarderParameters::5");
        assertEq(startTimestamp, block.timestamp + 50, "test_SetRewarderParameters::6");
        assertEq(endTimestamp, block.timestamp + 150, "test_SetRewarderParameters::7");

        (, uint256 pendingReward2) = rewarder.getPendingReward(alice, 1e18, 1e18);

        assertEq(pendingReward2, pendingReward1, "test_SetRewarderParameters::8");

        vm.warp(block.timestamp + 50);

        (, pendingReward2) = rewarder.getPendingReward(alice, 1e18, 1e18);

        assertEq(pendingReward2, pendingReward1, "test_SetRewarderParameters::9");

        vm.warp(block.timestamp + 50);

        (, pendingReward2) = rewarder.getPendingReward(alice, 1e18, 1e18);

        assertEq(pendingReward2, pendingReward1 + 25e18, "test_SetRewarderParameters::10");

        vm.warp(block.timestamp + 50);

        (, pendingReward2) = rewarder.getPendingReward(alice, 1e18, 1e18);

        assertEq(pendingReward2, pendingReward1 + 50e18, "test_SetRewarderParameters::11");
    }
}

contract MockMasterChef {
    mapping(uint256 => uint256) public getTotalDeposit;

    function setTotalDeposit(uint256 pid, uint256 totalDeposit) external {
        getTotalDeposit[pid] = totalDeposit;
    }
}

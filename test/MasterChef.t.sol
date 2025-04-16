// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../src/transparent/TransparentUpgradeableProxy2Step.sol";
import "../src/MasterChef.sol";
import "../src/Moe.sol";
import "./mocks/MockVeMoe.sol";
import "./mocks/MockERC20.sol";
import "../src/rewarders/MasterChefRewarder.sol";
import "../src/rewarders/RewarderFactory.sol";

contract MasterChefTest is Test {
    MasterChef masterChef;
    IMoe moe;
    MockVeMoe veMoe;
    RewarderFactory factory;

    IERC20 tokenA;
    IERC20 tokenB;

    IERC20 rewardToken0;
    IERC20 rewardToken1;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        tokenA = IERC20(new MockERC20("Token A", "TA", 18));
        tokenB = IERC20(new MockERC20("Token B", "TB", 18));

        rewardToken0 = IERC20(new MockERC20("Reward Token", "RT", 18));
        rewardToken1 = IERC20(new MockERC20("Reward Token", "RT", 6));

        uint256 nonce = vm.getNonce(address(this));

        address masterChefAddress = computeCreateAddress(address(this), nonce + 3);
        address factoryAddress = computeCreateAddress(address(this), nonce + 5);

        veMoe = new MockVeMoe(masterChefAddress);

        moe = IMoe(address(new Moe(masterChefAddress, 0, Constants.MAX_SUPPLY)));

        masterChef = new MasterChef(moe, IVeMoe(address(veMoe)), IRewarderFactory(factoryAddress), address(0), 0.5e18);

        TransparentUpgradeableProxy2Step proxy = new TransparentUpgradeableProxy2Step(
            address(masterChef),
            ProxyAdmin2Step(address(1)),
            abi.encodeWithSelector(
                MasterChef.initialize.selector, address(this), address(this), address(this), address(this), 0, 0
            )
        );

        masterChef = MasterChef(address(proxy));

        address factoryImpl = address(new RewarderFactory());
        factory = RewarderFactory(
            address(
                new TransparentUpgradeableProxy2Step(
                    factoryImpl,
                    ProxyAdmin2Step(address(1)),
                    abi.encodeWithSelector(
                        RewarderFactory.initialize.selector, address(this), new uint8[](0), new address[](0)
                    )
                )
            )
        );
        factory.setRewarderImplementation(
            IRewarderFactory.RewarderType.MasterChefRewarder, new MasterChefRewarder(address(masterChef))
        );

        require(address(masterChef) == masterChefAddress, "MasterChefTest::setUp::1");
        require(address(factory) == factoryAddress, "MasterChefTest::setUp::2");

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
        assertEq(address(masterChef.getRewarderFactory()), address(factory), "test_SetUp::3");
        assertEq(address(moe.getMinter()), address(masterChef), "test_SetUp::4");
        assertEq(moe.getMaxSupply(), Constants.MAX_SUPPLY, "test_SetUp::5");
        assertEq(address(masterChef.getToken(0)), address(tokenA), "test_SetUp::6");
        assertEq(address(masterChef.getToken(1)), address(tokenB), "test_SetUp::7");
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
        moePerSecond = uint96(bound(moePerSecond, 0, Constants.MAX_MOE_PER_SECOND));

        masterChef.setMoePerSecond(moePerSecond);

        assertEq(masterChef.getMoePerSecond(), moePerSecond, "test_SetMoePerSecond::1");

        assertEq(masterChef.getLastUpdateTimestamp(0), block.timestamp, "test_SetMoePerSecond::2");
        assertEq(masterChef.getLastUpdateTimestamp(1), block.timestamp, "test_SetMoePerSecond::3");

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        masterChef.setMoePerSecond(moePerSecond);
    }

    function test_Claim() public {
        masterChef.setMoePerSecond(2e18);

        {
            veMoe.setVotes(0, 1e18);
            veMoe.setVotes(1, 1e18);

            uint256[] memory topPids = new uint256[](2);

            topPids[0] = 0;
            topPids[1] = 1;

            IVeMoe(address(veMoe)).setTopPoolIds(topPids);
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
        assertEq(moe.balanceOf(address(this)), 5e18, "test_Claim::2");

        vm.prank(bob);
        masterChef.deposit(0, 0);

        assertEq(moe.balanceOf(address(bob)), 4.5e18, "test_Claim::3");
        assertEq(moe.balanceOf(address(this)), 5e18, "test_Claim::4");

        vm.warp(block.timestamp + 10);

        pids = new uint256[](2);
        pids[1] = 1;

        vm.prank(alice);
        masterChef.claim(pids);

        assertEq(moe.balanceOf(address(alice)), 3e18, "test_Claim::5");
        assertEq(moe.balanceOf(address(this)), 20e18, "test_Claim::6");

        vm.prank(bob);
        masterChef.claim(pids);

        assertEq(moe.balanceOf(address(bob)), 17e18, "test_Claim::7");
        assertEq(moe.balanceOf(address(this)), 20e18, "test_Claim::8");

        vm.prank(alice);
        masterChef.claim(pids);

        assertEq(moe.balanceOf(address(alice)), 3e18, "test_Claim::9");
        assertEq(moe.balanceOf(address(this)), 20e18, "test_Claim::10");

        vm.prank(bob);
        masterChef.claim(pids);

        assertEq(moe.balanceOf(address(bob)), 17e18, "test_Claim::11");
        assertEq(moe.balanceOf(address(this)), 20e18, "test_Claim::12");
    }

    function test_Add() public {
        masterChef.add(tokenA, IMasterChefRewarder(address(0)));

        MasterChefRewarder rewarder = MasterChefRewarder(
            payable(address(factory.createRewarder(IRewarderFactory.RewarderType.MasterChefRewarder, rewardToken0, 3)))
        );

        masterChef.add(tokenA, IMasterChefRewarder(address(rewarder)));

        assertEq(address(masterChef.getExtraRewarder(3)), address(rewarder), "test_Add::1");

        MasterChefRewarder rewarder1 = MasterChefRewarder(
            payable(address(factory.createRewarder(IRewarderFactory.RewarderType.MasterChefRewarder, rewardToken0, 2)))
        );
        MasterChefRewarder rewarder2 = MasterChefRewarder(
            payable(address(factory.createRewarder(IRewarderFactory.RewarderType.MasterChefRewarder, rewardToken0, 2)))
        );

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

        vm.prank(address(tokenA));
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, tokenA));
        masterChef.add(tokenA, IMasterChefRewarder(address(0)));

        address lbHooksManager = makeAddr("lbHooksManager");
        masterChef = new MasterChef(moe, IVeMoe(address(veMoe)), factory, lbHooksManager, 0);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        masterChef.add(tokenA, IMasterChefRewarder(address(0)));

        vm.prank(lbHooksManager);
        masterChef.add(tokenA, IMasterChefRewarder(address(0)));
    }

    function test_EmergencyWithdrawal() public {
        masterChef.setMoePerSecond(2e18);

        veMoe.setVotes(0, 1e18);
        IVeMoe(address(veMoe)).setTopPoolIds(new uint256[](1));

        assertEq(masterChef.getMoePerSecondForPid(0), 2e18, "test_EmergencyWithdrawal::1");
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
        assertEq(moe.balanceOf(address(this)), 10e18, "test_EmergencyWithdrawal::6");

        vm.prank(alice);
        masterChef.deposit(0, 1e18);

        assertEq(moe.balanceOf(address(alice)), 0, "test_EmergencyWithdrawal::7");

        vm.warp(block.timestamp + 10);

        vm.prank(alice);
        masterChef.claim(new uint256[](1));

        assertApproxEqAbs(moe.balanceOf(address(alice)), 1e18, 1, "test_EmergencyWithdrawal::8");
        assertEq(moe.balanceOf(address(this)), 20e18, "test_EmergencyWithdrawal::9");

        vm.prank(bob);
        masterChef.emergencyWithdraw(0);

        vm.prank(alice);
        masterChef.claim(new uint256[](1));

        assertApproxEqAbs(moe.balanceOf(address(alice)), 1e18, 1, "test_EmergencyWithdrawal::10");
        assertEq(moe.balanceOf(address(this)), 20e18, "test_EmergencyWithdrawal::11");
    }

    function test_TreasuryShare() public {
        veMoe.setVotes(0, 1e18);
        IVeMoe(address(veMoe)).setTopPoolIds(new uint256[](1));

        address treasury = makeAddr("treasury");
        address futureFunding = makeAddr("futureFunding");
        address team = makeAddr("team");

        uint256 nonce = vm.getNonce(address(this));
        address masterChefAddress = computeCreateAddress(address(this), nonce + 2);

        moe = IMoe(address(new Moe(masterChefAddress, 0, Constants.MAX_SUPPLY)));
        masterChef = new MasterChef(moe, IVeMoe(address(veMoe)), factory, address(0), 0.3e18);

        TransparentUpgradeableProxy2Step proxy = new TransparentUpgradeableProxy2Step(
            address(masterChef),
            ProxyAdmin2Step(address(1)),
            abi.encodeWithSelector(
                MasterChef.initialize.selector, address(this), treasury, futureFunding, team, 10e18, 20e18
            )
        );

        masterChef = MasterChef(address(proxy));

        assertEq(masterChef.getTreasury(), treasury, "test_TreasuryShare::1");
        assertEq(masterChef.getTreasuryShare(), 0.3e18, "test_TreasuryShare::2");

        masterChef.add(tokenA, IMasterChefRewarder(address(0)));
        masterChef.setMoePerSecond(1e18);

        vm.startPrank(alice);
        tokenA.approve(address(masterChef), type(uint256).max);
        masterChef.deposit(0, 1e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 10);

        (uint256[] memory moeRewards, IERC20[] memory extraTokens, uint256[] memory extraRewards) =
            masterChef.getPendingRewards(alice, new uint256[](1));

        assertEq(moeRewards.length, 1, "test_TreasuryShare::3");
        assertEq(extraTokens.length, 1, "test_TreasuryShare::4");
        assertEq(extraRewards.length, 1, "test_TreasuryShare::5");
        assertEq(moeRewards[0], 7e18, "test_TreasuryShare::6");
        assertEq(address(extraTokens[0]), address(0), "test_TreasuryShare::7");
        assertEq(extraRewards[0], 0, "test_TreasuryShare::8");
        assertEq(moe.balanceOf(futureFunding), 10e18, "test_TreasuryShare::9");
        assertEq(moe.balanceOf(team), 20e18, "test_TreasuryShare::10");

        masterChef.updateAll(new uint256[](1));

        (moeRewards, extraTokens, extraRewards) = masterChef.getPendingRewards(alice, new uint256[](1));

        assertEq(moeRewards.length, 1, "test_TreasuryShare::11");
        assertEq(extraTokens.length, 1, "test_TreasuryShare::12");
        assertEq(extraRewards.length, 1, "test_TreasuryShare::13");
        assertEq(moeRewards[0], 7e18, "test_TreasuryShare::14");
        assertEq(address(extraTokens[0]), address(0), "test_TreasuryShare::15");
        assertEq(extraRewards[0], 0, "test_TreasuryShare::16");
        assertEq(moe.balanceOf(address(alice)), 0, "test_TreasuryShare::17");
        assertEq(moe.balanceOf(address(treasury)), 3e18, "test_TreasuryShare::18");

        vm.prank(alice);
        masterChef.claim(new uint256[](1));

        assertEq(moe.balanceOf(address(alice)), 7e18, "test_TreasuryShare::19");
        assertEq(moe.balanceOf(address(treasury)), 3e18, "test_TreasuryShare::20");

        vm.expectRevert(IMasterChef.MasterChef__ZeroAddress.selector);
        masterChef.setTreasury(address(0));

        masterChef.setTreasury(address(1));

        assertEq(masterChef.getTreasuryShare(), 0.3e18, "test_TreasuryShare::21");
        assertEq(masterChef.getTreasury(), address(1), "test_TreasuryShare::22");

        vm.expectRevert(IMasterChef.MasterChef__InvalidShares.selector);
        new MasterChef(moe, IVeMoe(address(veMoe)), factory, address(0), 1e18 + 1);

        new MasterChef(moe, IVeMoe(address(veMoe)), factory, address(0), 1e18);
    }

    function test_ExtraRewarder() public {
        MasterChefRewarder rewarder0 = MasterChefRewarder(
            payable(address(factory.createRewarder(IRewarderFactory.RewarderType.MasterChefRewarder, rewardToken0, 0)))
        );
        MasterChefRewarder rewarder1 = MasterChefRewarder(
            payable(address(factory.createRewarder(IRewarderFactory.RewarderType.MasterChefRewarder, rewardToken1, 1)))
        );

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
        veMoe.setVotes(1, 1e18);

        IVeMoe(address(veMoe)).setTopPoolIds(new uint256[](1));

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
        assertApproxEqAbs(moeRewardAlice[0], 25e18, 1, "test_ExtraRewarder::4");
        assertApproxEqAbs(moeRewardAlice[1], 0, 1, "test_ExtraRewarder::5");
        assertEq(address(extraTokenAlice[0]), address(rewardToken0), "test_ExtraRewarder::6");
        assertEq(address(extraTokenAlice[1]), address(rewardToken1), "test_ExtraRewarder::7");
        assertApproxEqAbs(extraRewardAlice[0], 5e18, 1, "test_ExtraRewarder::8");
        assertApproxEqAbs(extraRewardAlice[1], 40e6, 1, "test_ExtraRewarder::9");
        assertEq(moe.balanceOf(address(this)), 0, "test_ExtraRewarder::10");

        vm.prank(alice);
        masterChef.claim(pids);

        assertEq(moe.balanceOf(address(alice)), moeRewardAlice[0], "test_ExtraRewarder::11");
        assertEq(rewardToken0.balanceOf(address(alice)), extraRewardAlice[0], "test_ExtraRewarder::12");
        assertEq(rewardToken1.balanceOf(address(alice)), extraRewardAlice[1], "test_ExtraRewarder::13");
        assertEq(moe.balanceOf(address(this)), 250e18, "test_ExtraRewarder::14");

        (uint256[] memory moeRewardBob, IERC20[] memory extraTokenBob, uint256[] memory extraRewardBob) =
            masterChef.getPendingRewards(bob, pids);

        assertEq(moeRewardBob.length, 2, "test_ExtraRewarder::15");
        assertEq(extraTokenBob.length, 2, "test_ExtraRewarder::16");
        assertEq(extraRewardBob.length, 2, "test_ExtraRewarder::17");
        assertApproxEqAbs(moeRewardBob[0], 225e18, 1, "test_ExtraRewarder::18");
        assertApproxEqAbs(moeRewardBob[1], 0, 1, "test_ExtraRewarder::19");
        assertEq(address(extraTokenBob[0]), address(rewardToken0), "test_ExtraRewarder::20");
        assertEq(address(extraTokenBob[1]), address(rewardToken1), "test_ExtraRewarder::21");
        assertApproxEqAbs(extraRewardBob[0], 45e18, 1, "test_ExtraRewarder::22");
        assertApproxEqAbs(extraRewardBob[1], 160e6, 1, "test_ExtraRewarder::23");
        assertEq(moe.balanceOf(address(this)), 250e18, "test_ExtraRewarder::24");

        vm.prank(bob);
        masterChef.claim(pids);

        assertEq(moe.balanceOf(address(bob)), moeRewardBob[0], "test_ExtraRewarder::25");
        assertEq(rewardToken0.balanceOf(address(bob)), extraRewardBob[0], "test_ExtraRewarder::26");
        assertEq(rewardToken1.balanceOf(address(bob)), extraRewardBob[1], "test_ExtraRewarder::27");
        assertEq(moe.balanceOf(address(this)), 250e18, "test_ExtraRewarder::28");
    }

    function test_Fuzz_SetStaticPoolShares(uint256 staticShare, uint256[] memory shares) public {
        staticShare = bound(staticShare, 1, 1e18);
        uint256 length = bound(shares.length, 0, Constants.MAX_NUMBER_OF_FARMS);
        assembly {
            mstore(shares, length)
        }
        masterChef.setMoePerSecond(uint96(Constants.MAX_MOE_PER_SECOND));

        for (uint256 i; i < length; i++) {
            if (i > 1) masterChef.add(tokenA, IMasterChefRewarder(address(0)));
            shares[i] = bound(shares[i], 1, Constants.MAX_STATIC_SHARES / length);
        }

        assertEq(masterChef.getStaticShare(), 0, "test_Fuzz_SetStaticPoolShares::1");
        assertEq(masterChef.getTotalStaticPoolShares(), 0, "test_Fuzz_SetStaticPoolShares::2");
        assertEq(masterChef.getStaticPoolIds().length, 0, "test_Fuzz_SetStaticPoolShares::3");

        masterChef.setStaticShare(uint128(staticShare));

        assertEq(masterChef.getStaticShare(), staticShare, "test_Fuzz_SetStaticPoolShares::4");
        assertEq(masterChef.getTotalStaticPoolShares(), 0, "test_Fuzz_SetStaticPoolShares::5");
        assertEq(masterChef.getStaticPoolIds().length, 0, "test_Fuzz_SetStaticPoolShares::6");

        uint256 sum = 0;
        for (uint256 i; i < length; i++) {
            masterChef.setStaticPoolShare(i, uint128(shares[i]));
            sum += shares[i];

            assertEq(masterChef.getStaticPoolShare(i), shares[i], "test_Fuzz_SetStaticPoolShares::7");
            assertEq(masterChef.isStaticPool(i), true, "test_Fuzz_SetStaticPoolShares::8");
            assertEq(masterChef.getTotalStaticPoolShares(), sum, "test_Fuzz_SetStaticPoolShares::9");

            uint256[] memory staticPoolIds = masterChef.getStaticPoolIds();
            assertEq(staticPoolIds.length, i + 1, "test_Fuzz_SetStaticPoolShares::10");
            assertEq(staticPoolIds[i], i, "test_Fuzz_SetStaticPoolShares::11");
            assertEq(
                masterChef.getMoePerSecondForPid(i),
                Constants.MAX_MOE_PER_SECOND * shares[i] * staticShare / (sum * 1e18),
                "test_Fuzz_SetStaticPoolShares::12"
            );
        }

        masterChef.setStaticShare(0);

        assertEq(masterChef.getStaticShare(), 0, "test_Fuzz_SetStaticPoolShares::13");
        assertEq(masterChef.getTotalStaticPoolShares(), sum, "test_Fuzz_SetStaticPoolShares::14");
        assertEq(masterChef.getStaticPoolIds().length, length, "test_Fuzz_SetStaticPoolShares::15");

        {
            uint256[] memory staticPoolIds = masterChef.getStaticPoolIds();
            for (uint256 i; i < length; i++) {
                assertEq(masterChef.getStaticPoolShare(i), shares[i], "test_Fuzz_SetStaticPoolShares::16");
                assertEq(staticPoolIds[i], i, "test_Fuzz_SetStaticPoolShares::17");
                assertEq(masterChef.getMoePerSecondForPid(i), 0, "test_Fuzz_SetStaticPoolShares::18");
            }
        }

        masterChef.setStaticShare(uint128(staticShare));

        assertEq(masterChef.getStaticShare(), staticShare, "test_Fuzz_SetStaticPoolShares::19");
        assertEq(masterChef.getTotalStaticPoolShares(), sum, "test_Fuzz_SetStaticPoolShares::20");
        assertEq(masterChef.getStaticPoolIds().length, length, "test_Fuzz_SetStaticPoolShares::21");

        for (uint256 i; i < length; i++) {
            masterChef.setStaticPoolShare(i, 0);
            sum -= shares[i];

            assertEq(masterChef.getStaticPoolShare(i), 0, "test_Fuzz_SetStaticPoolShares::22");
            assertEq(masterChef.isStaticPool(i), false, "test_Fuzz_SetStaticPoolShares::23");
            assertEq(masterChef.getTotalStaticPoolShares(), sum, "test_Fuzz_SetStaticPoolShares::24");

            assertEq(masterChef.getStaticPoolIds().length, length - (i + 1), "test_Fuzz_SetStaticPoolShares::25");
            assertEq(masterChef.getMoePerSecondForPid(i), 0, "test_Fuzz_SetStaticPoolShares::26");
            if (i != length - 1) {
                assertEq(
                    masterChef.getMoePerSecondForPid(i + 1),
                    Constants.MAX_MOE_PER_SECOND * shares[i + 1] * staticShare / (sum * 1e18),
                    "test_Fuzz_SetStaticPoolShares::27"
                );
            }
        }
    }

    function test_Revert_SetStaticPoolShares() public {
        vm.expectRevert(IMasterChef.MasterChef__InvalidShares.selector);
        masterChef.setStaticShare(1e18 + 1);

        vm.expectRevert(abi.encodeWithSelector(IMasterChef.MasterChef__InvalidPoolId.selector, 2));
        masterChef.setStaticPoolShare(2, 0);

        veMoe.setTopPoolIds(new uint256[](1));

        vm.expectRevert(abi.encodeWithSelector(IMasterChef.MasterChef__TopPool.selector, 0));
        masterChef.setStaticPoolShare(0, 0);

        veMoe.setTopPoolIds(new uint256[](0));

        for (uint256 i; i < Constants.MAX_NUMBER_OF_FARMS; i++) {
            masterChef.add(tokenA, IMasterChefRewarder(address(0)));
            masterChef.setStaticPoolShare(i, 1e18);
        }

        vm.expectRevert(IMasterChef.MasterChef__TooManyStaticPools.selector);
        masterChef.setStaticPoolShare(Constants.MAX_NUMBER_OF_FARMS, 1e18);

        masterChef.setStaticPoolShare(0, 0);
        masterChef.setStaticPoolShare(1, 0);

        masterChef.setStaticPoolShare(
            Constants.MAX_NUMBER_OF_FARMS, uint128(Constants.MAX_STATIC_SHARES - masterChef.getTotalStaticPoolShares())
        );

        vm.expectRevert(IMasterChef.MasterChef__StaticPoolSharesOverflow.selector);
        masterChef.setStaticPoolShare(1, 1);
    }

    function test_SetStaticPoolShares() public {
        masterChef.add(tokenA, IMasterChefRewarder(address(0)));
        masterChef.add(tokenB, IMasterChefRewarder(address(0)));

        uint256[] memory pids = new uint256[](4);
        pids[0] = 0;
        pids[1] = 1;
        pids[2] = 2;
        pids[3] = 3;

        uint256[] memory topPids = new uint256[](2);
        topPids[0] = 0;
        topPids[1] = 1;

        {
            MockERC20(address(tokenA)).mint(alice, 4e18);
            MockERC20(address(tokenB)).mint(alice, 5e18);

            MockERC20(address(tokenA)).mint(bob, 6e18);
            MockERC20(address(tokenB)).mint(bob, 5e18);

            masterChef.setMoePerSecond(2e18);

            veMoe.setVotes(0, 4e18);
            veMoe.setVotes(1, 1e18);

            IVeMoe(address(veMoe)).setTopPoolIds(topPids);

            vm.startPrank(alice);
            masterChef.deposit(0, 1e18);
            masterChef.deposit(1, 2e18);
            masterChef.deposit(2, 4e18);
            masterChef.deposit(3, 5e18);
            vm.stopPrank();

            vm.startPrank(bob);
            masterChef.deposit(0, 9e18);
            masterChef.deposit(1, 8e18);
            masterChef.deposit(2, 6e18);
            masterChef.deposit(3, 5e18);
            vm.stopPrank();
        }

        vm.warp(block.timestamp + 10);

        assertEq(masterChef.getMoePerSecondForPid(0), 1.6e18, "test_SetStaticPoolShares::1");
        assertEq(masterChef.getMoePerSecondForPid(1), 0.4e18, "test_SetStaticPoolShares::2");
        assertEq(masterChef.getMoePerSecondForPid(2), 0, "test_SetStaticPoolShares::3");
        assertEq(masterChef.getMoePerSecondForPid(3), 0, "test_SetStaticPoolShares::4");

        vm.prank(alice);
        masterChef.claim(pids);

        vm.prank(bob);
        masterChef.claim(pids);

        assertApproxEqAbs(moe.balanceOf(address(alice)), 1.2e18, 2, "test_SetStaticPoolShares::5");
        assertApproxEqAbs(moe.balanceOf(address(bob)), 8.8e18, 2, "test_SetStaticPoolShares::6");
        assertEq(moe.balanceOf(address(this)), 10e18, "test_SetStaticPoolShares::7");

        vm.warp(block.timestamp + 10);

        // Set static share to 0.5, but no static pool shares, the rewards are effectively lost
        masterChef.setStaticShare(0.5e18);

        assertEq(masterChef.getMoePerSecondForPid(0), 0.8e18, "test_SetStaticPoolShares::8");
        assertEq(masterChef.getMoePerSecondForPid(1), 0.2e18, "test_SetStaticPoolShares::9");
        assertEq(masterChef.getMoePerSecondForPid(2), 0, "test_SetStaticPoolShares::10");
        assertEq(masterChef.getMoePerSecondForPid(3), 0, "test_SetStaticPoolShares::11");

        vm.warp(block.timestamp + 10);

        masterChef.setStaticPoolShare(2, 1e18);
        masterChef.setStaticPoolShare(3, 4e18);

        assertEq(masterChef.getMoePerSecondForPid(0), 0.8e18, "test_SetStaticPoolShares::12");
        assertEq(masterChef.getMoePerSecondForPid(1), 0.2e18, "test_SetStaticPoolShares::13");
        assertEq(masterChef.getMoePerSecondForPid(2), 0.2e18, "test_SetStaticPoolShares::14");
        assertEq(masterChef.getMoePerSecondForPid(3), 0.8e18, "test_SetStaticPoolShares::15");

        vm.warp(block.timestamp + 10);

        masterChef.getPendingRewards(alice, pids);

        vm.prank(alice);
        masterChef.claim(topPids);

        assertApproxEqAbs(
            moe.balanceOf(address(alice)), 1.2e18 + 1.2e18 + 1.2e18 / 2 + 1.2e18 / 2, 2, "test_SetStaticPoolShares::16"
        );
        assertEq(moe.balanceOf(address(this)), 30e18, "test_SetStaticPoolShares::17");

        (uint256[] memory moeRewardAlice,,) = masterChef.getPendingRewards(alice, pids);
        (uint256[] memory moeRewardBob,,) = masterChef.getPendingRewards(bob, pids);

        assertEq(moeRewardAlice.length, 4, "test_SetStaticPoolShares::18");
        assertEq(moeRewardAlice[0], 0, "test_SetStaticPoolShares::19");
        assertEq(moeRewardAlice[1], 0, "test_SetStaticPoolShares::20");
        assertApproxEqAbs(moeRewardAlice[2], 0.4e18, 1, "test_SetStaticPoolShares::21");
        assertApproxEqAbs(moeRewardAlice[3], 2e18, 1, "test_SetStaticPoolShares::22");

        assertEq(moeRewardBob.length, 4, "test_SetStaticPoolShares::23");
        assertApproxEqAbs(moeRewardBob[0], 7.2e18 + 7.2e18 / 2 + 7.2e18 / 2, 1, "test_SetStaticPoolShares::24");
        assertApproxEqAbs(moeRewardBob[1], 1.6e18 + 1.6e18 / 2 + 1.6e18 / 2, 1, "test_SetStaticPoolShares::25");
        assertApproxEqAbs(moeRewardBob[2], 0.6e18, 1, "test_SetStaticPoolShares::26");
        assertApproxEqAbs(moeRewardBob[3], 2e18, 1, "test_SetStaticPoolShares::27");

        vm.warp(block.timestamp + 10);

        vm.prank(alice);
        masterChef.claim(pids);

        vm.prank(bob);
        masterChef.claim(pids);

        vm.warp(block.timestamp + 10);

        (moeRewardAlice,,) = masterChef.getPendingRewards(alice, pids);
        (moeRewardBob,,) = masterChef.getPendingRewards(bob, pids);

        assertEq(moeRewardAlice.length, 4, "test_SetStaticPoolShares::28");
        assertEq(moeRewardAlice[0], 0.8e18 / 2, "test_SetStaticPoolShares::29");
        assertEq(moeRewardAlice[1], 0.4e18 / 2, "test_SetStaticPoolShares::30");
        assertEq(moeRewardAlice[2], 0.4e18, "test_SetStaticPoolShares::31");
        assertEq(moeRewardAlice[3], 2e18, "test_SetStaticPoolShares::32");

        assertEq(moeRewardBob.length, 4, "test_SetStaticPoolShares::33");
        assertEq(moeRewardBob[0], 7.2e18 / 2, "test_SetStaticPoolShares::34");
        assertEq(moeRewardBob[1], 1.6e18 / 2, "test_SetStaticPoolShares::35");
        assertEq(moeRewardBob[2], 0.6e18, "test_SetStaticPoolShares::36");
        assertEq(moeRewardBob[3], 2e18, "test_SetStaticPoolShares::37");

        masterChef.setStaticPoolShare(3, 0);
        topPids[0] = 0;
        topPids[1] = 3;

        veMoe.setTopPoolIds(topPids);
        veMoe.setVotes(0, 4e18);
        veMoe.setVotes(3, 4e18);

        masterChef.setStaticPoolShare(1, 1e18);
        masterChef.setStaticPoolShare(2, 1e18);

        assertEq(masterChef.getTotalStaticPoolShares(), 2e18, "test_SetStaticPoolShares::38");
        assertEq(veMoe.getTotalWeight(), 8e18, "test_SetStaticPoolShares::39");

        (moeRewardAlice,,) = masterChef.getPendingRewards(alice, pids);
        (moeRewardBob,,) = masterChef.getPendingRewards(bob, pids);

        assertEq(moeRewardAlice.length, 4, "test_SetStaticPoolShares::40");
        assertEq(moeRewardAlice[0], 0.8e18 / 2, "test_SetStaticPoolShares::41");
        assertEq(moeRewardAlice[1], 0.4e18 / 2, "test_SetStaticPoolShares::42");
        assertEq(moeRewardAlice[2], 0.4e18, "test_SetStaticPoolShares::43");
        assertEq(moeRewardAlice[3], 2e18, "test_SetStaticPoolShares::44");

        assertEq(moeRewardBob.length, 4, "test_SetStaticPoolShares::45");
        assertEq(moeRewardBob[0], 7.2e18 / 2, "test_SetStaticPoolShares::46");
        assertEq(moeRewardBob[1], 1.6e18 / 2, "test_SetStaticPoolShares::47");
        assertEq(moeRewardBob[2], 0.6e18, "test_SetStaticPoolShares::48");
        assertEq(moeRewardBob[3], 2e18, "test_SetStaticPoolShares::49");

        assertEq(masterChef.getMoePerSecondForPid(0), 0.5e18, "test_SetStaticPoolShares::50");
        assertEq(masterChef.getMoePerSecondForPid(1), 0.5e18, "test_SetStaticPoolShares::51");
        assertEq(masterChef.getMoePerSecondForPid(2), 0.5e18, "test_SetStaticPoolShares::52");
        assertEq(masterChef.getMoePerSecondForPid(3), 0.5e18, "test_SetStaticPoolShares::53");

        vm.warp(block.timestamp + 10);

        (moeRewardAlice,,) = masterChef.getPendingRewards(alice, pids);
        (moeRewardBob,,) = masterChef.getPendingRewards(bob, pids);

        assertEq(moeRewardAlice.length, 4, "test_SetStaticPoolShares::54");
        assertEq(moeRewardAlice[0], 0.8e18 / 2 + 0.5e18 / 2, "test_SetStaticPoolShares::55");
        assertEq(moeRewardAlice[1], 0.4e18 / 2 + 1e18 / 2, "test_SetStaticPoolShares::56");
        assertEq(moeRewardAlice[2], 0.4e18 + 2e18 / 2, "test_SetStaticPoolShares::57");
        assertEq(moeRewardAlice[3], 2e18 + 2.5e18 / 2, "test_SetStaticPoolShares::58");

        assertEq(moeRewardBob.length, 4, "test_SetStaticPoolShares::59");
        assertEq(moeRewardBob[0], 7.2e18 / 2 + 4.5e18 / 2, "test_SetStaticPoolShares::60");
        assertEq(moeRewardBob[1], 1.6e18 / 2 + 4e18 / 2, "test_SetStaticPoolShares::61");
        assertEq(moeRewardBob[2], 0.6e18 + 3e18 / 2, "test_SetStaticPoolShares::62");
        assertEq(moeRewardBob[3], 2e18 + 2.5e18 / 2, "test_SetStaticPoolShares::63");

        masterChef.setStaticShare(0);

        assertEq(masterChef.getMoePerSecondForPid(0), 1e18, "test_SetStaticPoolShares::64");
        assertEq(masterChef.getMoePerSecondForPid(1), 0, "test_SetStaticPoolShares::65");
        assertEq(masterChef.getMoePerSecondForPid(2), 0, "test_SetStaticPoolShares::66");
        assertEq(masterChef.getMoePerSecondForPid(3), 1e18, "test_SetStaticPoolShares::67");
    }
}

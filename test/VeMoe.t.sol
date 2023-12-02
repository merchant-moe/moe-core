// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/transparent/TransparentUpgradeableProxy2Step.sol";

import "../src/VeMoe.sol";
import "../src/MoeStaking.sol";
import "../src/Moe.sol";
import "../src/MasterChef.sol";
import "../src/rewarders/VeMoeRewarder.sol";
import "./mocks/MockNoRevert.sol";
import "./mocks/MockERC20.sol";

contract VeMoeTest is Test {
    MoeStaking staking;
    Moe moe;
    VeMoe veMoe;
    MasterChef masterChef;

    IERC20 token18d;
    IERC20 token6d;

    VeMoeRewarder bribes0;
    VeMoeRewarder bribes0Bis;
    VeMoeRewarder bribes1;

    address sMoe;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        moe = new Moe(address(this), 0, type(uint256).max);
        token18d = new MockERC20("18d", "18d", 18);
        token6d = new MockERC20("6d", "6d", 6);

        sMoe = address(new MockNoRevert());

        uint256 nonce = vm.getNonce(address(this));

        address stakingAddress = computeCreateAddress(address(this), nonce);
        address masterChefAddress = computeCreateAddress(address(this), nonce + 3);
        address veMoeAddress = computeCreateAddress(address(this), nonce + 4);

        staking = new MoeStaking(moe, IVeMoe(veMoeAddress), IStableMoe(sMoe));
        masterChef = new MasterChef(moe, IVeMoe(veMoeAddress), 0, 0, 0);
        veMoe = new VeMoe(IMoeStaking(stakingAddress), IMasterChef(masterChefAddress), 100e18);

        TransparentUpgradeableProxy2Step masterChefProxy = new TransparentUpgradeableProxy2Step(
            address(masterChef),
            ProxyAdmin2Step(address(1)),
            abi.encodeWithSelector(MasterChef.initialize.selector, address(this), address(this), address(this), address(this))
        );

        TransparentUpgradeableProxy2Step veMoeProxy = new TransparentUpgradeableProxy2Step(
            address(veMoe),
            ProxyAdmin2Step(address(1)),
            abi.encodeWithSelector(VeMoe.initialize.selector, address(this))    
        );

        veMoe = VeMoe(address(veMoeProxy));
        masterChef = MasterChef(address(masterChefProxy));

        bribes0 = new VeMoeRewarder(token18d, address(veMoe), 0, address(this));
        bribes0Bis = new VeMoeRewarder(token18d, address(veMoe), 0, address(this));
        bribes1 = new VeMoeRewarder(token6d, address(veMoe), 1, address(this));

        assertEq(address(masterChef.getVeMoe()), address(veMoe), "setUp::1");

        masterChef.add(token18d, IMasterChefRewarder(address(0)));
        masterChef.add(token6d, IMasterChefRewarder(address(0)));

        moe.mint(alice, 100e18);
        moe.mint(bob, 100e18);

        vm.prank(alice);
        moe.approve(address(staking), type(uint256).max);

        vm.prank(bob);
        moe.approve(address(staking), type(uint256).max);
    }

    function test_GetParameters() public {
        assertEq(address(veMoe.getMoeStaking()), address(staking), "test_GetParameters::1");
        assertEq(address(veMoe.getMasterChef()), address(masterChef), "test_GetParameters::2");
    }

    function test_SetVeMoePerSecondPerMoe() public {
        uint256 veMoePerSecondPerMoe = veMoe.getVeMoePerSecondPerMoe();

        assertEq(veMoePerSecondPerMoe, 0, "test_SetVeMoePerSecondPerMoe::1");

        veMoe.setVeMoePerSecondPerMoe(1);

        veMoePerSecondPerMoe = veMoe.getVeMoePerSecondPerMoe();

        assertEq(veMoePerSecondPerMoe, 1, "test_SetVeMoePerSecondPerMoe::2");

        veMoe.setVeMoePerSecondPerMoe(3);

        veMoePerSecondPerMoe = veMoe.getVeMoePerSecondPerMoe();

        assertEq(veMoePerSecondPerMoe, 3, "test_SetVeMoePerSecondPerMoe::3");

        veMoe.setVeMoePerSecondPerMoe(0);

        veMoePerSecondPerMoe = veMoe.getVeMoePerSecondPerMoe();

        assertEq(veMoePerSecondPerMoe, 0, "test_SetVeMoePerSecondPerMoe::4");
    }

    function test_OnModifyAndClaim() public {
        veMoe.setVeMoePerSecondPerMoe(1e18);

        vm.prank(alice);
        staking.stake(1e18);

        vm.prank(bob);
        staking.stake(9e18);

        assertEq(veMoe.balanceOf(alice), 0, "test_OnModifyAndClaim::1");
        assertEq(veMoe.balanceOf(bob), 0, "test_OnModifyAndClaim::2");

        vm.warp(block.timestamp + 50);

        assertEq(veMoe.balanceOf(alice), 50e18, "test_OnModifyAndClaim::3");
        assertEq(veMoe.balanceOf(bob), 450e18, "test_OnModifyAndClaim::4");

        vm.prank(alice);
        staking.claim();

        assertEq(veMoe.balanceOf(alice), 50e18, "test_OnModifyAndClaim::5");
        assertEq(veMoe.balanceOf(bob), 450e18, "test_OnModifyAndClaim::6");

        vm.warp(block.timestamp + 25);

        veMoe.setVeMoePerSecondPerMoe(1e18);

        assertEq(veMoe.balanceOf(alice), 75e18, "test_OnModifyAndClaim::7");
        assertEq(veMoe.balanceOf(bob), 675e18, "test_OnModifyAndClaim::8");

        vm.prank(bob);
        veMoe.claim(new uint256[](10));

        assertEq(veMoe.balanceOf(alice), 75e18, "test_OnModifyAndClaim::9");
        assertEq(veMoe.balanceOf(bob), 675e18, "test_OnModifyAndClaim::10");

        vm.warp(block.timestamp + 25);

        assertEq(veMoe.balanceOf(alice), 100e18, "test_OnModifyAndClaim::11");
        assertEq(veMoe.balanceOf(bob), 900e18, "test_OnModifyAndClaim::12");

        vm.warp(block.timestamp + 1);

        assertEq(veMoe.balanceOf(alice), 100e18, "test_OnModifyAndClaim::13");
        assertEq(veMoe.balanceOf(bob), 900e18, "test_OnModifyAndClaim::14");
    }

    function test_SetTopPoolIds() public {
        uint256[] memory pids = new uint256[](3);

        for (uint256 i; i < 8; ++i) {
            masterChef.add(token18d, IMasterChefRewarder(address(0)));
        }

        assertEq(masterChef.getNumberOfFarms(), 10, "test_SetTopPoolIds::1");

        pids[0] = 9;
        pids[1] = 7;
        pids[2] = 1;

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        veMoe.setTopPoolIds(pids);

        veMoe.setTopPoolIds(pids);

        uint256[] memory topPoolIds = veMoe.getTopPoolIds();

        assertEq(topPoolIds.length, 3, "test_SetTopPoolIds::2");
        assertEq(topPoolIds[0], 9, "test_SetTopPoolIds::3");
        assertEq(topPoolIds[1], 7, "test_SetTopPoolIds::4");
        assertEq(topPoolIds[2], 1, "test_SetTopPoolIds::5");

        assertTrue(veMoe.isInTopPoolIds(9), "test_SetTopPoolIds::6");
        assertTrue(veMoe.isInTopPoolIds(7), "test_SetTopPoolIds::7");
        assertTrue(veMoe.isInTopPoolIds(1), "test_SetTopPoolIds::8");
        assertFalse(veMoe.isInTopPoolIds(2), "test_SetTopPoolIds::9");

        pids[0] = 1;
        pids[1] = 2;
        pids[2] = 3;

        veMoe.setTopPoolIds(pids);

        topPoolIds = veMoe.getTopPoolIds();

        assertEq(topPoolIds.length, 3, "test_SetTopPoolIds::10");
        assertEq(topPoolIds[0], 1, "test_SetTopPoolIds::11");
        assertEq(topPoolIds[1], 2, "test_SetTopPoolIds::12");
        assertEq(topPoolIds[2], 3, "test_SetTopPoolIds::13");

        assertTrue(veMoe.isInTopPoolIds(1), "test_SetTopPoolIds::14");
        assertTrue(veMoe.isInTopPoolIds(2), "test_SetTopPoolIds::15");
        assertTrue(veMoe.isInTopPoolIds(3), "test_SetTopPoolIds::16");
        assertFalse(veMoe.isInTopPoolIds(7), "test_SetTopPoolIds::17");
        assertFalse(veMoe.isInTopPoolIds(9), "test_SetTopPoolIds::18");

        pids[0] = 1;
        pids[1] = 2;
        pids[2] = 1;

        vm.expectRevert(abi.encodeWithSelector(IVeMoe.VeMoe__DuplicatePoolId.selector, 1));
        veMoe.setTopPoolIds(pids);

        pids[0] = 10;

        vm.expectRevert();
        veMoe.setTopPoolIds(pids);

        for (uint256 i; i < Constants.MAX_NUMBER_OF_FARMS; ++i) {
            masterChef.add(token18d, IMasterChefRewarder(address(0)));
        }

        uint256[] memory topPids = new uint256[](Constants.MAX_NUMBER_OF_FARMS);

        for (uint256 i; i < topPids.length; ++i) {
            topPids[i] = i;
        }

        veMoe.setTopPoolIds(topPids);

        assertEq(veMoe.getTopPoolIds().length, Constants.MAX_NUMBER_OF_FARMS, "test_SetTopPoolIds::19");

        topPids = new uint256[](Constants.MAX_NUMBER_OF_FARMS + 1);

        vm.expectRevert(IVeMoe.VeMoe__TooManyPoolIds.selector);
        veMoe.setTopPoolIds(topPids);
    }

    function test_Vote() external {
        veMoe.setVeMoePerSecondPerMoe(1e18);

        vm.prank(alice);
        staking.stake(1e18);

        vm.prank(bob);
        staking.stake(9e18);

        vm.warp(block.timestamp + 50);

        uint256[] memory pids = new uint256[](2);

        pids[0] = 0;
        pids[1] = 1;

        int256[] memory deltaAmounts = new int256[](2);

        deltaAmounts[0] = 25e18;
        deltaAmounts[1] = 25e18 + 1;

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVeMoe.VeMoe__InsufficientVeMoe.selector, 50e18, 50e18 + 1));
        veMoe.vote(pids, deltaAmounts);

        deltaAmounts[1] = 25e18;

        vm.prank(alice);
        veMoe.vote(pids, deltaAmounts);

        assertEq(veMoe.getVotes(0), 25e18, "test_Vote::1");
        assertEq(veMoe.getVotes(1), 25e18, "test_Vote::2");
        assertEq(veMoe.getTotalVotes(), 50e18, "test_Vote::3");
        assertEq(veMoe.getVotesOf(alice, 0), 25e18, "test_Vote::4");
        assertEq(veMoe.getVotesOf(alice, 1), 25e18, "test_Vote::5");
        assertEq(veMoe.getTotalVotesOf(alice), 50e18, "test_Vote::6");

        deltaAmounts[0] = 0;
        deltaAmounts[1] = 1;

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVeMoe.VeMoe__InsufficientVeMoe.selector, 50e18, 50e18 + 1));
        veMoe.vote(pids, deltaAmounts);

        deltaAmounts[0] = 400e18;
        deltaAmounts[1] = 50e18;

        vm.prank(bob);
        veMoe.vote(pids, deltaAmounts);

        assertEq(veMoe.getVotes(0), 425e18, "test_Vote::7");
        assertEq(veMoe.getVotes(1), 75e18, "test_Vote::8");
        assertEq(veMoe.getTotalVotes(), 500e18, "test_Vote::9");
        assertEq(veMoe.getVotesOf(bob, 0), 400e18, "test_Vote::10");
        assertEq(veMoe.getVotesOf(bob, 1), 50e18, "test_Vote::11");
        assertEq(veMoe.getTotalVotesOf(bob), 450e18, "test_Vote::12");

        deltaAmounts[0] = -200e18;
        deltaAmounts[1] = -50e18;

        vm.prank(bob);
        veMoe.vote(pids, deltaAmounts);

        assertEq(veMoe.getVotes(0), 225e18, "test_Vote::13");
        assertEq(veMoe.getVotes(1), 25e18, "test_Vote::14");
        assertEq(veMoe.getTotalVotes(), 250e18, "test_Vote::15");
        assertEq(veMoe.getVotesOf(bob, 0), 200e18, "test_Vote::16");
        assertEq(veMoe.getVotesOf(bob, 1), 0, "test_Vote::17");
        assertEq(veMoe.getTotalVotesOf(bob), 200e18, "test_Vote::18");

        deltaAmounts[0] = -25e18;
        deltaAmounts[1] = -25e18;

        vm.prank(alice);
        veMoe.vote(pids, deltaAmounts);

        assertEq(veMoe.getVotes(0), 200e18, "test_Vote::19");
        assertEq(veMoe.getVotes(1), 0, "test_Vote::20");
        assertEq(veMoe.getTotalVotes(), 200e18, "test_Vote::21");
        assertEq(veMoe.getVotesOf(alice, 0), 0, "test_Vote::22");
        assertEq(veMoe.getVotesOf(alice, 1), 0, "test_Vote::23");
        assertEq(veMoe.getTotalVotesOf(alice), 0, "test_Vote::24");
    }

    function test_VoteOnTopPids() external {
        veMoe.setVeMoePerSecondPerMoe(1e18);

        vm.prank(alice);
        staking.stake(1e18);

        vm.prank(bob);
        staking.stake(9e18);

        vm.warp(block.timestamp + 50);

        uint256[] memory pids = new uint256[](2);

        pids[0] = 0;
        pids[1] = 1;

        int256[] memory deltaAmounts = new int256[](2);

        deltaAmounts[0] = 25e18;
        deltaAmounts[1] = 25e18;

        uint256[] memory topPids = new uint256[](1);

        vm.prank(alice);
        veMoe.vote(pids, deltaAmounts);

        veMoe.setTopPoolIds(topPids);

        assertEq(veMoe.getTopPidsTotalVotes(), 25e18, "test_VoteOnTopPids::1");
        assertEq(veMoe.getVotes(0), 25e18, "test_VoteOnTopPids::2");
        assertTrue(veMoe.isInTopPoolIds(0), "test_VoteOnTopPids::3");
        assertFalse(veMoe.isInTopPoolIds(1), "test_VoteOnTopPids::4");

        uint256[] memory topPoolIds = veMoe.getTopPoolIds();

        assertEq(topPoolIds.length, 1, "test_VoteOnTopPids::5");
        assertEq(topPoolIds[0], 0, "test_VoteOnTopPids::6");

        deltaAmounts[0] = 400e18;
        deltaAmounts[1] = 50e18;

        vm.prank(bob);
        veMoe.vote(pids, deltaAmounts);

        assertEq(veMoe.getTopPidsTotalVotes(), 425e18, "test_VoteOnTopPids::7");
        assertEq(veMoe.getVotes(0), 425e18, "test_VoteOnTopPids::8");
        assertTrue(veMoe.isInTopPoolIds(0), "test_VoteOnTopPids::9");
        assertFalse(veMoe.isInTopPoolIds(1), "test_VoteOnTopPids::10");

        deltaAmounts[0] = -200e18;
        deltaAmounts[1] = -50e18;

        vm.prank(bob);
        veMoe.vote(pids, deltaAmounts);

        assertEq(veMoe.getTopPidsTotalVotes(), 225e18, "test_VoteOnTopPids::11");
        assertEq(veMoe.getVotes(0), 225e18, "test_VoteOnTopPids::12");
        assertTrue(veMoe.isInTopPoolIds(0), "test_VoteOnTopPids::13");
        assertFalse(veMoe.isInTopPoolIds(1), "test_VoteOnTopPids::14");

        topPids[0] = 1;

        veMoe.setTopPoolIds(topPids);

        assertEq(veMoe.getTopPidsTotalVotes(), 25e18, "test_VoteOnTopPids::15");
        assertEq(veMoe.getVotes(0), 225e18, "test_VoteOnTopPids::16");
        assertEq(veMoe.getVotes(1), 25e18, "test_VoteOnTopPids::17");
        assertFalse(veMoe.isInTopPoolIds(0), "test_VoteOnTopPids::18");
        assertTrue(veMoe.isInTopPoolIds(1), "test_VoteOnTopPids::19");

        topPids = new uint256[](2);

        topPids[0] = 0;
        topPids[1] = 1;

        veMoe.setTopPoolIds(topPids);

        assertEq(veMoe.getTopPidsTotalVotes(), 250e18, "test_VoteOnTopPids::20");
        assertEq(veMoe.getVotes(0), 225e18, "test_VoteOnTopPids::21");
        assertEq(veMoe.getVotes(1), 25e18, "test_VoteOnTopPids::22");
        assertTrue(veMoe.isInTopPoolIds(0), "test_VoteOnTopPids::23");
        assertTrue(veMoe.isInTopPoolIds(1), "test_VoteOnTopPids::24");

        vm.warp(block.timestamp + 50);

        deltaAmounts[0] = 600e18;
        deltaAmounts[1] = 100e18;

        vm.prank(bob);
        veMoe.vote(pids, deltaAmounts);

        assertEq(veMoe.getTopPidsTotalVotes(), 950e18, "test_VoteOnTopPids::25");
        assertEq(veMoe.getVotes(0), 825e18, "test_VoteOnTopPids::26");
        assertEq(veMoe.getVotes(1), 125e18, "test_VoteOnTopPids::27");
        assertTrue(veMoe.isInTopPoolIds(0), "test_VoteOnTopPids::28");
        assertTrue(veMoe.isInTopPoolIds(1), "test_VoteOnTopPids::29");

        topPids = new uint256[](0);

        veMoe.setTopPoolIds(topPids);

        assertEq(veMoe.getTopPidsTotalVotes(), 0, "test_VoteOnTopPids::30");
        assertEq(veMoe.getVotes(0), 825e18, "test_VoteOnTopPids::31");
        assertEq(veMoe.getVotes(1), 125e18, "test_VoteOnTopPids::32");
        assertFalse(veMoe.isInTopPoolIds(0), "test_VoteOnTopPids::33");
        assertFalse(veMoe.isInTopPoolIds(1), "test_VoteOnTopPids::34");
    }

    function test_SetBribes() external {
        veMoe.setVeMoePerSecondPerMoe(1e18);

        vm.prank(alice);
        staking.stake(1e18);

        vm.prank(bob);
        staking.stake(9e18);

        vm.warp(block.timestamp + 50);

        uint256[] memory pids = new uint256[](2);

        pids[0] = 0;
        pids[1] = 1;

        int256[] memory deltaAmounts = new int256[](2);

        deltaAmounts[0] = 25e18;
        deltaAmounts[1] = 25e18;

        vm.prank(alice);
        veMoe.vote(pids, deltaAmounts);

        uint256[] memory topPids = new uint256[](1);
        veMoe.setTopPoolIds(topPids);

        uint256[] memory bribePid = new uint256[](1);
        IVeMoeRewarder[] memory bribes = new IVeMoeRewarder[](1);

        bribePid[0] = 0;
        bribes[0] = bribes0;

        vm.prank(alice);
        veMoe.setBribes(bribePid, bribes);

        assertEq(address(veMoe.getBribesOf(alice, 0)), address(bribes0), "test_SetBribes::1");
        assertEq(veMoe.getBribesTotalVotes(bribes0, 0), 25e18, "test_SetBribes::2");

        deltaAmounts[0] = 400e18;
        deltaAmounts[1] = 0;

        vm.prank(bob);
        veMoe.vote(pids, deltaAmounts);

        bribePid = new uint256[](2);
        bribes = new IVeMoeRewarder[](2);

        bribePid[0] = 0;
        bribePid[1] = 1;

        bribes[0] = bribes0;
        bribes[1] = bribes1;

        vm.prank(bob);
        veMoe.setBribes(bribePid, bribes);

        assertEq(address(veMoe.getBribesOf(alice, 0)), address(bribes0), "test_SetBribes::3");
        assertEq(address(veMoe.getBribesOf(bob, 0)), address(bribes0), "test_SetBribes::4");
        assertEq(address(veMoe.getBribesOf(bob, 1)), address(bribes1), "test_SetBribes::5");
        assertEq(veMoe.getBribesTotalVotes(bribes0, 0), 425e18, "test_SetBribes::6");
        assertEq(veMoe.getBribesTotalVotes(bribes1, 1), 0, "test_SetBribes::7");

        vm.prank(alice);
        veMoe.setBribes(bribePid, bribes);

        assertEq(address(veMoe.getBribesOf(alice, 0)), address(bribes0), "test_SetBribes::8");
        assertEq(address(veMoe.getBribesOf(alice, 1)), address(bribes1), "test_SetBribes::9");
        assertEq(address(veMoe.getBribesOf(bob, 0)), address(bribes0), "test_SetBribes::10");
        assertEq(address(veMoe.getBribesOf(bob, 1)), address(bribes1), "test_SetBribes::11");
        assertEq(veMoe.getBribesTotalVotes(bribes0, 0), 425e18, "test_SetBribes::12");
        assertEq(veMoe.getBribesTotalVotes(bribes1, 1), 25e18, "test_SetBribes::13");

        bribes[0] = bribes0Bis;
        bribes[1] = IVeMoeRewarder(address(0));

        vm.prank(alice);
        veMoe.setBribes(bribePid, bribes);

        assertEq(address(veMoe.getBribesOf(alice, 0)), address(bribes0Bis), "test_SetBribes::14");
        assertEq(address(veMoe.getBribesOf(alice, 1)), address(0), "test_SetBribes::15");
        assertEq(veMoe.getBribesTotalVotes(bribes0, 0), 400e18, "test_SetBribes::16");
        assertEq(veMoe.getBribesTotalVotes(bribes0Bis, 0), 25e18, "test_SetBribes::17");
        assertEq(veMoe.getBribesTotalVotes(bribes1, 1), 0, "test_SetBribes::18");

        deltaAmounts[0] = -200e18;
        deltaAmounts[1] = 25e18;

        vm.prank(bob);
        veMoe.vote(pids, deltaAmounts);

        assertEq(veMoe.getBribesTotalVotes(bribes0, 0), 200e18, "test_SetBribes::19");
        assertEq(veMoe.getBribesTotalVotes(bribes0Bis, 0), 25e18, "test_SetBribes::20");
        assertEq(veMoe.getBribesTotalVotes(bribes1, 1), 25e18, "test_SetBribes::21");
    }

    function test_EmergencyUnsetBribes() external {
        veMoe.setVeMoePerSecondPerMoe(1e18);

        vm.prank(alice);
        staking.stake(1e18);

        vm.prank(bob);
        staking.stake(9e18);

        vm.warp(block.timestamp + 50);

        uint256[] memory pids = new uint256[](2);

        pids[0] = 0;
        pids[1] = 1;

        int256[] memory deltaAmounts = new int256[](2);

        deltaAmounts[0] = 25e18;
        deltaAmounts[1] = 25e18;

        vm.prank(alice);
        veMoe.vote(pids, deltaAmounts);

        deltaAmounts[0] = 400e18;
        deltaAmounts[1] = 50e18;

        vm.prank(bob);
        veMoe.vote(pids, deltaAmounts);

        uint256[] memory topPids = new uint256[](1);
        veMoe.setTopPoolIds(topPids);

        BadBribes badBribes = new BadBribes();

        uint256[] memory bribePid = new uint256[](1);
        IVeMoeRewarder[] memory bribes = new IVeMoeRewarder[](1);

        bribePid[0] = 0;
        bribes[0] = IVeMoeRewarder(address(badBribes));

        vm.prank(alice);
        veMoe.setBribes(bribePid, bribes);

        vm.prank(bob);
        veMoe.setBribes(bribePid, bribes);

        badBribes.setShouldRevert(true);

        vm.expectRevert(IVeMoe.VeMoe__CannotUnstakeWithVotes.selector);
        vm.prank(alice);
        staking.unstake(1e18);

        bribes[0] = IVeMoeRewarder(address(0));

        vm.expectRevert();
        vm.prank(alice);
        veMoe.setBribes(bribePid, bribes);

        deltaAmounts[0] = -25e18;
        deltaAmounts[1] = -25e18;

        vm.expectRevert();
        vm.prank(alice);
        veMoe.vote(pids, deltaAmounts);

        vm.prank(alice);
        veMoe.emergencyUnsetBribes(bribePid);

        assertEq(address(veMoe.getBribesOf(alice, 0)), address(0), "test_EmergencyUnsetBribes::1");
        assertEq(veMoe.getVotesOf(alice, 0), 25e18, "test_EmergencyUnsetBribes::2");
        assertEq(
            veMoe.getBribesTotalVotes(IVeMoeRewarder(address(badBribes)), 0), 400e18, "test_EmergencyUnsetBribes::3"
        );

        vm.prank(alice);
        veMoe.vote(pids, deltaAmounts);

        vm.prank(alice);
        staking.unstake(1e18);
    }

    function test_ClaimBribesRewards() external {
        veMoe.setVeMoePerSecondPerMoe(1e18);

        vm.prank(alice);
        staking.stake(1e18);

        vm.prank(bob);
        staking.stake(9e18);

        vm.warp(block.timestamp + 50);

        uint256[] memory pids = new uint256[](2);

        pids[0] = 0;
        pids[1] = 1;

        int256[] memory deltaAmounts = new int256[](2);

        deltaAmounts[0] = 25e18;
        deltaAmounts[1] = 25e18;

        vm.prank(alice);
        veMoe.vote(pids, deltaAmounts);

        deltaAmounts[0] = 75e18;
        deltaAmounts[1] = 25e18;

        vm.prank(bob);
        veMoe.vote(pids, deltaAmounts);

        IVeMoeRewarder[] memory bribes = new IVeMoeRewarder[](2);

        bribes[0] = bribes0;
        bribes[1] = bribes1;

        vm.prank(alice);
        veMoe.setBribes(pids, bribes);

        assertEq(address(veMoe.getBribesOf(alice, 0)), address(bribes0), "test_ClaimBribesRewards::1");
        assertEq(address(veMoe.getBribesOf(alice, 1)), address(bribes1), "test_ClaimBribesRewards::2");
        assertEq(veMoe.getBribesTotalVotes(bribes0, 0), 25e18, "test_ClaimBribesRewards::3");
        assertEq(veMoe.getBribesTotalVotes(bribes1, 1), 25e18, "test_ClaimBribesRewards::4");

        vm.prank(bob);
        veMoe.setBribes(pids, bribes);

        assertEq(address(veMoe.getBribesOf(bob, 0)), address(bribes0), "test_ClaimBribesRewards::5");
        assertEq(address(veMoe.getBribesOf(bob, 1)), address(bribes1), "test_ClaimBribesRewards::6");
        assertEq(veMoe.getBribesTotalVotes(bribes0, 0), 100e18, "test_ClaimBribesRewards::7");
        assertEq(veMoe.getBribesTotalVotes(bribes1, 1), 50e18, "test_ClaimBribesRewards::8");

        MockERC20(address(token18d)).mint(address(bribes0), 100e18);
        MockERC20(address(token6d)).mint(address(bribes1), 100e6);

        bribes0.setRewardPerSecond(1e18, 100);
        bribes1.setRewardPerSecond(1e6, 100);

        vm.warp(block.timestamp + 50);

        (IERC20[] memory bribeTokens, uint256[] memory bribeRewards) = veMoe.getPendingRewards(alice, pids);

        assertEq(bribeTokens.length, 2, "test_ClaimBribesRewards::9");
        assertEq(address(bribeTokens[0]), address(token18d), "test_ClaimBribesRewards::10");
        assertEq(address(bribeTokens[1]), address(token6d), "test_ClaimBribesRewards::11");
        assertEq(bribeRewards.length, 2, "test_ClaimBribesRewards::12");
        assertApproxEqAbs(bribeRewards[0], 12.5e18, 1, "test_ClaimBribesRewards::13");
        assertApproxEqAbs(bribeRewards[1], 25e6, 1, "test_ClaimBribesRewards::14");

        vm.prank(alice);
        veMoe.claim(pids);

        assertEq(token18d.balanceOf(address(alice)), bribeRewards[0], "test_ClaimBribesRewards::15");
        assertEq(token6d.balanceOf(address(alice)), bribeRewards[1], "test_ClaimBribesRewards::16");

        (bribeTokens, bribeRewards) = veMoe.getPendingRewards(bob, pids);

        assertEq(bribeTokens.length, 2, "test_ClaimBribesRewards::17");
        assertEq(address(bribeTokens[0]), address(token18d), "test_ClaimBribesRewards::18");
        assertEq(address(bribeTokens[1]), address(token6d), "test_ClaimBribesRewards::19");
        assertEq(bribeRewards.length, 2, "test_ClaimBribesRewards::20");
        assertApproxEqAbs(bribeRewards[0], 37.5e18, 1, "test_ClaimBribesRewards::21");
        assertApproxEqAbs(bribeRewards[1], 25e6, 1, "test_ClaimBribesRewards::22");

        vm.prank(bob);
        veMoe.claim(pids);

        assertEq(token18d.balanceOf(address(bob)), bribeRewards[0], "test_ClaimBribesRewards::23");
        assertEq(token6d.balanceOf(address(bob)), bribeRewards[1], "test_ClaimBribesRewards::24");
    }

    function test_ReenterBribes() public {
        MaliciousBribe maliciousBribe = new MaliciousBribe(veMoe);
        moe.mint(address(maliciousBribe), 1e18);

        veMoe.setVeMoePerSecondPerMoe(1e18);

        MockERC20(address(token18d)).mint(address(bribes0), 100e18);
        bribes0.setRewardPerSecond(1e18, 100);

        vm.prank(alice);
        staking.stake(1e18);

        uint256[] memory pids = new uint256[](1);
        int256[] memory deltaAmounts = new int256[](1);
        IVeMoeRewarder[] memory bribes = new IVeMoeRewarder[](1);

        vm.startPrank(address(maliciousBribe));
        moe.approve(address(staking), type(uint256).max);
        staking.stake(1e18);

        vm.warp(block.timestamp + 50);

        pids[0] = 0;
        deltaAmounts[0] = 1e18;
        bribes[0] = IVeMoeRewarder(address(maliciousBribe));

        veMoe.vote(pids, deltaAmounts);
        veMoe.setBribes(pids, bribes);

        bribes[0] = bribes0;

        veMoe.setBribes(pids, bribes);

        vm.stopPrank();

        assertEq(token18d.balanceOf(address(maliciousBribe)), 0, "test_ReenterBribes::1");
        assertEq(token18d.balanceOf(address(bribes0)), 100e18, "test_ReenterBribes::2");
    }
}

contract MaliciousBribe {
    IVeMoe public veMoe;

    constructor(IVeMoe _veMoe) {
        veMoe = _veMoe;
    }

    function onModify(address, uint256 pid, uint256 oldBalance, uint256, uint256) external returns (uint256) {
        if (oldBalance == 0) return 0;

        uint256[] memory pids = new uint256[](1);
        IVeMoeRewarder[] memory bribes = new IVeMoeRewarder[](1);

        pids[0] = pid;
        bribes[0] = IVeMoeRewarder(address(this));

        veMoe.setBribes(pids, bribes);

        return 0;
    }
}

contract BadBribes {
    bool public shouldRevert;

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    fallback() external {
        if (shouldRevert) revert();
        assembly {
            mstore(0, 0)
            return(0, 32)
        }
    }
}

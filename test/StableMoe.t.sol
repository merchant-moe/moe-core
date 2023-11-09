// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../src/StableMoe.sol";
import "../src/MoeStaking.sol";
import "../src/Moe.sol";
import "./mocks/MockNoRevert.sol";
import "./mocks/MockERC20.sol";

contract StableMoeTest is Test {
    MoeStaking staking;
    Moe moe;
    StableMoe sMoe;

    address veMoe;

    IERC20 reward18d;
    IERC20 reward6d;
    IERC20 rewardNative;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        moe = new Moe(address(this), type(uint256).max);
        reward18d = new MockERC20("18d", "18d", 18);
        reward6d = new MockERC20("6d", "6d", 6);

        veMoe = address(new MockNoRevert());

        uint256 nonce = vm.getNonce(address(this));

        address stakingAddress = computeCreateAddress(address(this), nonce + 1);

        sMoe = new StableMoe(IMoeStaking(stakingAddress), address(this));
        staking = new MoeStaking(IERC20(moe), IVeMoe(veMoe), IStableMoe(sMoe));

        moe.mint(alice, 100e18);
        moe.mint(bob, 100e18);

        vm.prank(alice);
        moe.approve(address(staking), type(uint256).max);

        vm.prank(bob);
        moe.approve(address(staking), type(uint256).max);
    }

    function test_GetParameters() public {
        assertEq(address(sMoe.getMoeStaking()), address(staking), "test_GetParameters::1");
    }

    function test_AddReward() public {
        assertEq(sMoe.getNumberOfRewards(), 0, "test_AddReward::1");
        assertEq(sMoe.getActiveRewardTokens().length, 0, "test_AddReward::2");

        (IERC20[] memory tokens, uint256[] memory rewards) = sMoe.getPendingRewards(address(this));

        assertEq(tokens.length, 0, "test_AddReward::3");
        assertEq(rewards.length, 0, "test_AddReward::4");

        sMoe.addReward(reward18d);

        assertEq(sMoe.getNumberOfRewards(), 1, "test_AddReward::5");
        assertEq(sMoe.getActiveRewardTokens().length, 1, "test_AddReward::6");
        assertEq(address(sMoe.getRewardToken(0)), address(reward18d), "test_AddReward::7");
        assertEq(address(sMoe.getActiveRewardTokens()[0]), address(reward18d), "test_AddReward::8");

        sMoe.addReward(reward6d);

        assertEq(sMoe.getNumberOfRewards(), 2, "test_AddReward::9");
        assertEq(sMoe.getActiveRewardTokens().length, 2, "test_AddReward::10");
        assertEq(address(sMoe.getRewardToken(1)), address(reward6d), "test_AddReward::11");
        assertEq(address(sMoe.getActiveRewardTokens()[1]), address(reward6d), "test_AddReward::12");

        vm.expectRevert(abi.encodeWithSelector(IStableMoe.StableMoe__RewardAlreadyAdded.selector, reward18d));
        sMoe.addReward(reward18d);

        vm.expectRevert(abi.encodeWithSelector(IStableMoe.StableMoe__RewardAlreadyAdded.selector, reward6d));
        sMoe.addReward(reward6d);

        sMoe.removeReward(reward18d);

        assertEq(sMoe.getNumberOfRewards(), 2, "test_AddReward::13");
        assertEq(sMoe.getActiveRewardTokens().length, 1, "test_AddReward::14");
        assertEq(address(sMoe.getRewardToken(0)), address(reward18d), "test_AddReward::15");
        assertEq(address(sMoe.getRewardToken(1)), address(reward6d), "test_AddReward::16");
        assertEq(address(sMoe.getActiveRewardTokens()[0]), address(reward6d), "test_AddReward::17");

        vm.expectRevert(abi.encodeWithSelector(IStableMoe.StableMoe__RewardAlreadyAdded.selector, reward18d));
        sMoe.addReward(reward18d);

        vm.expectRevert(abi.encodeWithSelector(IStableMoe.StableMoe__RewardAlreadyRemoved.selector, reward18d));
        sMoe.removeReward(reward18d);

        vm.expectRevert(abi.encodeWithSelector(IStableMoe.StableMoe__RewardAlreadyRemoved.selector, address(1)));
        sMoe.removeReward(IERC20(address(1)));
    }

    function test_OnModifyAndClaim() public {
        sMoe.addReward(reward18d);
        sMoe.addReward(reward6d);
        sMoe.addReward(rewardNative);

        vm.prank(alice);
        staking.stake(1e18);

        vm.expectRevert(IStableMoe.StableMoe__UnauthorizedCaller.selector);
        sMoe.onModify(alice, 1, 1, 1, 1);

        vm.prank(bob);
        staking.stake(9e18);

        MockERC20(address(reward18d)).mint(address(sMoe), 100e18);
        MockERC20(address(reward6d)).mint(address(sMoe), 1e6);
        vm.deal(address(sMoe), 2e18);

        (IERC20[] memory aliceTokens, uint256[] memory aliceRewards) = sMoe.getPendingRewards(alice);

        assertEq(aliceTokens.length, 3, "test_OnModifyAndClaim::1");
        assertEq(address(aliceTokens[0]), address(reward18d), "test_OnModifyAndClaim::2");
        assertEq(address(aliceTokens[1]), address(reward6d), "test_OnModifyAndClaim::3");
        assertEq(address(aliceTokens[2]), address(rewardNative), "test_OnModifyAndClaim::4");

        assertEq(aliceRewards.length, 3, "test_OnModifyAndClaim::5");
        assertApproxEqAbs(aliceRewards[0], 10e18, 1, "test_OnModifyAndClaim::6");
        assertApproxEqAbs(aliceRewards[1], 0.1e6, 1, "test_OnModifyAndClaim::7");
        assertApproxEqAbs(aliceRewards[2], 0.2e18, 1, "test_OnModifyAndClaim::8");

        (IERC20[] memory bobTokens, uint256[] memory bobRewards) = sMoe.getPendingRewards(bob);

        assertEq(bobTokens.length, 3, "test_OnModifyAndClaim::9");
        assertEq(address(bobTokens[0]), address(reward18d), "test_OnModifyAndClaim::10");
        assertEq(address(bobTokens[1]), address(reward6d), "test_OnModifyAndClaim::11");
        assertEq(address(bobTokens[2]), address(rewardNative), "test_OnModifyAndClaim::12");

        assertEq(bobRewards.length, 3, "test_OnModifyAndClaim::13");
        assertApproxEqAbs(bobRewards[0], 90e18, 1, "test_OnModifyAndClaim::14");
        assertApproxEqAbs(bobRewards[1], 0.9e6, 1, "test_OnModifyAndClaim::15");
        assertApproxEqAbs(bobRewards[2], 1.8e18, 1, "test_OnModifyAndClaim::16");

        vm.prank(alice);
        staking.claim();

        assertApproxEqAbs(reward18d.balanceOf(alice), 10e18, 1, "test_OnModifyAndClaim::17");
        assertApproxEqAbs(reward6d.balanceOf(alice), 0.1e6, 1, "test_OnModifyAndClaim::18");
        assertApproxEqAbs(alice.balance, 0.2e18, 1, "test_OnModifyAndClaim::19");
        assertEq(aliceRewards[0], reward18d.balanceOf(alice), "test_OnModifyAndClaim::20");
        assertEq(aliceRewards[1], reward6d.balanceOf(alice), "test_OnModifyAndClaim::21");
        assertEq(aliceRewards[2], alice.balance, "test_OnModifyAndClaim::22");

        (aliceTokens, aliceRewards) = sMoe.getPendingRewards(alice);

        assertEq(aliceRewards[0], 0, "test_OnModifyAndClaim::23");
        assertEq(aliceRewards[1], 0, "test_OnModifyAndClaim::24");
        assertEq(aliceRewards[2], 0, "test_OnModifyAndClaim::25");

        MockERC20(address(reward18d)).mint(address(sMoe), 100e18);
        MockERC20(address(reward6d)).mint(address(sMoe), 1e6);

        (aliceTokens, aliceRewards) = sMoe.getPendingRewards(alice);

        assertApproxEqAbs(aliceRewards[0], 10e18, 1, "test_OnModifyAndClaim::26");
        assertApproxEqAbs(aliceRewards[1], 0.1e6, 1, "test_OnModifyAndClaim::27");
        assertEq(aliceRewards[2], 0, "test_OnModifyAndClaim::28");

        (bobTokens, bobRewards) = sMoe.getPendingRewards(bob);

        vm.prank(bob);
        sMoe.claim();

        assertApproxEqAbs(reward18d.balanceOf(bob), 180e18, 1, "test_OnModifyAndClaim::29");
        assertApproxEqAbs(reward6d.balanceOf(bob), 1.8e6, 1, "test_OnModifyAndClaim::30");
        assertApproxEqAbs(bob.balance, 1.8e18, 1, "test_OnModifyAndClaim::31");
        assertEq(bobRewards[0], reward18d.balanceOf(bob), "test_OnModifyAndClaim::32");
        assertEq(bobRewards[1], reward6d.balanceOf(bob), "test_OnModifyAndClaim::33");
        assertEq(bobRewards[2], bob.balance, "test_OnModifyAndClaim::34");

        vm.prank(alice);
        staking.stake(8e18);

        assertApproxEqAbs(reward18d.balanceOf(alice), 20e18, 1, "test_OnModifyAndClaim::35");
        assertApproxEqAbs(reward6d.balanceOf(alice), 0.2e6, 1, "test_OnModifyAndClaim::36");
        assertApproxEqAbs(alice.balance, 0.2e18, 1, "test_OnModifyAndClaim::37");

        MockERC20(address(reward18d)).mint(address(sMoe), 100e18);
        MockERC20(address(reward6d)).mint(address(sMoe), 1e6);
        vm.deal(address(sMoe), 2e18);

        sMoe.removeReward(reward18d);

        (aliceTokens, aliceRewards) = sMoe.getPendingRewards(alice);

        assertEq(aliceTokens.length, 2, "test_OnModifyAndClaim::38");
        assertEq(address(aliceTokens[0]), address(rewardNative), "test_OnModifyAndClaim::39");
        assertEq(address(aliceTokens[1]), address(reward6d), "test_OnModifyAndClaim::40");
        assertEq(aliceRewards.length, 2, "test_OnModifyAndClaim::41");
        assertApproxEqAbs(aliceRewards[0], 1e18, 1, "test_OnModifyAndClaim::42");
        assertApproxEqAbs(aliceRewards[1], 0.5e6, 1, "test_OnModifyAndClaim::43");

        sMoe.removeReward(reward6d);

        vm.prank(alice);
        sMoe.claim();

        assertApproxEqAbs(reward18d.balanceOf(alice), 20e18, 1, "test_OnModifyAndClaim::44");
        assertApproxEqAbs(reward6d.balanceOf(alice), 0.2e6, 1, "test_OnModifyAndClaim::45");
        assertApproxEqAbs(alice.balance, 1.2e18, 2, "test_OnModifyAndClaim::46");

        sMoe.removeReward(rewardNative);

        vm.prank(bob);
        staking.claim();

        assertApproxEqAbs(reward18d.balanceOf(bob), 180e18, 1, "test_OnModifyAndClaim::47");
        assertApproxEqAbs(reward6d.balanceOf(bob), 1.8e6, 1, "test_OnModifyAndClaim::48");
        assertApproxEqAbs(bob.balance, 1.8e18, 1, "test_OnModifyAndClaim::49");
    }

    function test_Sweep() public {
        MockERC20(address(reward18d)).mint(address(sMoe), 100e18);

        sMoe.sweep(reward18d, alice);

        assertEq(reward18d.balanceOf(alice), 100e18, "test_Sweep::1");

        sMoe.addReward(reward18d);

        vm.expectRevert(abi.encodeWithSelector(IStableMoe.StableMoe__ActiveReward.selector, reward18d));
        sMoe.sweep(reward18d, alice);

        sMoe.removeReward(reward18d);

        MockERC20(address(reward18d)).mint(address(sMoe), 100e18);

        sMoe.sweep(reward18d, bob);

        assertEq(reward18d.balanceOf(bob), 100e18, "test_Sweep::2");
    }
}

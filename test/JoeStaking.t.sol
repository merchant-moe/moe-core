// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "../src/transparent/TransparentUpgradeableProxy2Step.sol";

import "../src/JoeStaking.sol";
import "../src/rewarders/JoeStakingRewarder.sol";
import "../src/rewarders/BaseRewarder.sol";
import "../src/Moe.sol";

contract JoeStakingTest is Test {
    JoeStaking staking;
    JoeStakingRewarder rewarder;
    Moe moe;

    IERC20 joe;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        joe = new Moe(address(this), 0, type(uint256).max);
        moe = new Moe(address(this), 37_500_000e18, 500_000_000e18);

        uint256 nonce = vm.getNonce(address(this));

        address implAddress = computeCreateAddress(address(this), nonce + 2);

        rewarder = new JoeStakingRewarder(IERC20(address(moe)), implAddress, address(this));

        address impl = address(new JoeStaking(IERC20(address(joe)), IJoeStakingRewarder(address(rewarder))));

        staking = JoeStaking(address(new TransparentUpgradeableProxy2Step(impl, ProxyAdmin2Step(address(1)), "")));

        vm.prank(alice);
        joe.approve(address(staking), type(uint256).max);

        vm.prank(bob);
        joe.approve(address(staking), type(uint256).max);

        vm.label(address(joe), "joe");
        vm.label(address(moe), "moe");
        vm.label(address(rewarder), "rewarder");
        vm.label(address(staking), "staking");
    }

    function test_GetParameters() public {
        assertEq(staking.getJoe(), address(joe), "test_GetParameters::1");
        assertEq(staking.getRewarder(), address(rewarder), "test_GetParameters::2");

        assertEq(address(rewarder.getToken()), address(moe), "test_GetParameters::3");
        assertEq(rewarder.getCaller(), address(staking), "test_GetParameters::4");
        assertEq(rewarder.getPid(), 0, "test_GetParameters::5");
        assertEq(OwnableUpgradeable(address(rewarder)).owner(), address(this), "test_GetParameters::6");

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        rewarder.initialize(address(this));
    }

    function test_Stake() public {
        vm.prank(alice);
        joe.approve(address(staking), 0);

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(staking), 0, 1e18)
        );
        vm.prank(alice);
        staking.stake(1e18);

        vm.prank(alice);
        joe.approve(address(staking), 1e18);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 1e18));
        vm.prank(alice);
        staking.stake(1e18);

        Moe(address(joe)).mint(alice, 1e18);

        vm.prank(alice);
        staking.stake(1e18);

        assertEq(joe.balanceOf(address(staking)), 1e18, "test_Stake::1");
        assertEq(joe.balanceOf(alice), 0, "test_Stake::2");
        assertEq(staking.getDeposit(alice), 1e18, "test_Stake::3");
        assertEq(staking.getTotalDeposit(), 1e18, "test_Stake::4");

        Moe(address(joe)).mint(bob, 10e18);

        vm.prank(bob);
        staking.stake(9e18);

        assertEq(joe.balanceOf(address(staking)), 10e18, "test_Stake::5");
        assertEq(joe.balanceOf(bob), 1e18, "test_Stake::6");
        assertEq(staking.getDeposit(bob), 9e18, "test_Stake::7");
        assertEq(staking.getTotalDeposit(), 10e18, "test_Stake::8");
    }

    function test_Unstake() public {
        Moe(address(joe)).mint(alice, 1e18);
        Moe(address(joe)).mint(bob, 10e18);

        vm.prank(alice);
        staking.stake(1e18);

        vm.prank(bob);
        staking.stake(9e18);

        vm.prank(alice);
        staking.unstake(0.5e18);

        assertEq(joe.balanceOf(address(staking)), 9.5e18, "test_Unstake::1");
        assertEq(joe.balanceOf(alice), 0.5e18, "test_Unstake::2");
        assertEq(staking.getDeposit(alice), 0.5e18, "test_Unstake::3");
        assertEq(staking.getTotalDeposit(), 9.5e18, "test_Unstake::4");

        vm.prank(bob);
        staking.unstake(9e18);

        assertEq(joe.balanceOf(address(staking)), 0.5e18, "test_Unstake::5");
        assertEq(joe.balanceOf(bob), 10e18, "test_Unstake::6");
        assertEq(staking.getDeposit(bob), 0, "test_Unstake::7");
        assertEq(staking.getTotalDeposit(), 0.5e18, "test_Unstake::8");

        vm.prank(alice);
        staking.unstake(0.5e18);

        assertEq(joe.balanceOf(address(staking)), 0, "test_Unstake::9");
        assertEq(joe.balanceOf(alice), 1e18, "test_Unstake::10");
        assertEq(staking.getDeposit(alice), 0, "test_Unstake::11");
        assertEq(staking.getTotalDeposit(), 0, "test_Unstake::12");

        vm.expectRevert(Math.Math__UnderOverflow.selector);
        vm.prank(bob);
        staking.unstake(1);
    }

    function test_Claim() public {
        Moe(address(joe)).mint(alice, 1e18);
        Moe(address(joe)).mint(bob, 10e18);

        vm.prank(alice);
        staking.stake(1e18);

        vm.prank(bob);
        staking.stake(9e18);

        (IERC20 token, uint256 amount) = staking.getPendingReward(alice);

        assertEq(address(token), address(moe), "test_Claim::1");
        assertEq(amount, 0, "test_Claim::2");

        vm.prank(alice);
        staking.claim();

        assertEq(moe.balanceOf(address(alice)), 0, "test_Claim::1");

        moe.mint(address(rewarder), 10e18);

        rewarder.setRewarderParameters(1e18, block.timestamp, 10);

        vm.warp(block.timestamp + 2);

        (token, amount) = staking.getPendingReward(alice);

        assertEq(address(token), address(moe), "test_Claim::3");
        assertApproxEqAbs(amount, 0.2e18, 1, "test_Claim::4");

        vm.prank(alice);
        staking.claim();

        assertApproxEqAbs(moe.balanceOf(address(alice)), 0.2e18, 1, "test_Claim::5");

        (token, amount) = staking.getPendingReward(bob);

        assertEq(address(token), address(moe), "test_Claim::6");
        assertApproxEqAbs(amount, 1.8e18, 1, "test_Claim::7");

        vm.warp(block.timestamp + 10);

        (token, amount) = staking.getPendingReward(alice);

        assertEq(address(token), address(moe), "test_Claim::9");
        assertApproxEqAbs(amount, 0.8e18, 1, "test_Claim::10");

        vm.prank(alice);
        staking.claim();

        assertApproxEqAbs(moe.balanceOf(address(alice)), 1e18, 1, "test_Claim::11");

        (token, amount) = staking.getPendingReward(bob);

        assertEq(address(token), address(moe), "test_Claim::12");
        assertApproxEqAbs(amount, 9e18, 1, "test_Claim::13");

        vm.prank(bob);
        staking.claim();

        assertApproxEqAbs(moe.balanceOf(address(bob)), 9e18, 1, "test_Claim::14");
    }

    function test_Aidrop() public {
        uint256 airdropTime = block.timestamp + 100;
        uint256 airdropAmount = 12_500_000e18;
        uint256 rewardAmount = 25_000_000e18;

        Moe(address(joe)).mint(alice, 1e18);
        Moe(address(joe)).mint(bob, 10e18);

        vm.prank(alice);
        staking.stake(1e18);

        vm.prank(bob);
        staking.stake(9e18);

        moe.transfer(address(rewarder), airdropAmount + rewardAmount);

        rewarder.setRewarderParameters(airdropAmount, airdropTime, 1);

        (IERC20 token, uint256 amount) = staking.getPendingReward(alice);

        assertEq(address(token), address(moe), "test_Aidrop::1");
        assertEq(amount, 0, "test_Aidrop::2");

        vm.warp(airdropTime);

        (token, amount) = staking.getPendingReward(alice);

        assertEq(address(token), address(moe), "test_Aidrop::3");
        assertEq(amount, 0, "test_Aidrop::4");

        vm.warp(airdropTime + 1);

        (token, amount) = staking.getPendingReward(alice);

        assertEq(address(token), address(moe), "test_Aidrop::5");
        assertApproxEqAbs(amount, airdropAmount / 10, 1, "test_Aidrop::6");

        vm.warp(airdropTime + 10);

        (token, amount) = staking.getPendingReward(alice);

        assertEq(address(token), address(moe), "test_Aidrop::7");
        assertApproxEqAbs(amount, airdropAmount / 10, 1, "test_Aidrop::8");

        vm.prank(alice);
        staking.claim();

        assertApproxEqAbs(moe.balanceOf(address(alice)), airdropAmount / 10, 1, "test_Aidrop::9");

        rewarder.setRewarderParameters(rewardAmount / 100, block.timestamp, 100);

        vm.warp(block.timestamp + 50);

        (token, amount) = staking.getPendingReward(alice);

        assertEq(address(token), address(moe), "test_Aidrop::10");
        assertApproxEqAbs(amount, rewardAmount / 20, 1, "test_Aidrop::11");

        (token, amount) = staking.getPendingReward(bob);

        assertEq(address(token), address(moe), "test_Aidrop::12");
        assertApproxEqAbs(amount, airdropAmount * 9 / 10 + rewardAmount * 9 / 20, 1, "test_Aidrop::13");

        vm.warp(block.timestamp + 100);

        (token, amount) = staking.getPendingReward(alice);

        assertEq(address(token), address(moe), "test_Aidrop::14");
        assertApproxEqAbs(amount, rewardAmount / 10, 1, "test_Aidrop::15");

        (token, amount) = staking.getPendingReward(bob);

        assertEq(address(token), address(moe), "test_Aidrop::16");
        assertApproxEqAbs(amount, airdropAmount * 9 / 10 + rewardAmount * 9 / 10, 1, "test_Aidrop::17");

        vm.prank(alice);
        staking.claim();

        assertApproxEqAbs(moe.balanceOf(address(alice)), airdropAmount / 10 + rewardAmount / 10, 1, "test_Aidrop::18");

        vm.prank(bob);
        staking.claim();

        assertApproxEqAbs(
            moe.balanceOf(address(bob)), airdropAmount * 9 / 10 + rewardAmount * 9 / 10, 1, "test_Aidrop::19"
        );
    }
}

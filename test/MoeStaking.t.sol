// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../src/MoeStaking.sol";
import "../src/Moe.sol";
import "./mocks/MockNoRevert.sol";

contract MoeStakingTest is Test {
    MoeStaking staking;
    Moe moe;

    address veMoe;
    address sMoe;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        moe = new Moe(address(this), type(uint256).max);

        veMoe = address(new MockNoRevert());
        sMoe = address(new MockNoRevert());

        staking = new MoeStaking(IERC20(moe), IVeMoe(veMoe), IStableMoe(sMoe));
    }

    function test_GetParameters() public {
        assertEq(staking.getMoe(), address(moe), "test_GetParameters::1");
        assertEq(staking.getVeMoe(), veMoe, "test_GetParameters::2");
        assertEq(staking.getSMoe(), sMoe, "test_GetParameters::3");
    }

    function test_Stake() public {
        moe.mint(alice, 1e18);

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(staking), 0, 1e18)
        );
        vm.prank(alice);
        staking.stake(1e18);

        vm.startPrank(alice);
        moe.approve(address(staking), 1e18);
        staking.stake(1e18);
        vm.stopPrank();

        assertEq(moe.balanceOf(address(staking)), 1e18, "test_Stake::1");
        assertEq(moe.balanceOf(alice), 0, "test_Stake::2");
        assertEq(staking.getDeposit(alice), 1e18, "test_Stake::3");
        assertEq(staking.getTotalDeposit(), 1e18, "test_Stake::4");
        assertTrue(
            _isEq(
                MockNoRevert(veMoe).getCallData(),
                MockNoRevert(sMoe).getCallData(),
                abi.encodeWithSelector(IVeMoe.onModify.selector, alice, 0, 1e18, 0, 1e18)
            ),
            "test_Stake::5"
        );

        moe.mint(bob, 10e18);

        vm.startPrank(bob);
        moe.approve(address(staking), type(uint256).max);

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(bob), 10e18, 10e18 + 1)
        );
        staking.stake(10e18 + 1);

        staking.stake(9e18);
        vm.stopPrank();

        assertEq(moe.balanceOf(address(staking)), 10e18, "test_Stake::6");
        assertEq(moe.balanceOf(bob), 1e18, "test_Stake::7");
        assertEq(staking.getDeposit(bob), 9e18, "test_Stake::8");
        assertEq(staking.getTotalDeposit(), 10e18, "test_Stake::9");
        assertTrue(
            _isEq(
                MockNoRevert(veMoe).getCallData(),
                MockNoRevert(sMoe).getCallData(),
                abi.encodeWithSelector(IVeMoe.onModify.selector, bob, 0, 9e18, 1e18, 10e18)
            ),
            "test_Stake::10"
        );

        vm.prank(bob);
        staking.stake(1e18);

        assertEq(moe.balanceOf(address(staking)), 11e18, "test_Stake::11");
        assertEq(moe.balanceOf(bob), 0, "test_Stake::12");
        assertEq(staking.getDeposit(bob), 10e18, "test_Stake::13");
        assertEq(staking.getTotalDeposit(), 11e18, "test_Stake::14");
        assertTrue(
            _isEq(
                MockNoRevert(veMoe).getCallData(),
                MockNoRevert(sMoe).getCallData(),
                abi.encodeWithSelector(IVeMoe.onModify.selector, bob, 9e18, 10e18, 10e18, 11e18)
            ),
            "test_Stake::15"
        );

        moe.mint(address(staking), 1e18);

        assertEq(moe.balanceOf(address(staking)), 12e18, "test_Stake::16");
        assertEq(moe.balanceOf(bob), 0, "test_Stake::17");
        assertEq(staking.getDeposit(bob), 10e18, "test_Stake::18");
        assertEq(staking.getTotalDeposit(), 11e18, "test_Stake::19");

        vm.prank(bob);
        staking.claim();

        assertEq(moe.balanceOf(address(staking)), 12e18, "test_Stake::20");
        assertEq(moe.balanceOf(bob), 0, "test_Stake::21");
        assertEq(staking.getDeposit(bob), 10e18, "test_Stake::22");
        assertEq(staking.getTotalDeposit(), 11e18, "test_Stake::23");
        assertTrue(
            _isEq(
                MockNoRevert(veMoe).getCallData(),
                MockNoRevert(sMoe).getCallData(),
                abi.encodeWithSelector(IVeMoe.onModify.selector, bob, 10e18, 10e18, 11e18, 11e18)
            ),
            "test_Stake::24"
        );
    }

    function test_Unstake() public {
        moe.mint(alice, 1e18);
        moe.mint(bob, 10e18);

        vm.startPrank(alice);
        moe.approve(address(staking), 1e18);
        staking.stake(1e18);
        vm.stopPrank();

        vm.startPrank(bob);
        moe.approve(address(staking), type(uint256).max);
        staking.stake(9e18);
        vm.stopPrank();

        vm.prank(bob);
        staking.unstake(1e18);

        assertEq(moe.balanceOf(address(staking)), 9e18, "test_Unstake::1");
        assertEq(moe.balanceOf(bob), 2e18, "test_Unstake::2");
        assertEq(staking.getDeposit(bob), 8e18, "test_Unstake::3");
        assertEq(staking.getTotalDeposit(), 9e18, "test_Unstake::4");
        assertTrue(
            _isEq(
                MockNoRevert(veMoe).getCallData(),
                MockNoRevert(sMoe).getCallData(),
                abi.encodeWithSelector(IVeMoe.onModify.selector, bob, 9e18, 8e18, 10e18, 9e18)
            ),
            "test_Unstake::5"
        );

        vm.prank(alice);
        staking.unstake(1e18);

        assertEq(moe.balanceOf(address(staking)), 8e18, "test_Unstake::6");
        assertEq(moe.balanceOf(alice), 1e18, "test_Unstake::7");
        assertEq(staking.getDeposit(alice), 0, "test_Unstake::8");
        assertEq(staking.getTotalDeposit(), 8e18, "test_Unstake::9");
        assertTrue(
            _isEq(
                MockNoRevert(veMoe).getCallData(),
                MockNoRevert(sMoe).getCallData(),
                abi.encodeWithSelector(IVeMoe.onModify.selector, alice, 1e18, 0, 9e18, 8e18)
            ),
            "test_Unstake::10"
        );

        vm.expectRevert(Math.Math__UnderOverflow.selector);
        vm.prank(alice);
        staking.unstake(1);

        vm.prank(bob);
        staking.unstake(8e18);

        assertEq(moe.balanceOf(address(staking)), 0, "test_Unstake::11");
        assertEq(moe.balanceOf(bob), 10e18, "test_Unstake::12");
        assertEq(staking.getDeposit(bob), 0, "test_Unstake::13");
        assertEq(staking.getTotalDeposit(), 0, "test_Unstake::14");
        assertTrue(
            _isEq(
                MockNoRevert(veMoe).getCallData(),
                MockNoRevert(sMoe).getCallData(),
                abi.encodeWithSelector(IVeMoe.onModify.selector, bob, 8e18, 0, 8e18, 0)
            ),
            "test_Unstake::15"
        );

        vm.prank(bob);
        staking.claim();

        assertEq(moe.balanceOf(address(staking)), 0, "test_Unstake::16");
        assertEq(moe.balanceOf(bob), 10e18, "test_Unstake::17");
        assertEq(staking.getDeposit(bob), 0, "test_Unstake::18");
        assertEq(staking.getTotalDeposit(), 0, "test_Unstake::19");
        assertTrue(
            _isEq(
                MockNoRevert(veMoe).getCallData(),
                MockNoRevert(sMoe).getCallData(),
                abi.encodeWithSelector(IVeMoe.onModify.selector, bob, 0, 0, 0, 0)
            ),
            "test_Unstake::20"
        );
    }

    function _isEq(bytes memory data0, bytes memory data1, bytes memory data2) private pure returns (bool) {
        return keccak256(data0) == keccak256(data1) && keccak256(data1) == keccak256(data2);
    }
}

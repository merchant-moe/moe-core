// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/VestingWallet.sol";
import "./mocks/MockERC20.sol";

contract VestingWalletTest is Test {
    VestingWallet wallet;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    IERC20 token;

    function setUp() public {
        token = new MockERC20("token", "TKN", 18);

        wallet = new VestingWallet(address(this), token, block.timestamp+ 365 days, 365 days);
    }

    function owner() public view returns (address) {
        return address(this);
    }

    function test_Initialize() public {
        assertEq(wallet.masterChef(), address(this), "test_Initialize::1");
        assertEq(address(wallet.token()), address(token), "test_Initialize::2");
        assertEq(wallet.start(), block.timestamp + 365 days, "test_Initialize::3");
        assertEq(wallet.duration(), 365 days, "test_Initialize::4");
        assertEq(wallet.end(), block.timestamp + 2 * 365 days, "test_Initialize::5");
        assertEq(wallet.beneficiary(), address(0), "test_Initialize::6");
        assertEq(wallet.released(), 0, "test_Initialize::7");
        assertEq(wallet.releasable(), 0, "test_Initialize::8");
        assertEq(wallet.vestedAmount(block.timestamp), 0, "test_Initialize::9");
    }

    function test_SetBeneficiary() public {
        assertEq(wallet.beneficiary(), address(0), "test_SetBeneficiary::1");

        wallet.setBeneficiary(alice);

        assertEq(wallet.beneficiary(), alice, "test_SetBeneficiary::2");

        vm.prank(alice);
        vm.expectRevert(IVestingWallet.VestingWallet__NotMasterChefOwner.selector);
        wallet.setBeneficiary(bob);
    }

    function test_Release() public {
        MockERC20(address(token)).mint(address(wallet), 365e18);
        wallet.setBeneficiary(alice);

        vm.warp(block.timestamp + 365 days - 1);

        assertEq(wallet.releasable(), 0, "test_Release::1");

        vm.expectRevert(IVestingWallet.VestingWallet__NotBeneficiary.selector);
        wallet.release();

        vm.prank(alice);
        wallet.release();

        assertEq(wallet.released(), 0, "test_Release::2");
        assertEq(wallet.releasable(), 0, "test_Release::3");
        assertEq(token.balanceOf(alice), 0, "test_Release::4");
        assertEq(token.balanceOf(address(wallet)), 365e18, "test_Release::5");

        vm.warp(block.timestamp + 1);

        assertEq(wallet.releasable(), 0, "test_Release::6");

        vm.prank(alice);
        wallet.release();

        assertEq(wallet.released(), 0, "test_Release::7");
        assertEq(wallet.releasable(), 0, "test_Release::8");
        assertEq(token.balanceOf(alice), 0, "test_Release::9");
        assertEq(token.balanceOf(address(wallet)), 365e18, "test_Release::10");

        vm.warp(block.timestamp + 1 days);

        assertEq(wallet.releasable(), 1e18, "test_Release::11");

        vm.prank(alice);
        wallet.release();

        assertEq(wallet.released(), 1e18, "test_Release::12");
        assertEq(wallet.releasable(), 0, "test_Release::13");
        assertEq(token.balanceOf(alice), 1e18, "test_Release::14");
        assertEq(token.balanceOf(address(wallet)), 364e18, "test_Release::15");

        vm.warp(block.timestamp + 364 days);

        assertEq(wallet.releasable(), 364e18, "test_Release::16");

        vm.prank(alice);
        wallet.release();

        assertEq(wallet.released(), 365e18, "test_Release::17");
        assertEq(wallet.releasable(), 0, "test_Release::18");
        assertEq(token.balanceOf(alice), 365e18, "test_Release::19");
        assertEq(token.balanceOf(address(wallet)), 0, "test_Release::20");

        vm.warp(block.timestamp + 1 days);

        assertEq(wallet.releasable(), 0, "test_Release::21");

        vm.prank(alice);
        wallet.release();

        assertEq(wallet.released(), 365e18, "test_Release::22");
        assertEq(wallet.releasable(), 0, "test_Release::23");
        assertEq(token.balanceOf(alice), 365e18, "test_Release::24");
        assertEq(token.balanceOf(address(wallet)), 0, "test_Release::25");

        MockERC20(address(token)).mint(address(wallet), 365e18);

        assertEq(wallet.releasable(), 365e18, "test_Release::26");

        vm.prank(alice);
        wallet.release();

        assertEq(wallet.released(), 730e18, "test_Release::27");
        assertEq(wallet.releasable(), 0, "test_Release::28");
        assertEq(token.balanceOf(alice), 730e18, "test_Release::29");
        assertEq(token.balanceOf(address(wallet)), 0, "test_Release::30");
    }

    function test_ReleaseMoreTokenInMiddle() public {
        MockERC20(address(token)).mint(address(wallet), 365e18);
        wallet.setBeneficiary(alice);

        vm.warp(block.timestamp + 365 days + (365 days / 2));

        assertEq(wallet.releasable(), 365e18 / 2, "test_ReleaseMoreTokenInMiddle::1");

        vm.prank(alice);
        wallet.release();

        MockERC20(address(token)).mint(address(wallet), 365e18);

        assertEq(wallet.releasable(), 365e18 / 2, "test_ReleaseMoreTokenInMiddle::2");

        vm.prank(alice);
        wallet.release();

        assertEq(wallet.released(), 365e18, "test_ReleaseMoreTokenInMiddle::3");
        assertEq(wallet.releasable(), 0, "test_ReleaseMoreTokenInMiddle::4");
        assertEq(token.balanceOf(alice), 365e18, "test_ReleaseMoreTokenInMiddle::5");
        assertEq(token.balanceOf(address(wallet)), 365e18, "test_ReleaseMoreTokenInMiddle::6");

        vm.warp(block.timestamp + 365 days + (365 days / 2));

        assertEq(wallet.releasable(), 365e18, "test_ReleaseMoreTokenInMiddle::7");

        vm.prank(alice);
        wallet.release();

        assertEq(wallet.released(), 730e18, "test_ReleaseMoreTokenInMiddle::8");
        assertEq(wallet.releasable(), 0, "test_ReleaseMoreTokenInMiddle::9");
        assertEq(token.balanceOf(alice), 730e18, "test_ReleaseMoreTokenInMiddle::10");
        assertEq(token.balanceOf(address(wallet)), 0, "test_ReleaseMoreTokenInMiddle::11");
    }
}

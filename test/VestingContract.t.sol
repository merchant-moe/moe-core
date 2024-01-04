// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/VestingContract.sol";
import "./mocks/MockERC20.sol";

contract VestingContractTest is Test {
    VestingContract vesting;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    IERC20 token;

    uint256 start = block.timestamp + 365 days;
    uint256 cliffDuration = 10 days;
    uint256 vestingDuration = 100 days;

    uint256 total = 100e18;

    function setUp() public {
        token = new MockERC20("token", "TKN", 18);

        vesting = new VestingContract(address(this), token, start, cliffDuration, vestingDuration);
    }

    function owner() public view returns (address) {
        return address(this);
    }

    function test_Initialize() public {
        assertEq(vesting.masterChef(), address(this), "test_Initialize::1");
        assertEq(address(vesting.token()), address(token), "test_Initialize::2");
        assertEq(vesting.start(), start, "test_Initialize::3");
        assertEq(vesting.cliffDuration(), cliffDuration, "test_Initialize::4");
        assertEq(vesting.vestingDuration(), vestingDuration, "test_Initialize::5");
        assertEq(vesting.end(), start + vestingDuration, "test_Initialize::6");
        assertEq(vesting.beneficiary(), address(0), "test_Initialize::7");
        assertEq(vesting.released(), 0, "test_Initialize::8");
        assertEq(vesting.releasable(), 0, "test_Initialize::9");
        assertEq(vesting.vestedAmount(block.timestamp), 0, "test_Initialize::10");
    }

    function test_SetBeneficiary() public {
        assertEq(vesting.beneficiary(), address(0), "test_SetBeneficiary::1");

        vesting.setBeneficiary(alice);

        assertEq(vesting.beneficiary(), alice, "test_SetBeneficiary::2");

        vm.prank(alice);
        vm.expectRevert(IVestingContract.VestingContract__NotMasterChefOwner.selector);
        vesting.setBeneficiary(bob);
    }

    function test_Release() public {
        MockERC20(address(token)).mint(address(vesting), total);
        vesting.setBeneficiary(alice);

        vm.warp(start - 1);

        assertEq(vesting.releasable(), 0, "test_Release::1");

        vm.expectRevert(IVestingContract.VestingContract__NotBeneficiary.selector);
        vesting.release();

        vm.prank(alice);
        vesting.release();

        assertEq(vesting.released(), 0, "test_Release::2");
        assertEq(vesting.releasable(), 0, "test_Release::3");
        assertEq(token.balanceOf(alice), 0, "test_Release::4");
        assertEq(token.balanceOf(address(vesting)), total, "test_Release::5");

        vm.warp(start);

        assertEq(vesting.releasable(), 0, "test_Release::6");

        vm.prank(alice);
        vesting.release();

        assertEq(vesting.released(), 0, "test_Release::7");
        assertEq(vesting.releasable(), 0, "test_Release::8");
        assertEq(token.balanceOf(alice), 0, "test_Release::9");
        assertEq(token.balanceOf(address(vesting)), total, "test_Release::10");

        vm.warp(start + cliffDuration);

        assertEq(vesting.releasable(), 0, "test_Release::11");

        vm.prank(alice);
        vesting.release();

        assertEq(vesting.released(), 0, "test_Release::12");
        assertEq(vesting.releasable(), 0, "test_Release::13");
        assertEq(token.balanceOf(alice), 0, "test_Release::14");
        assertEq(token.balanceOf(address(vesting)), total, "test_Release::15");

        vm.warp(start + cliffDuration + 1);

        uint256 expectedReleasable = (cliffDuration + 1) * total / vestingDuration;

        assertEq(vesting.releasable(), expectedReleasable, "test_Release::16");

        vm.prank(alice);
        vesting.release();

        assertEq(vesting.released(), expectedReleasable, "test_Release::17");
        assertEq(vesting.releasable(), 0, "test_Release::18");
        assertEq(token.balanceOf(alice), expectedReleasable, "test_Release::19");
        assertEq(token.balanceOf(address(vesting)), total - expectedReleasable, "test_Release::20");

        vm.warp(start + vestingDuration);

        assertEq(vesting.releasable(), total - expectedReleasable, "test_Release::21");

        vm.prank(alice);
        vesting.release();

        assertEq(vesting.released(), total, "test_Release::22");
        assertEq(vesting.releasable(), 0, "test_Release::23");
        assertEq(token.balanceOf(alice), total, "test_Release::24");
        assertEq(token.balanceOf(address(vesting)), 0, "test_Release::25");

        MockERC20(address(token)).mint(address(vesting), total);

        assertEq(vesting.releasable(), total, "test_Release::26");

        vm.prank(alice);
        vesting.release();

        assertEq(vesting.released(), 2 * total, "test_Release::27");
        assertEq(vesting.releasable(), 0, "test_Release::28");
        assertEq(token.balanceOf(alice), 2 * total, "test_Release::29");
        assertEq(token.balanceOf(address(vesting)), 0, "test_Release::30");
    }

    function test_ReleaseMoreTokenInMiddle() public {
        MockERC20(address(token)).mint(address(vesting), total);
        vesting.setBeneficiary(alice);

        vm.warp(start + (vestingDuration / 2));

        assertEq(vesting.releasable(), total / 2, "test_ReleaseMoreTokenInMiddle::1");

        vm.prank(alice);
        vesting.release();

        MockERC20(address(token)).mint(address(vesting), total);

        assertEq(vesting.releasable(), total / 2, "test_ReleaseMoreTokenInMiddle::2");

        vm.prank(alice);
        vesting.release();

        assertEq(vesting.released(), total, "test_ReleaseMoreTokenInMiddle::3");
        assertEq(vesting.releasable(), 0, "test_ReleaseMoreTokenInMiddle::4");
        assertEq(token.balanceOf(alice), total, "test_ReleaseMoreTokenInMiddle::5");
        assertEq(token.balanceOf(address(vesting)), total, "test_ReleaseMoreTokenInMiddle::6");

        vm.warp(start + vestingDuration);

        assertEq(vesting.releasable(), total, "test_ReleaseMoreTokenInMiddle::7");

        vm.prank(alice);
        vesting.release();

        assertEq(vesting.released(), 2 * total, "test_ReleaseMoreTokenInMiddle::8");
        assertEq(vesting.releasable(), 0, "test_ReleaseMoreTokenInMiddle::9");
        assertEq(token.balanceOf(alice), 2 * total, "test_ReleaseMoreTokenInMiddle::10");
        assertEq(token.balanceOf(address(vesting)), 0, "test_ReleaseMoreTokenInMiddle::11");
    }

    function test_RevokeBeforeStart() public {
        MockERC20(address(token)).mint(address(vesting), total);
        vesting.setBeneficiary(alice);

        vm.warp(start - 1);

        assertEq(vesting.revoked(), false, "test_RevokeBeforeStart::1");

        vesting.revoke();

        assertEq(vesting.released(), 0, "test_RevokeBeforeStart::2");
        assertEq(vesting.released(), 0, "test_RevokeBeforeStart::3");
        assertEq(vesting.releasable(), 0, "test_RevokeBeforeStart::4");
        assertEq(vesting.vestedAmount(block.timestamp), 0, "test_RevokeBeforeStart::5");
        assertEq(token.balanceOf(alice), 0, "test_RevokeBeforeStart::6");
        assertEq(token.balanceOf(address(vesting)), 0, "test_RevokeBeforeStart::7");
        assertEq(token.balanceOf(address(this)), total, "test_RevokeBeforeStart::8");
    }

    function test_Fuzz_RevokeAfterStartBeforeCliff(uint256 t0) public {
        t0 = bound(t0, start, start + cliffDuration);

        MockERC20(address(token)).mint(address(vesting), total);
        vesting.setBeneficiary(alice);

        vm.warp(t0);

        assertEq(vesting.revoked(), false, "test_Fuzz_RevokeAfterStartBeforeCliff::1");

        vesting.revoke();

        uint256 expectedReleasable = (t0 - start) * total / vestingDuration;

        assertEq(vesting.released(), 0, "test_Fuzz_RevokeAfterStartBeforeCliff::2");
        assertEq(vesting.releasable(), 0, "test_Fuzz_RevokeAfterStartBeforeCliff::3");
        assertEq(vesting.vestedAmount(block.timestamp), 0, "test_Fuzz_RevokeAfterStartBeforeCliff::4");
        assertEq(token.balanceOf(alice), 0, "test_Fuzz_RevokeAfterStartBeforeCliff::5");
        assertEq(token.balanceOf(address(vesting)), expectedReleasable, "test_Fuzz_RevokeAfterStartBeforeCliff::6");
        assertEq(token.balanceOf(address(this)), total - expectedReleasable, "test_Fuzz_RevokeAfterStartBeforeCliff::7");

        vm.prank(alice);
        vesting.release();

        assertEq(vesting.revoked(), true, "test_Fuzz_RevokeAfterStartBeforeCliff::8");
        assertEq(vesting.released(), 0, "test_Fuzz_RevokeAfterStartBeforeCliff::9");
        assertEq(vesting.releasable(), 0, "test_Fuzz_RevokeAfterStartBeforeCliff::10");
        assertEq(vesting.vestedAmount(block.timestamp), 0, "test_Fuzz_RevokeAfterStartBeforeCliff::11");
        assertEq(token.balanceOf(alice), 0, "test_Fuzz_RevokeAfterStartBeforeCliff::12");
        assertEq(token.balanceOf(address(vesting)), expectedReleasable, "test_Fuzz_RevokeAfterStartBeforeCliff::13");
        assertEq(
            token.balanceOf(address(this)), total - expectedReleasable, "test_Fuzz_RevokeAfterStartBeforeCliff::14"
        );

        vm.warp(start + cliffDuration + 1);

        assertEq(vesting.releasable(), expectedReleasable, "test_Fuzz_RevokeAfterStartBeforeCliff::15");

        vm.prank(alice);
        vesting.release();

        assertEq(vesting.released(), expectedReleasable, "test_Fuzz_RevokeAfterStartBeforeCliff::16");
        assertEq(vesting.releasable(), 0, "test_Fuzz_RevokeAfterStartBeforeCliff::17");
        assertEq(vesting.vestedAmount(block.timestamp), expectedReleasable, "test_Fuzz_RevokeAfterStartBeforeCliff::18");
        assertEq(token.balanceOf(alice), expectedReleasable, "test_Fuzz_RevokeAfterStartBeforeCliff::19");
        assertEq(token.balanceOf(address(vesting)), 0, "test_Fuzz_RevokeAfterStartBeforeCliff::20");
        assertEq(
            token.balanceOf(address(this)), total - expectedReleasable, "test_Fuzz_RevokeAfterStartBeforeCliff::21"
        );
    }

    function test_Fuzz_RevokeAfterStartAfterCliff(uint256 t0) public {
        t0 = bound(t0, start + cliffDuration + 1, start + vestingDuration);

        MockERC20(address(token)).mint(address(vesting), total);
        vesting.setBeneficiary(alice);

        vm.warp(t0);

        assertEq(vesting.revoked(), false, "test_Fuzz_RevokeAfterStartAfterCliff::1");

        vesting.revoke();

        uint256 expectedReleasable = (t0 - start) * total / vestingDuration;

        assertEq(vesting.released(), 0, "test_Fuzz_RevokeAfterStartAfterCliff::2");
        assertEq(vesting.releasable(), expectedReleasable, "test_Fuzz_RevokeAfterStartAfterCliff::3");
        assertEq(vesting.vestedAmount(block.timestamp), expectedReleasable, "test_Fuzz_RevokeAfterStartAfterCliff::4");
        assertEq(token.balanceOf(alice), 0, "test_Fuzz_RevokeAfterStartAfterCliff::5");
        assertEq(token.balanceOf(address(vesting)), expectedReleasable, "test_Fuzz_RevokeAfterStartAfterCliff::6");
        assertEq(token.balanceOf(address(this)), total - expectedReleasable, "test_Fuzz_RevokeAfterStartAfterCliff::7");

        vm.prank(alice);
        vesting.release();

        assertEq(vesting.revoked(), true, "test_Fuzz_RevokeAfterStartAfterCliff::8");
        assertEq(vesting.released(), expectedReleasable, "test_Fuzz_RevokeAfterStartAfterCliff::9");
        assertEq(vesting.releasable(), 0, "test_Fuzz_RevokeAfterStartAfterCliff::10");
        assertEq(vesting.vestedAmount(block.timestamp), expectedReleasable, "test_Fuzz_RevokeAfterStartAfterCliff::11");
        assertEq(token.balanceOf(alice), expectedReleasable, "test_Fuzz_RevokeAfterStartAfterCliff::12");
        assertEq(token.balanceOf(address(vesting)), 0, "test_Fuzz_RevokeAfterStartAfterCliff::13");
        assertEq(token.balanceOf(address(this)), total - expectedReleasable, "test_Fuzz_RevokeAfterStartAfterCliff::14");
    }

    function test_RevokeAfterEnd() public {
        MockERC20(address(token)).mint(address(vesting), total);
        vesting.setBeneficiary(alice);

        vm.warp(start + vestingDuration + 1);

        assertEq(vesting.revoked(), false, "test_RevokeAfterEnd::1");

        vesting.revoke();

        assertEq(vesting.released(), 0, "test_RevokeAfterEnd::2");
        assertEq(vesting.releasable(), total, "test_RevokeAfterEnd::3");
        assertEq(vesting.vestedAmount(block.timestamp), total, "test_RevokeAfterEnd::4");
        assertEq(token.balanceOf(alice), 0, "test_RevokeAfterEnd::5");
        assertEq(token.balanceOf(address(vesting)), total, "test_RevokeAfterEnd::6");
        assertEq(token.balanceOf(address(this)), 0, "test_RevokeAfterEnd::7");

        vm.prank(alice);
        vesting.release();

        assertEq(vesting.revoked(), true, "test_RevokeAfterEnd::8");
        assertEq(vesting.released(), total, "test_RevokeAfterEnd::9");
        assertEq(vesting.releasable(), 0, "test_RevokeAfterEnd::10");
        assertEq(vesting.vestedAmount(block.timestamp), total, "test_RevokeAfterEnd::11");
        assertEq(token.balanceOf(alice), total, "test_RevokeAfterEnd::12");
        assertEq(token.balanceOf(address(vesting)), 0, "test_RevokeAfterEnd::13");
        assertEq(token.balanceOf(address(this)), 0, "test_RevokeAfterEnd::14");
    }

    function test_Fuzz_Revoke(uint256 t0, uint256 t1) public {
        t0 = bound(t0, 0, vestingDuration - 1);
        t1 = bound(t1, t0 + 1, vestingDuration);

        MockERC20(address(token)).mint(address(vesting), total);
        vesting.setBeneficiary(alice);

        vm.warp(start + t0);

        assertEq(vesting.revoked(), false, "test_Fuzz_Revoke::1");

        vm.prank(alice);
        vesting.release();

        uint256 vested0 = t0 * total / vestingDuration;
        uint256 released0 = t0 > cliffDuration ? vested0 : 0;

        assertEq(vesting.revoked(), false, "test_Fuzz_Revoke::2");
        assertEq(vesting.released(), released0, "test_Fuzz_Revoke::3");
        assertEq(vesting.releasable(), 0, "test_Fuzz_Revoke::4");
        assertEq(vesting.vestedAmount(block.timestamp), released0, "test_Fuzz_Revoke::5");
        assertEq(token.balanceOf(alice), released0, "test_Fuzz_Revoke::6");
        assertEq(token.balanceOf(address(vesting)), total - released0, "test_Fuzz_Revoke::7");
        assertEq(token.balanceOf(address(this)), 0, "test_Fuzz_Revoke::8");

        vm.warp(start + t1);

        uint256 vested1 = t1 * total / vestingDuration;
        uint256 released1 = t1 > cliffDuration ? vested1 : 0;

        vesting.revoke();

        assertEq(vesting.released(), released0, "test_Fuzz_Revoke::9");
        assertEq(vesting.releasable(), released1 - released0, "test_Fuzz_Revoke::10");
        assertEq(vesting.vestedAmount(block.timestamp), released1, "test_Fuzz_Revoke::11");
        assertEq(token.balanceOf(alice), released0, "test_Fuzz_Revoke::12");
        assertEq(token.balanceOf(address(vesting)), vested1 - released0, "test_Fuzz_Revoke::13");
        assertEq(token.balanceOf(address(this)), total - vested1, "test_Fuzz_Revoke::14");

        vm.prank(alice);
        vesting.release();

        assertEq(vesting.released(), released1, "test_Fuzz_Revoke::15");
        assertEq(vesting.releasable(), 0, "test_Fuzz_Revoke::16");
        assertEq(vesting.vestedAmount(block.timestamp), released1, "test_Fuzz_Revoke::17");
        assertEq(token.balanceOf(alice), released1, "test_Fuzz_Revoke::18");
        assertEq(token.balanceOf(address(vesting)), vested1 - released1, "test_Fuzz_Revoke::19");
        assertEq(token.balanceOf(address(this)), total - vested1, "test_Fuzz_Revoke::20");

        MockERC20(address(token)).mint(address(vesting), total);

        uint256 releasable = t1 > cliffDuration ? total : 0;

        assertEq(vesting.released(), released1, "test_Fuzz_Revoke::21");
        assertEq(vesting.releasable(), releasable, "test_Fuzz_Revoke::22");
        assertEq(vesting.vestedAmount(block.timestamp), releasable + released1, "test_Fuzz_Revoke::23");
        assertEq(token.balanceOf(alice), released1, "test_Fuzz_Revoke::24");
        assertEq(token.balanceOf(address(vesting)), total + (vested1 - released1), "test_Fuzz_Revoke::25");
        assertEq(token.balanceOf(address(this)), total - vested1, "test_Fuzz_Revoke::26");

        vm.prank(alice);
        vesting.release();

        assertEq(vesting.released(), releasable + released1, "test_Fuzz_Revoke::27");
        assertEq(vesting.releasable(), 0, "test_Fuzz_Revoke::28");
        assertEq(vesting.vestedAmount(block.timestamp), releasable + released1, "test_Fuzz_Revoke::29");
        assertEq(token.balanceOf(alice), releasable + released1, "test_Fuzz_Revoke::30");
        assertEq(token.balanceOf(address(vesting)), total - releasable + (vested1 - released1), "test_Fuzz_Revoke::31");
        assertEq(token.balanceOf(address(this)), total - vested1, "test_Fuzz_Revoke::32");

        vm.warp(start + cliffDuration + 1);

        vm.prank(alice);
        vesting.release();

        assertEq(vesting.released(), total + vested1, "test_Fuzz_Revoke::33");
        assertEq(vesting.releasable(), 0, "test_Fuzz_Revoke::34");
        assertEq(vesting.vestedAmount(block.timestamp), total + vested1, "test_Fuzz_Revoke::35");
        assertEq(token.balanceOf(alice), total + vested1, "test_Fuzz_Revoke::36");
        assertEq(token.balanceOf(address(vesting)), 0, "test_Fuzz_Revoke::37");
        assertEq(token.balanceOf(address(this)), total - vested1, "test_Fuzz_Revoke::38");
    }
}

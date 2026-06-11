// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {MoeRegulator} from "../../src/safe-module/MoeRegulator.sol";
import {IMoeRegulator} from "../../src/interfaces/IMoeRegulator.sol";
import {IMasterChef} from "../../src/interfaces/IMasterChef.sol";
import {IMoe} from "../../src/interfaces/IMoe.sol";

interface ISafeModuleManager {
    function enableModule(address module) external;
    function isModuleEnabled(address module) external view returns (bool);
}

interface IOwnable {
    function owner() external view returns (address);
}

/// forge-config: default.evm_version = "shanghai"
contract MoeRegulatorTest is Test {
    uint256 constant FORK_BLOCK = 96522935;

    address constant MULTISIG = 0x244305969310527b29d8Ff3Aa263f686dB61Df6f;
    address constant MASTERCHEF = 0xA756f7D419e1A5cbd656A438443011a7dE1955b5;

    MoeRegulator regulator;

    struct Rate {
        uint256 date;
        uint256 rate;
    }

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mantle"), FORK_BLOCK);

        regulator = new MoeRegulator(MULTISIG, MASTERCHEF);

        vm.prank(MULTISIG);
        ISafeModuleManager(MULTISIG).enableModule(address(regulator));

        assertTrue(ISafeModuleManager(MULTISIG).isModuleEnabled(address(regulator)), "setUp::1");
        assertEq(IOwnable(MASTERCHEF).owner(), MULTISIG, "setUp::2");
    }

    function _schedule() internal pure returns (Rate[] memory s) {
        s = new Rate[](19);
        s[0] = Rate(1780934400, 1.55e18); // 8-Jun-2026 4:00 PM UTC
        s[1] = Rate(1783526400, 1.53e18); // 8-Jul-2026 4:00 PM UTC
        s[2] = Rate(1786204800, 1.5e18); // 8-Aug-2026 4:00 PM UTC
        s[3] = Rate(1788883200, 1.47e18); // 8-Sep-2026 4:00 PM UTC
        s[4] = Rate(1791475200, 1.44e18); // 8-Oct-2026 4:00 PM UTC
        s[5] = Rate(1794153600, 1.41e18); // 8-Nov-2026 4:00 PM UTC
        s[6] = Rate(1796745600, 1.38e18); // 8-Dec-2026 4:00 PM UTC
        s[7] = Rate(1799424000, 1.35e18); // 8-Jan-2027 4:00 PM UTC
        s[8] = Rate(1802102400, 1.32e18); // 8-Feb-2027 4:00 PM UTC
        s[9] = Rate(1804521600, 1.29e18); // 8-Mar-2027 4:00 PM UTC
        s[10] = Rate(1807200000, 1.26e18); // 8-Apr-2027 4:00 PM UTC
        s[11] = Rate(1809792000, 1.23e18); // 8-May-2027 4:00 PM UTC
        s[12] = Rate(1812470400, 1.2e18); // 8-Jun-2027 4:00 PM UTC
        s[13] = Rate(1815062400, 1.17e18); // 8-Jul-2027 4:00 PM UTC
        s[14] = Rate(1817740800, 1.14e18); // 8-Aug-2027 4:00 PM UTC
        s[15] = Rate(1820419200, 1.11e18); // 8-Sep-2027 4:00 PM UTC
        s[16] = Rate(1823011200, 1.08e18); // 8-Oct-2027 4:00 PM UTC
        s[17] = Rate(1825689600, 1.06e18); // 8-Nov-2027 4:00 PM UTC
        s[18] = Rate(1828281600, 1.05e18); // 8-Dec-2027 4:00 PM UTC
    }

    function test_GetScheduledRate_Boundaries() public {
        Rate[] memory s = _schedule();

        (uint32 date, uint64 rate) = regulator.getScheduledRate(s[0].date);
        assertEq(date, uint32(s[0].date), "test_GetScheduledRate_Boundaries::1");
        assertEq(rate, uint64(s[0].rate), "test_GetScheduledRate_Boundaries::2");

        (date, rate) = regulator.getScheduledRate(s[1].date);
        assertEq(date, uint32(s[1].date), "test_GetScheduledRate_Boundaries::3");
        assertEq(rate, uint64(s[1].rate), "test_GetScheduledRate_Boundaries::4");

        (date, rate) = regulator.getScheduledRate(s[18].date + 365 days);
        assertEq(date, uint32(s[18].date), "test_GetScheduledRate_Boundaries::5");
        assertEq(rate, uint64(s[18].rate), "test_GetScheduledRate_Boundaries::6");
    }

    function test_GetScheduledRate_RevertsBeforeFirstDate() public {
        Rate[] memory s = _schedule();

        vm.expectRevert(IMoeRegulator.MoeRegulator__NoRateFound.selector);
        regulator.getScheduledRate(s[0].date - 1);
    }

    function test_UpdateMoePerSecond() public {
        Rate[] memory s = _schedule();

        vm.warp(s[1].date);
        regulator.updateMoePerSecond();

        assertEq(IMasterChef(MASTERCHEF).getMoePerSecond(), s[1].rate, "test_UpdateMoePerSecond::1");
    }

    /// @dev Active entry for a timestamp: the latest scheduled date that is <= ts. found=false before the first date.
    function _active(uint256 ts) internal pure returns (bool found, uint256 date, uint256 rate) {
        Rate[] memory s = _schedule();
        for (uint256 i; i < s.length; i++) {
            if (ts >= s[i].date) {
                (found, date, rate) = (true, s[i].date, s[i].rate);
            }
        }
    }

    function testFuzz_GetScheduledRate(uint32 ts) public {
        (bool found, uint256 date, uint256 rate) = _active(ts);

        if (!found) {
            vm.expectRevert(IMoeRegulator.MoeRegulator__NoRateFound.selector);
            regulator.getScheduledRate(ts);
            return;
        }

        (uint32 actualDate, uint64 actualRate) = regulator.getScheduledRate(ts);
        assertEq(actualDate, uint32(date), "testFuzz_GetScheduledRate::1");
        assertEq(actualRate, uint64(rate), "testFuzz_GetScheduledRate::2");
    }

    function testFuzz_UpdateMoePerSecond(uint256 ts) public {
        Rate[] memory s = _schedule();
        ts = bound(ts, s[0].date, s[18].date);

        (,, uint256 expectedRate) = _active(ts);
        uint256 currentRate = IMasterChef(MASTERCHEF).getMoePerSecond();

        vm.warp(ts);

        if (expectedRate == currentRate) {
            vm.expectRevert(IMoeRegulator.MoeRegulator__NoUpdateNeeded.selector);
            regulator.updateMoePerSecond();
        } else {
            regulator.updateMoePerSecond();
        }

        assertEq(IMasterChef(MASTERCHEF).getMoePerSecond(), expectedRate, "testFuzz_UpdateMoePerSecond::1");
    }

    function test_UpdateRevertsWhenRateWouldNotDecrease() public {
        Rate[] memory s = _schedule();
        vm.warp(s[5].date); // scheduled rate 1.41e18

        // Drive the current rate below the scheduled one so the update would have to raise it.
        vm.prank(MULTISIG);
        IMasterChef(MASTERCHEF).setMoePerSecond(uint96(1e18));

        vm.expectRevert(stdError.assertionError);
        regulator.updateMoePerSecond();
    }

    function test_UpdateAcrossAllDates() public {
        Rate[] memory s = _schedule();

        for (uint256 i; i < s.length; i++) {
            uint256 currentRate = IMasterChef(MASTERCHEF).getMoePerSecond();

            vm.warp(s[i].date);

            if (s[i].rate == currentRate) {
                vm.expectRevert(IMoeRegulator.MoeRegulator__NoUpdateNeeded.selector);
                regulator.updateMoePerSecond();
            } else {
                regulator.updateMoePerSecond();
            }

            assertEq(IMasterChef(MASTERCHEF).getMoePerSecond(), s[i].rate, "test_UpdateAcrossAllDates::1");
        }

        IMoe moe = IMoe(IMasterChef(MASTERCHEF).getMoe());
        assertLt(moe.totalSupply(), moe.getMaxSupply(), "test_UpdateAcrossAllDates::2");

        vm.warp(block.timestamp + 60 days);
        vm.expectRevert(IMoeRegulator.MoeRegulator__NoUpdateNeeded.selector);
        regulator.updateMoePerSecond();

        uint256[] memory pids = new uint256[](1);
        pids[0] = 57;
        IMasterChef(MASTERCHEF).updateAll(pids);

        assertEq(moe.totalSupply(), moe.getMaxSupply(), "test_UpdateAcrossAllDates::3");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMasterChef} from "../interfaces/IMasterChef.sol";
import {ISafe} from "../interfaces/ISafe.sol";
import {IMoeRegulator} from "../interfaces/IMoeRegulator.sol";

/**
 * @title Moe Regulator Contract
 * @dev Safe module that steps the MasterChef MOE per second down along a fixed schedule.
 * It is enabled as a module on the Safe that owns the MasterChef, so that anyone can call
 * updateMoePerSecond to apply the rate scheduled for the current timestamp.
 */
contract MoeRegulator is IMoeRegulator {
    address public immutable override SAFE;
    address public immutable override MASTERCHEF;

    uint256 constant DATE_SIZE = 4;
    uint256 constant ENTRY_SIZE = 12;
    uint256 constant COUNT = 19;

    /**
     * @dev Emission schedule ordered newest date first. Each 12-byte entry packs a 4-byte timestamp
     * followed by the 8-byte MOE per second that applies from that timestamp onwards.
     */
    bytes public constant override MOE_RATES = hex"6cf95d000e92596fd6290000" // 8-Dec-2027 4:00 PM UTC, 1.05e18
        hex"6cd1d0000eb5e06245ea0000" // 8-Nov-2027 4:00 PM UTC, 1.06e18
        hex"6ca8f1800efcee47256c0000" // 8-Oct-2027 4:00 PM UTC, 1.08e18
        hex"6c8164800f67831e74af0000" // 8-Sep-2027 4:00 PM UTC, 1.11e18
        hex"6c5886000fd217f5c3f20000" // 8-Aug-2027 4:00 PM UTC, 1.14e18
        hex"6c2fa780103caccd13350000" // 8-Jul-2027 4:00 PM UTC, 1.17e18
        hex"6c081a8010a741a462780000" // 8-Jun-2027 4:00 PM UTC, 1.20e18
        hex"6bdf3c001111d67bb1bb0000" // 8-May-2027 4:00 PM UTC, 1.23e18
        hex"6bb7af00117c6b5300fe0000" // 8-Apr-2027 4:00 PM UTC, 1.26e18
        hex"6b8ed08011e7002a50410000" // 8-Mar-2027 4:00 PM UTC, 1.29e18
        hex"6b69e680125195019f840000" // 8-Feb-2027 4:00 PM UTC, 1.32e18
        hex"6b41080012bc29d8eec70000" // 8-Jan-2027 4:00 PM UTC, 1.35e18
        hex"6b1829801326beb03e0a0000" // 8-Dec-2026 4:00 PM UTC, 1.38e18
        hex"6af09c80139153878d4d0000" // 8-Nov-2026 4:00 PM UTC, 1.41e18
        hex"6ac7be0013fbe85edc900000" // 8-Oct-2026 4:00 PM UTC, 1.44e18
        hex"6aa0310014667d362bd30000" // 8-Sep-2026 4:00 PM UTC, 1.47e18
        hex"6a77528014d1120d7b160000" // 8-Aug-2026 4:00 PM UTC, 1.50e18
        hex"6a4e7400153ba6e4ca590000" // 8-Jul-2026 4:00 PM UTC, 1.53e18
        hex"6a26e7001582b4c9a9db0000"; // 8-Jun-2026 4:00 PM UTC, 1.55e18

    /**
     * @dev Constructor for the MoeRegulator contract.
     * @param safe The Safe that owns the MasterChef and enables this contract as a module.
     * @param masterchef The MasterChef whose MOE per second is regulated.
     */
    constructor(address safe, address masterchef) {
        SAFE = safe;
        MASTERCHEF = masterchef;
    }

    /**
     * @dev Returns the scheduled entry active at a timestamp, i.e. the most recent one whose date has passed.
     * @param timestamp The timestamp to look up, in seconds.
     * @return The date the returned rate became active.
     * @return The MOE per second scheduled from that date.
     */
    function getScheduledRate(uint256 timestamp) public pure override returns (uint32, uint64) {
        bytes memory moeRates = MOE_RATES;
        for (uint256 i; i < COUNT; i++) {
            (uint32 date, uint64 moePerSecond) = _get(moeRates, i);
            if (timestamp >= date) {
                return (date, moePerSecond);
            }
        }
        revert MoeRegulator__NoRateFound();
    }

    /**
     * @dev Applies the rate scheduled for the current block timestamp to the MasterChef through the Safe module.
     * Reverts when the scheduled rate already matches the current one, and only ever lowers the rate.
     */
    function updateMoePerSecond() external override {
        (uint32 date, uint64 moePerSecond) = getScheduledRate(block.timestamp);
        uint256 currentMoePerSecond = IMasterChef(MASTERCHEF).getMoePerSecond();

        if (moePerSecond == currentMoePerSecond) revert MoeRegulator__NoUpdateNeeded();
        assert(block.timestamp >= date && moePerSecond < currentMoePerSecond);

        ISafe(SAFE)
            .execTransactionFromModule(
                MASTERCHEF, 0, abi.encodeCall(IMasterChef.setMoePerSecond, (moePerSecond)), ISafe.Operation.Call
            );
    }

    /**
     * @dev Decodes the entry at index from a packed schedule.
     * @param rates The packed schedule (see MOE_RATES).
     * @param index The entry index, from 0 (newest) to COUNT - 1 (oldest).
     * @return date The entry's 4-byte timestamp.
     * @return rate The entry's 8-byte MOE per second.
     */
    function _get(bytes memory rates, uint256 index) internal pure returns (uint32 date, uint64 rate) {
        assembly ("memory-safe") {
            date := shr(224, mload(add(add(rates, 0x20), mul(index, ENTRY_SIZE))))
            rate := shr(192, mload(add(add(rates, add(0x20, DATE_SIZE)), mul(index, ENTRY_SIZE))))
        }
    }
}

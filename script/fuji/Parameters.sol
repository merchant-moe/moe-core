// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Parameters.sol";

library Parameters {
    address internal constant multisig = 0xFFC08538077a0455E0F4077823b1A0E3e18Faf0b;

    // Token Distribution
    uint256 internal constant stakingPercent = 0.05e18;
    uint256 internal constant airdropPercent = 0.025e18;

    uint256 internal constant liquidityMiningPercent = 0.3e18;

    uint256 internal constant treasuryPercent = 0.175e18;
    address internal constant treasury = 0xFFC08538077a0455E0F4077823b1A0E3e18Faf0b;

    uint64 internal constant start = 1702918800;

    uint256 internal constant seed1Percent = 0.15e18 / 2;
    address internal constant seed1Beneficiary = 0xFFC08538077a0455E0F4077823b1A0E3e18Faf0b;
    uint64 internal constant seed1Cliff = 365 days;
    uint64 internal constant seed1Duration = 3 * 365 days;

    uint256 internal constant seed2Percent = 0.15e18 / 2;
    address internal constant seed2Beneficiary = 0xFFC08538077a0455E0F4077823b1A0E3e18Faf0b;
    uint64 internal constant seed2Cliff = 365 days;
    uint64 internal constant seed2Duration = 3 * 365 days;

    uint256 internal constant futureFundingPercent = 0.15e18;
    address internal constant futureFundingBeneficiary = 0xFFC08538077a0455E0F4077823b1A0E3e18Faf0b;
    uint64 internal constant futureFundingCliff = 365 days;
    uint64 internal constant futureFundingDuration = 0;

    uint256 internal constant teamPercent = 0.15e18;
    address internal constant teamBeneficiary = 0xFFC08538077a0455E0F4077823b1A0E3e18Faf0b;
    uint64 internal constant teamCliff = 365 days;
    uint64 internal constant teamDuration = 0;

    // Moe
    uint256 internal constant maxSupply = 500_000_000e18;

    // Joe
    address internal constant joe = 0xeAF034F59e660b7b5a71Db280604bd9804307B53;

    // VeMoe
    uint256 internal constant maxVeMoePerMoe = 1_000e18;

    // Factory
    address internal constant feeTo = 0xFFC08538077a0455E0F4077823b1A0E3e18Faf0b;

    // Router
    string internal constant nativeSymbol = "AVAX";
    address internal constant wNative = 0xd00ae08403B9bbb9124bB305C09058E32C39A48c;
}

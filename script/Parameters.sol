// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Parameters.sol";

library Parameters {
    string internal constant chainName = "mantle";
    uint256 internal constant chainId = 5000;
    string internal constant chainAlias = "mantle";
    string internal constant rpcUrl = "https://rpc.mantle.xyz";

    address internal constant multisig = address(1);

    // Token Distribution
    uint256 internal constant stakingPercent = 0.05e18;
    uint256 internal constant airdropPercent = 0.025e18;

    uint256 internal constant liquidityMiningPercent = 0.3e18;

    uint256 internal constant treasuryPercent = 0.175e18;
    address internal constant treasury = address(2);

    uint64 internal constant start = 123456789;

    uint256 internal constant seed1Percent = 0.15e18 / 2;
    address internal constant seed1Beneficiary = address(3);
    uint64 internal constant seed1Cliff = 365 days;
    uint64 internal constant seed1Duration = 3 * 365 days;

    uint256 internal constant seed2Percent = 0.15e18 / 2;
    address internal constant seed2Beneficiary = address(4);
    uint64 internal constant seed2Cliff = 365 days;
    uint64 internal constant seed2Duration = 3 * 365 days;

    uint256 internal constant futureFundingPercent = 0.15e18;
    address internal constant futureFundingBeneficiary = address(5);
    uint64 internal constant futureFundingCliff = 365 days;
    uint64 internal constant futureFundingDuration = 0;

    uint256 internal constant teamPercent = 0.15e18;
    address internal constant teamBeneficiary = address(6);
    uint64 internal constant teamCliff = 365 days;
    uint64 internal constant teamDuration = 0;

    // Moe
    uint256 internal constant maxSupply = 500_000_000e18;

    // VeMoe
    uint256 internal constant maxVeMoePerMoe = 0;

    // Factory
    address internal constant feeTo = address(6);

    // Router
    address internal constant wNative = address(7);
}

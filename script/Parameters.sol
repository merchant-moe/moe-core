// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Parameters.sol";

library Parameters {
    string internal constant chainName = "mantle";
    uint256 internal constant chainId = 5000;
    string internal constant chainAlias = "mantle";
    string internal constant rpcUrl = "https://rpc.mantle.xyz";

    address internal constant multisig = address(1);
    address internal constant treasury = address(2);

    // Token Distribution
    uint256 internal constant liquidityMiningPercent = 0.3e18;
    uint256 internal constant treasuryPercent = 0.175e18;

    uint256 internal constant stakingPercent = 0.05e18;
    uint256 internal constant airdropPercent = 0.025e18;

    uint64 internal constant start = 123456789;

    uint256 internal constant seedPercent = 0.15e18;
    address internal constant seedAddress = address(3);
    uint64 internal constant seedCliff = 365 days;
    uint64 internal constant seedDuration = 3 * 365 days;

    uint256 internal constant futureFundingPercent = 0.15e18;
    address internal constant futureFundingAddress = address(4);
    uint64 internal constant futureFundingCliff = 365 days;
    uint64 internal constant futureFundingDuration = 3 * 365 days;

    uint256 internal constant teamPercent = 0.15e18;
    address internal constant teamAddress = address(5);
    uint64 internal constant teamCliff = 365 days;
    uint64 internal constant teamDuration = 3 * 365 days;

    // Moe
    uint256 internal constant maxSupply = 500_000_000e18;

    // VeMoe
    uint256 internal constant maxVeMoePerMoe = 0;
}

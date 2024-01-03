// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Parameters.sol";

library Parameters {
    string internal constant chainName = "mantle";
    uint256 internal constant chainId = 5000;
    string internal constant chainAlias = "mantle";
    string internal constant rpcUrl = "https://rpc.mantle.xyz";

    address internal constant multisig = 0x244305969310527b29d8Ff3Aa263f686dB61Df6f;

    // Token Distribution
    uint256 internal constant stakingPercent = 0.05e18;
    uint256 internal constant airdropPercent = 0.025e18;

    uint256 internal constant liquidityMiningPercent = 0.3e18;

    uint256 internal constant treasuryPercent = 0.175e18;
    address internal constant treasury = 0x69722b1F681f321c9078136E9223148234eB3BE0;

    uint256 internal constant seed1Percent = 0.15e18 / 2;
    address internal constant futureFunding = 0x685489467Ff83E8fF3d1f63f86bE9b1425a0787d;

    uint256 internal constant seed2Percent = 0.15e18 / 2;
    address internal constant seed1 = 0x06f7a877c4E33642F77CA8D58739D5D7Fa5D2Eea;

    uint256 internal constant futureFundingPercent = 0.15e18;
    address internal constant seed2 = 0xF4e86cb0343f7D2DC1d0515Bc8DD946ce4859130;

    uint256 internal constant teamPercent = 0.15e18;
    address internal constant team = 0x0933824Da7DB2f07DECD82ebbd0A6b5B69F2949a;

    // Moe
    uint256 internal constant maxSupply = 500_000_000e18;

    // Joe
    address internal constant joe = 0x371c7ec6D8039ff7933a2AA28EB827Ffe1F52f07;

    // VeMoe
    uint256 internal constant maxVeMoePerMoe = 1_000e18;

    // Factory
    address internal constant feeTo = multisig;

    // Router
    string internal constant nativeSymbol = "MANTLE";
    address internal constant wNative = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8;
}

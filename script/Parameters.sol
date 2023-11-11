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

    // Moe
    uint256 internal constant initialSupply = 0;
    uint256 internal constant maxSupply = 500_000_000e18;

    // MasterChef
    uint256 internal constant treasuryShare = 0;

    // VeMoe
    uint256 internal constant maxVeMoePerMoe = 0;
}

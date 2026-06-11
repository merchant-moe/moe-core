// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "./Parameters.sol";
import "./Addresses.sol";

import "../../src/safe-module/MoeRegulator.sol";

contract DeployModuleScript is Script {
    function run() public returns (MoeRegulator moeRegulator) {
        // add the custom chain
        setChain(
            Parameters.chainAlias,
            StdChains.ChainData({name: Parameters.chainName, chainId: Parameters.chainId, rpcUrl: Parameters.rpcUrl})
        );

        vm.createSelectFork(StdChains.getChain(Parameters.chainAlias).rpcUrl);

        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(pk);

        moeRegulator = new MoeRegulator(Addresses.devMultisig, Addresses.masterChefProxy);

        vm.stopBroadcast();
    }
}

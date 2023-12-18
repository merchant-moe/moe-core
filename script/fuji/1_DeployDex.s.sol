// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "./Parameters.sol";
import "../../src/dex/MoeFactory.sol";
import "../../src/dex/MoePair.sol";
import "../../src/dex/MoeRouter.sol";
import "../../src/dex/MoeQuoter.sol";

contract DeployDexScript is Script {
    function run()
        public
        returns (MoeFactory moeFactory, address moePairImplentation, MoeRouter router, MoeQuoter quoter)
    {
        vm.createSelectFork(StdChains.getChain("avalanche_fuji").rpcUrl);

        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(pk);

        moeFactory = new MoeFactory(Parameters.feeTo, Parameters.multisig);

        router = new MoeRouter(address(moeFactory), Parameters.wNative);

        quoter = new MoeQuoter(address(moeFactory));

        vm.stopBroadcast();

        moePairImplentation = moeFactory.implementation();
    }
}

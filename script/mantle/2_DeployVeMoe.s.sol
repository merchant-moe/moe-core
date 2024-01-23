// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "./Parameters.sol";
import "./Addresses.sol";
import "../../src/VeMoe.sol";

contract DeployVeMoeScript is Script {
    function run() public returns (VeMoe veMoe) {
        // add the custom chain
        setChain(
            Parameters.chainAlias,
            StdChains.ChainData({name: Parameters.chainName, chainId: Parameters.chainId, rpcUrl: Parameters.rpcUrl})
        );

        vm.createSelectFork(StdChains.getChain(Parameters.chainAlias).rpcUrl, 49731291);

        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(pk);

        veMoe = new VeMoe(
            IMoeStaking(Addresses.moeStakingProxy),
            IMasterChef(Addresses.masterChefProxy),
            IRewarderFactory(Addresses.rewarderFactoryProxy),
            Parameters.maxVeMoePerMoe
        );

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "./Parameters.sol";
import "./Addresses.sol";

import "../../src/VeMoe.sol";
import "../../src/MasterChef.sol";

contract DeployScript is Script {
    function run() public returns (VeMoe veMoe, MasterChef masterChef) {
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

        uint256 sumEmissionShare = Parameters.liquidityMiningPercent + Parameters.treasuryPercent;

        masterChef = new MasterChef(
            IMoe(Addresses.moe),
            IVeMoe(Addresses.veMoeProxy),
            IRewarderFactory(Addresses.rewarderFactoryProxy),
            Parameters.treasuryPercent * 1e18 / sumEmissionShare
        );

        vm.stopBroadcast();
    }
}

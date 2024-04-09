// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "./Parameters.sol";
import "./Addresses.sol";

import "../../src/VeMoe.sol";
import "../../src/MasterChef.sol";
import "../../src/MoeLens.sol";
import "../../src/rewarders/VeMoeRewarder.sol";
import "../../src/rewarders/MasterChefRewarder.sol";

contract DeployScript is Script {
    function run()
        public
        returns (
            VeMoe veMoe,
            MasterChef masterChef,
            MoeLens moeLens,
            VeMoeRewarder veMoeRewarder,
            MasterChefRewarder masterChefRewarder
        )
    {
        // add the custom chain
        setChain(
            Parameters.chainAlias,
            StdChains.ChainData({name: Parameters.chainName, chainId: Parameters.chainId, rpcUrl: Parameters.rpcUrl})
        );

        vm.createSelectFork(StdChains.getChain(Parameters.chainAlias).rpcUrl, 51235190);

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
            address(0),
            Parameters.treasuryPercent * 1e18 / sumEmissionShare
        );

        moeLens = new MoeLens(
            IMasterChef(Addresses.masterChefProxy), IJoeStaking(Addresses.joeStakingProxy), Parameters.nativeSymbol
        );

        veMoeRewarder = new VeMoeRewarder(Addresses.veMoeProxy);

        masterChefRewarder = new MasterChefRewarder(Addresses.masterChefProxy);

        vm.stopBroadcast();
    }
}

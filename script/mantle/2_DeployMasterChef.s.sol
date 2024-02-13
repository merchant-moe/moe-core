// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "./Parameters.sol";
import "../../src/transparent/TransparentUpgradeableProxy2Step.sol";
import "../../src/transparent/ProxyAdmin2Step.sol";
import "../../src/Moe.sol";
import "../../src/MasterChef.sol";
import "../../src/MoeStaking.sol";
import "../../src/JoeStaking.sol";
import "../../src/VeMoe.sol";
import "../../src/StableMoe.sol";
import "../../src/VestingContract.sol";
import "../../src/rewarders/RewarderFactory.sol";
import "../../src/rewarders/JoeStakingRewarder.sol";
import "../../src/rewarders/MasterChefRewarder.sol";
import "../../src/rewarders/VeMoeRewarder.sol";
import "../../src/MoeLens.sol";

contract DeployMasterChefScript is Script {
    IMoe public moe = Moe(0x4515A45337F461A11Ff0FE8aBF3c606AE5dC00c9);
    IVeMoe public veMoe = VeMoe(0x55160b0f39848A7B844f3a562210489dF301dee7);
    IRewarderFactory public rewarderFactory = IRewarderFactory(0xE283Db759720982094de7Fc6Edc49D3adf848943);

    function run() public returns (IMasterChef masterChefImplementation) {
        // add the custom chain
        setChain(
            Parameters.chainAlias,
            StdChains.ChainData({name: Parameters.chainName, chainId: Parameters.chainId, rpcUrl: Parameters.rpcUrl})
        );

        vm.createSelectFork(StdChains.getChain(Parameters.chainAlias).rpcUrl);

        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(pk);

        uint256 sumEmissionShare = Parameters.liquidityMiningPercent + Parameters.treasuryPercent;

        masterChefImplementation = new MasterChef(
            moe, veMoe, rewarderFactory, address(0), Parameters.treasuryPercent * 1e18 / sumEmissionShare
        );

        vm.stopBroadcast();
    }
}

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
        returns (MoeFactory moeFactory, MoePair moePairImplentation, MoeRouter router, MoeQuoter quoter)
    {
        vm.createSelectFork(StdChains.getChain("avalanche_fuji").rpcUrl);

        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(pk);

        uint256 nonce = vm.getNonce(deployer);

        address moeFactoryAddress = computeCreateAddress(deployer, nonce);
        address moePairImplentationAddress = computeCreateAddress(deployer, nonce + 1);

        vm.startBroadcast(pk);

        moeFactory = new MoeFactory(Parameters.feeTo, Parameters.multisig, moePairImplentationAddress);

        moePairImplentation = new MoePair(moeFactoryAddress);

        router = new MoeRouter(address(moeFactory), Parameters.wNative);

        quoter = new MoeQuoter(address(moeFactory));

        vm.stopBroadcast();

        require(MoeFactory(moeFactory).moePairImplementation() == address(moePairImplentation), "DeployDexScript::1");
        require(MoePair(moePairImplentation).factory() == address(moeFactory), "DeployDexScript::2");
    }
}

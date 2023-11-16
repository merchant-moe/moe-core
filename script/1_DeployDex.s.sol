// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/finance/VestingWallet.sol";

import "./Parameters.sol";
import "../src/dex/MoeFactory.sol";
import "../src/dex/MoePair.sol";
import "../src/dex/MoeRouter.sol";

contract DeployDexScript is Script {
    function run() public returns (MoeFactory moeFactory, address moePairImplentation, MoeRouter router) {
        // add the custom chain
        setChain(
            Parameters.chainAlias,
            StdChains.ChainData({name: Parameters.chainName, chainId: Parameters.chainId, rpcUrl: Parameters.rpcUrl})
        );

        vm.createSelectFork(StdChains.getChain(Parameters.chainAlias).rpcUrl);

        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(pk);

        moeFactory = new MoeFactory(Parameters.feeTo, Parameters.multisig);

        router = new MoeRouter(address(moeFactory), Parameters.wNative);

        vm.stopBroadcast();

        moePairImplentation = moeFactory.implementation();
    }
}
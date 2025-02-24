// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "../../src/dex/MoeFactory.sol";
import "../../src/dex/MoePair.sol";
import "../../src/dex/MoeRouter.sol";
import "../../src/dex/MoeQuoter.sol";
import "../../src/dex/MoeHelper.sol";

contract DeployDexScript is Script {
    address DEV_MS = 0x2fbB61a10B96254900C03F1644E9e1d2f5E76DD2;
    address WNATIVE = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;

    function run()
        public
        returns (
            MoeFactory moeFactory,
            MoePair moePairImplentation,
            MoeRouter router,
            MoeQuoter quoter,
            MoeHelper moeHelper
        )
    {
        vm.createSelectFork(StdChains.getChain("avalanche").rpcUrl);

        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(pk);

        uint256 nonce = vm.getNonce(deployer);

        address moeFactoryAddress = computeCreateAddress(deployer, nonce);
        address moePairImplentationAddress = computeCreateAddress(deployer, nonce + 1);

        vm.startBroadcast(pk);

        moeFactory = new MoeFactory(address(0), DEV_MS, moePairImplentationAddress);

        moePairImplentation = new MoePair(moeFactoryAddress);

        router = new MoeRouter(address(moeFactory), WNATIVE);

        quoter = new MoeQuoter(address(moeFactory));

        moeHelper = new MoeHelper();

        vm.stopBroadcast();

        require(moeFactory.moePairImplementation() == address(moePairImplentation), "DeployDexScript::1");
        require(moePairImplentation.factory() == address(moeFactory), "DeployDexScript::2");
    }
}

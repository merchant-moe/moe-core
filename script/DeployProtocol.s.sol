// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "./Parameters.sol";
import "../src/transparent/TransparentUpgradeableProxy2Step.sol";
import "../src/transparent/ProxyAdmin2Step.sol";
import "../src/Moe.sol";
import "../src/MasterChef.sol";
import "../src/MoeStaking.sol";
import "../src/VeMoe.sol";
import "../src/StableMoe.sol";

contract DeployProtocolScript is Script {
    struct Addresses {
        address masterChef;
        address moeStaking;
        address veMoe;
        address sMoe;
    }

    uint256 nonce;

    function run()
        public
        returns (ProxyAdmin2Step proxyAdmin, Moe moe, Addresses memory proxies, Addresses memory implementations)
    {
        // add the custom chain
        setChain(
            Parameters.chainAlias,
            StdChains.ChainData({name: Parameters.chainName, chainId: Parameters.chainId, rpcUrl: Parameters.rpcUrl})
        );

        vm.createSelectFork(StdChains.getChain(Parameters.chainAlias).rpcUrl);

        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(pk);

        nonce = vm.getNonce(deployer);

        address proxyAdminAddress = computeCreateAddress(deployer, nonce++);
        address moeAddress = computeCreateAddress(deployer, nonce++);

        implementations = _computeAddresses(deployer);
        proxies = _computeAddresses(deployer);

        // Deploy ProxyAdmin

        {
            vm.broadcast(pk);
            proxyAdmin = new ProxyAdmin2Step(Parameters.multisig);

            require(proxyAdminAddress == address(proxyAdmin), "run::1");
        }

        // Deploy MOE

        {
            vm.broadcast(pk);
            moe = new Moe(proxies.masterChef, Parameters.initialSupply, Parameters.maxSupply);

            require(moeAddress == address(moe), "run::2");
        }

        // Deploy Implementations

        {
            vm.broadcast(pk);
            MasterChef masterChefImplementation =
                new MasterChef(IMoe(moeAddress), IVeMoe(proxies.veMoe), Parameters.treasuryShare);

            require(implementations.masterChef == address(masterChefImplementation), "run::3");
        }
        {
            vm.broadcast(pk);
            MoeStaking moeStakingImplementation =
                new MoeStaking(IMoe(moeAddress), IVeMoe(proxies.veMoe), IStableMoe(proxies.sMoe));

            require(implementations.moeStaking == address(moeStakingImplementation), "run::4");
        }

        {
            vm.broadcast(pk);
            VeMoe veMoeImplementation = new VeMoe(
            IMoeStaking(proxies.moeStaking), IMasterChef(proxies.masterChef), Parameters.maxVeMoePerMoe
        );

            require(implementations.veMoe == address(veMoeImplementation), "run::5");
        }

        {
            vm.broadcast(pk);
            StableMoe sMoeImplementation = new StableMoe(IMoeStaking(proxies.moeStaking));

            require(implementations.sMoe == address(sMoeImplementation), "run::6");
        }

        // Deploy Proxies

        {
            vm.broadcast(pk);
            TransparentUpgradeableProxy2Step masterChefProxy = new TransparentUpgradeableProxy2Step(
                implementations.masterChef,
                proxyAdmin,
                abi.encodeWithSelector(MasterChef.initialize.selector, Parameters.multisig, Parameters.treasury)
            );

            require(proxies.masterChef == address(masterChefProxy), "run::7");
        }

        {
            vm.broadcast(pk);
            TransparentUpgradeableProxy2Step moeStakingProxy = new TransparentUpgradeableProxy2Step(
                implementations.moeStaking,
                proxyAdmin,
                ""
            );

            require(proxies.moeStaking == address(moeStakingProxy), "run::8");
        }
        {
            vm.broadcast(pk);
            TransparentUpgradeableProxy2Step veMoeProxy = new TransparentUpgradeableProxy2Step(
                implementations.veMoe,
                proxyAdmin,
                abi.encodeWithSelector(VeMoe.initialize.selector, Parameters.multisig)
            );

            require(proxies.veMoe == address(veMoeProxy), "run::9");
        }

        {
            vm.broadcast(pk);
            TransparentUpgradeableProxy2Step sMoeProxy = new TransparentUpgradeableProxy2Step(
                implementations.sMoe,
                proxyAdmin,
                abi.encodeWithSelector(StableMoe.initialize.selector, Parameters.multisig)
            );

            require(proxies.sMoe == address(sMoeProxy), "run::10");
        }
    }

    function _computeAddresses(address deployer) internal returns (Addresses memory addresses) {
        addresses.masterChef = computeCreateAddress(deployer, nonce++);
        addresses.moeStaking = computeCreateAddress(deployer, nonce++);
        addresses.veMoe = computeCreateAddress(deployer, nonce++);
        addresses.sMoe = computeCreateAddress(deployer, nonce++);
    }
}

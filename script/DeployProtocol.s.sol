// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/finance/VestingWallet.sol";

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
        returns (
            ProxyAdmin2Step proxyAdmin,
            Moe moe,
            VestingWallet[] memory vestingWallets,
            Addresses memory proxies,
            Addresses memory implementations
        )
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

        require(
            Parameters.liquidityMiningPercent + Parameters.treasuryPercent + Parameters.stakingPercent
                + Parameters.seedPercent + Parameters.futureFundingPercent + Parameters.teamPercent
                + Parameters.airdropPercent == 1e18,
            "run::0"
        );

        // Deploy ProxyAdmin

        vm.startBroadcast(pk);

        {
            proxyAdmin = new ProxyAdmin2Step(Parameters.multisig);

            require(proxyAdminAddress == address(proxyAdmin), "run::1");
        }

        // Deploy MOE

        {
            uint256 initialShare = Parameters.stakingPercent + Parameters.seedPercent + Parameters.futureFundingPercent
                + Parameters.teamPercent + Parameters.airdropPercent;

            uint256 initialSupply = initialShare * Parameters.maxSupply / 1e18;

            moe = new Moe(proxies.masterChef, initialSupply, Parameters.maxSupply);

            require(moeAddress == address(moe), "run::2");
        }

        // Deploy Implementations

        {
            MasterChef masterChefImplementation = new MasterChef(
                IMoe(moeAddress),
                IVeMoe(proxies.veMoe),
                Parameters.treasuryPercent * 1e18 / (Parameters.treasuryPercent + Parameters.liquidityMiningPercent)
            );

            require(implementations.masterChef == address(masterChefImplementation), "run::3");
        }
        {
            MoeStaking moeStakingImplementation =
                new MoeStaking(IMoe(moeAddress), IVeMoe(proxies.veMoe), IStableMoe(proxies.sMoe));

            require(implementations.moeStaking == address(moeStakingImplementation), "run::4");
        }

        {
            VeMoe veMoeImplementation = new VeMoe(
            IMoeStaking(proxies.moeStaking), IMasterChef(proxies.masterChef), Parameters.maxVeMoePerMoe
        );

            require(implementations.veMoe == address(veMoeImplementation), "run::5");
        }

        {
            StableMoe sMoeImplementation = new StableMoe(IMoeStaking(proxies.moeStaking));

            require(implementations.sMoe == address(sMoeImplementation), "run::6");
        }

        // Deploy Proxies

        {
            TransparentUpgradeableProxy2Step masterChefProxy = new TransparentUpgradeableProxy2Step(
                implementations.masterChef,
                proxyAdmin,
                abi.encodeWithSelector(MasterChef.initialize.selector, Parameters.multisig, Parameters.treasury)
            );

            require(proxies.masterChef == address(masterChefProxy), "run::7");
        }

        {
            TransparentUpgradeableProxy2Step moeStakingProxy = new TransparentUpgradeableProxy2Step(
                implementations.moeStaking,
                proxyAdmin,
                ""
            );

            require(proxies.moeStaking == address(moeStakingProxy), "run::8");
        }
        {
            TransparentUpgradeableProxy2Step veMoeProxy = new TransparentUpgradeableProxy2Step(
                implementations.veMoe,
                proxyAdmin,
                abi.encodeWithSelector(VeMoe.initialize.selector, Parameters.multisig)
            );

            require(proxies.veMoe == address(veMoeProxy), "run::9");
        }

        {
            TransparentUpgradeableProxy2Step sMoeProxy = new TransparentUpgradeableProxy2Step(
                implementations.sMoe,
                proxyAdmin,
                abi.encodeWithSelector(StableMoe.initialize.selector, Parameters.multisig)
            );

            require(proxies.sMoe == address(sMoeProxy), "run::10");
        }

        vestingWallets = new VestingWallet[](3);

        vestingWallets[0] = new VestingWallet(
            Parameters.seedAddress,
            Parameters.start + Parameters.seedCliff,
            Parameters.seedDuration
        );

        vestingWallets[1] = new VestingWallet(
            Parameters.futureFundingAddress,
            Parameters.start + Parameters.futureFundingCliff,
            Parameters.futureFundingDuration
        );

        vestingWallets[2] = new VestingWallet(
            Parameters.teamAddress,
            Parameters.start + Parameters.teamCliff,
            Parameters.teamDuration
        );

        moe.transfer(address(vestingWallets[0]), Parameters.seedPercent * Parameters.maxSupply / 1e18);
        moe.transfer(address(vestingWallets[1]), Parameters.futureFundingPercent * Parameters.maxSupply / 1e18);
        moe.transfer(address(vestingWallets[2]), Parameters.teamPercent * Parameters.maxSupply / 1e18);

        moe.transfer(Parameters.treasury, moe.balanceOf(deployer));

        vm.stopBroadcast();
    }

    function _computeAddresses(address deployer) internal returns (Addresses memory addresses) {
        addresses.masterChef = computeCreateAddress(deployer, nonce++);
        addresses.moeStaking = computeCreateAddress(deployer, nonce++);
        addresses.veMoe = computeCreateAddress(deployer, nonce++);
        addresses.sMoe = computeCreateAddress(deployer, nonce++);
    }
}

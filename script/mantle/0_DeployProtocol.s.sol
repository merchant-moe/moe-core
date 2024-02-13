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

contract DeployProtocolScript is Script {
    struct Addresses {
        address rewarderFactory;
        address masterChef;
        address moeStaking;
        address joeStaking;
        address veMoe;
        address sMoe;
    }

    mapping(IRewarderFactory.RewarderType => IBaseRewarder) _implementations;

    uint256 nonce;

    uint256 pk;
    address deployer;

    function run()
        public
        returns (
            ProxyAdmin2Step proxyAdmin,
            Moe moe,
            IBaseRewarder[3] memory rewarders,
            Addresses memory proxies,
            Addresses memory implementations,
            MoeLens lens
        )
    {
        // add the custom chain
        setChain(
            Parameters.chainAlias,
            StdChains.ChainData({name: Parameters.chainName, chainId: Parameters.chainId, rpcUrl: Parameters.rpcUrl})
        );

        vm.createSelectFork(StdChains.getChain(Parameters.chainAlias).rpcUrl);

        pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        deployer = vm.addr(pk);

        nonce = vm.getNonce(deployer);

        address proxyAdminAddress = computeCreateAddress(deployer, nonce++);
        address moeAddress = computeCreateAddress(deployer, nonce++);

        address[] memory rewarderAddresses = new address[](3);

        rewarderAddresses[0] = computeCreateAddress(deployer, nonce++);
        rewarderAddresses[1] = computeCreateAddress(deployer, nonce++);
        rewarderAddresses[2] = computeCreateAddress(deployer, nonce++);

        implementations = _computeAddresses(deployer);
        proxies = _computeAddresses(deployer);

        address moeLensAddress = computeCreateAddress(deployer, nonce++);

        require(
            Parameters.liquidityMiningPercent + Parameters.treasuryPercent + Parameters.stakingPercent
                + Parameters.seed1Percent + Parameters.seed2Percent + Parameters.futureFundingPercent
                + Parameters.teamPercent + Parameters.airdropPercent == 1e18,
            "run::1"
        );

        // Deploy ProxyAdmin

        vm.startBroadcast(pk);

        {
            proxyAdmin = new ProxyAdmin2Step(Parameters.multisig);

            require(proxyAdminAddress == address(proxyAdmin), "run::2");
        }

        // Deploy MOE

        {
            uint256 initialShare = Parameters.airdropPercent + Parameters.stakingPercent + Parameters.seed1Percent
                + Parameters.seed2Percent;

            uint256 initialSupply = initialShare * Parameters.maxSupply / 1e18;

            moe = new Moe(proxies.masterChef, initialSupply, Parameters.maxSupply);

            require(moeAddress == address(moe), "run::3");
        }

        // Deploy Rewarders

        {
            IBaseRewarder joeStakingRewarder = new JoeStakingRewarder(proxies.joeStaking);
            IBaseRewarder masterChefRewarder = new MasterChefRewarder(proxies.masterChef);
            IBaseRewarder veMoeRewarder = new VeMoeRewarder(proxies.veMoe);

            _implementations[IRewarderFactory.RewarderType.JoeStakingRewarder] = IBaseRewarder(rewarderAddresses[0]);
            _implementations[IRewarderFactory.RewarderType.MasterChefRewarder] = IBaseRewarder(rewarderAddresses[1]);
            _implementations[IRewarderFactory.RewarderType.VeMoeRewarder] = IBaseRewarder(rewarderAddresses[2]);

            rewarders[0] = _implementations[IRewarderFactory.RewarderType.JoeStakingRewarder];
            rewarders[1] = _implementations[IRewarderFactory.RewarderType.MasterChefRewarder];
            rewarders[2] = _implementations[IRewarderFactory.RewarderType.VeMoeRewarder];

            require(rewarderAddresses[0] == address(joeStakingRewarder), "run::4");
            require(rewarderAddresses[1] == address(masterChefRewarder), "run::5");
            require(rewarderAddresses[2] == address(veMoeRewarder), "run::6");
        }

        // Deploy Implementations

        {
            RewarderFactory rewarderFactoryImplementation = new RewarderFactory();

            require(implementations.rewarderFactory == address(rewarderFactoryImplementation), "run::7");
        }

        {
            uint256 sumEmissionShare = Parameters.liquidityMiningPercent + Parameters.treasuryPercent;

            MasterChef masterChefImplementation = new MasterChef(
                IMoe(moeAddress),
                IVeMoe(proxies.veMoe),
                IRewarderFactory(proxies.rewarderFactory),
                address(0),
                Parameters.treasuryPercent * 1e18 / sumEmissionShare
            );

            require(implementations.masterChef == address(masterChefImplementation), "run::8");
        }

        {
            MoeStaking moeStakingImplementation =
                new MoeStaking(IMoe(moeAddress), IVeMoe(proxies.veMoe), IStableMoe(proxies.sMoe));

            require(implementations.moeStaking == address(moeStakingImplementation), "run::9");
        }

        {
            JoeStaking joeStakingImplementation =
                new JoeStaking(IERC20(Parameters.joe), IRewarderFactory(proxies.rewarderFactory));

            require(implementations.joeStaking == address(joeStakingImplementation), "run::10");
        }

        {
            VeMoe veMoeImplementation = new VeMoe(
                IMoeStaking(proxies.moeStaking),
                IMasterChef(proxies.masterChef),
                IRewarderFactory(proxies.rewarderFactory),
                Parameters.maxVeMoePerMoe
            );

            require(implementations.veMoe == address(veMoeImplementation), "run::11");
        }

        {
            StableMoe sMoeImplementation = new StableMoe(IMoeStaking(proxies.moeStaking));

            require(implementations.sMoe == address(sMoeImplementation), "run::12");
        }

        // Deploy Proxies

        {
            IRewarderFactory.RewarderType[] memory rewarderTypes = new IRewarderFactory.RewarderType[](3);
            IBaseRewarder[] memory rewarderImplementations = new IBaseRewarder[](3);

            rewarderTypes[0] = IRewarderFactory.RewarderType.JoeStakingRewarder;
            rewarderImplementations[0] = _implementations[IRewarderFactory.RewarderType.JoeStakingRewarder];

            rewarderTypes[1] = IRewarderFactory.RewarderType.MasterChefRewarder;
            rewarderImplementations[1] = _implementations[IRewarderFactory.RewarderType.MasterChefRewarder];

            rewarderTypes[2] = IRewarderFactory.RewarderType.VeMoeRewarder;
            rewarderImplementations[2] = _implementations[IRewarderFactory.RewarderType.VeMoeRewarder];

            bytes memory data = abi.encodeWithSelector(
                RewarderFactory.initialize.selector, Parameters.multisig, rewarderTypes, rewarderImplementations
            );

            TransparentUpgradeableProxy2Step rewarderFactoryProxy =
                new TransparentUpgradeableProxy2Step(implementations.rewarderFactory, proxyAdmin, data);

            require(proxies.rewarderFactory == address(rewarderFactoryProxy), "run::13");
        }

        {
            TransparentUpgradeableProxy2Step masterChefProxy = new TransparentUpgradeableProxy2Step(
                implementations.masterChef,
                proxyAdmin,
                abi.encodeWithSelector(
                    MasterChef.initialize.selector,
                    Parameters.multisig,
                    Parameters.treasury,
                    Parameters.futureFunding,
                    Parameters.team,
                    Parameters.futureFundingPercent * Parameters.maxSupply / 1e18,
                    Parameters.teamPercent * Parameters.maxSupply / 1e18
                )
            );

            require(proxies.masterChef == address(masterChefProxy), "run::14");
        }

        {
            TransparentUpgradeableProxy2Step moeStakingProxy =
                new TransparentUpgradeableProxy2Step(implementations.moeStaking, proxyAdmin, "");

            require(proxies.moeStaking == address(moeStakingProxy), "run::15");
        }

        {
            TransparentUpgradeableProxy2Step joeStakingProxy = new TransparentUpgradeableProxy2Step(
                implementations.joeStaking,
                proxyAdmin,
                abi.encodeWithSelector(JoeStaking.initialize.selector, Parameters.multisig)
            );

            require(proxies.joeStaking == address(joeStakingProxy), "run::16");
        }

        {
            TransparentUpgradeableProxy2Step veMoeProxy = new TransparentUpgradeableProxy2Step(
                implementations.veMoe,
                proxyAdmin,
                abi.encodeWithSelector(VeMoe.initialize.selector, Parameters.multisig)
            );

            require(proxies.veMoe == address(veMoeProxy), "run::17");
        }

        {
            TransparentUpgradeableProxy2Step sMoeProxy = new TransparentUpgradeableProxy2Step(
                implementations.sMoe,
                proxyAdmin,
                abi.encodeWithSelector(StableMoe.initialize.selector, Parameters.multisig)
            );

            require(proxies.sMoe == address(sMoeProxy), "run::18");
        }

        // Deploy MoeLens

        {
            lens =
                new MoeLens(IMasterChef(proxies.masterChef), IJoeStaking(proxies.joeStaking), Parameters.nativeSymbol);

            require(moeLensAddress == address(lens), "run::19");
        }

        require(
            moe.balanceOf(deployer)
                == Parameters.maxSupply * Parameters.airdropPercent / 1e18
                    + Parameters.maxSupply * Parameters.stakingPercent / 1e18
                    + Parameters.maxSupply * Parameters.seed1Percent / 1e18
                    + Parameters.maxSupply * Parameters.seed2Percent / 1e18,
            "run::20"
        );

        moe.transfer(Parameters.seed1, Parameters.seed1Percent * Parameters.maxSupply / 1e18);
        moe.transfer(Parameters.seed2, Parameters.seed2Percent * Parameters.maxSupply / 1e18);

        moe.transfer(Parameters.multisig, moe.balanceOf(deployer));

        vm.stopBroadcast();
    }

    function _computeAddresses(address deployer_) internal returns (Addresses memory addresses) {
        addresses.rewarderFactory = computeCreateAddress(deployer_, nonce++);
        addresses.masterChef = computeCreateAddress(deployer_, nonce++);
        addresses.moeStaking = computeCreateAddress(deployer_, nonce++);
        addresses.joeStaking = computeCreateAddress(deployer_, nonce++);
        addresses.veMoe = computeCreateAddress(deployer_, nonce++);
        addresses.sMoe = computeCreateAddress(deployer_, nonce++);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "./Parameters.sol";
import "../src/transparent/TransparentUpgradeableProxy2Step.sol";
import "../src/transparent/ProxyAdmin2Step.sol";
import "../src/Moe.sol";
import "../src/MasterChef.sol";
import "../src/MoeStaking.sol";
import "../src/JoeStaking.sol";
import "../src/VeMoe.sol";
import "../src/StableMoe.sol";
import "../src/VestingContract.sol";
import "../src/rewarders/RewarderFactory.sol";
import "../src/rewarders/JoeStakingRewarder.sol";
import "../src/rewarders/MasterChefRewarder.sol";
import "../src/rewarders/VeMoeRewarder.sol";

contract DeployProtocolScript is Script {
    struct Addresses {
        address rewarderFactory;
        address masterChef;
        address moeStaking;
        address joeStaking;
        address veMoe;
        address sMoe;
    }

    struct Vestings {
        address futureFunding;
        address team;
        address seed1;
        address seed2;
    }

    uint256 nonce;

    function run()
        public
        returns (
            ProxyAdmin2Step proxyAdmin,
            Moe moe,
            IBaseRewarder[3] memory rewarders,
            Addresses memory proxies,
            Addresses memory implementations,
            Vestings memory vestings
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
        vestings = _computeVestings(deployer);
        proxies = _computeAddresses(deployer);

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

        // Deploy Implementations

        {
            RewarderFactory rewarderFactoryImplementation = new RewarderFactory();

            require(implementations.rewarderFactory == address(rewarderFactoryImplementation), "run::3");
        }

        {
            uint256 sumEmissionShare = Parameters.liquidityMiningPercent + Parameters.treasuryPercent
                + Parameters.futureFundingPercent + Parameters.teamPercent;

            MasterChef masterChefImplementation = new MasterChef(
                IMoe(moeAddress),
                IVeMoe(proxies.veMoe),
                IRewarderFactory(proxies.rewarderFactory),
                Parameters.treasuryPercent * 1e18 / sumEmissionShare,
                Parameters.futureFundingPercent * 1e18 / sumEmissionShare,
                Parameters.teamPercent * 1e18 / sumEmissionShare
            );

            require(implementations.masterChef == address(masterChefImplementation), "run::4");
        }

        {
            MoeStaking moeStakingImplementation =
                new MoeStaking(IMoe(moeAddress), IVeMoe(proxies.veMoe), IStableMoe(proxies.sMoe));

            require(implementations.moeStaking == address(moeStakingImplementation), "run::5");
        }

        {
            JoeStaking joeStakingImplementation =
                new JoeStaking(IERC20(Parameters.joe), IRewarderFactory(proxies.rewarderFactory));

            require(implementations.joeStaking == address(joeStakingImplementation), "run::6");
        }

        {
            VeMoe veMoeImplementation = new VeMoe(
                IMoeStaking(proxies.moeStaking),
                IMasterChef(proxies.masterChef),
                IRewarderFactory(proxies.rewarderFactory),
                Parameters.maxVeMoePerMoe
            );

            require(implementations.veMoe == address(veMoeImplementation), "run::6");
        }

        {
            StableMoe sMoeImplementation = new StableMoe(IMoeStaking(proxies.moeStaking));

            require(implementations.sMoe == address(sMoeImplementation), "run::7");
        }

        // Deploy Vestings

        {
            VestingContract futureFundingVesting = new VestingContract(
                proxies.masterChef,
                IERC20(moeAddress),
                Parameters.start + Parameters.futureFundingCliff,
                Parameters.futureFundingDuration
            );

            require(vestings.futureFunding == address(futureFundingVesting), "run::12");
        }

        {
            VestingContract teamVesting = new VestingContract(
                proxies.masterChef,
                IERC20(moeAddress),
                Parameters.start + Parameters.teamCliff,
                Parameters.teamDuration
            );

            require(vestings.team == address(teamVesting), "run::13");
        }

        {
            VestingContract seed1Vesting = new VestingContract(
                proxies.masterChef,
                IERC20(moeAddress),
                Parameters.start + Parameters.seed1Cliff,
                Parameters.seed1Duration
            );

            require(vestings.seed1 == address(seed1Vesting), "run::14");
        }

        {
            VestingContract seed2Vesting = new VestingContract(
                proxies.masterChef,
                IERC20(moeAddress),
                Parameters.start + Parameters.seed2Cliff,
                Parameters.seed2Duration
            );

            require(vestings.seed2 == address(seed2Vesting), "run::15");
        }

        // Deploy Proxies

        {
            TransparentUpgradeableProxy2Step rewarderFactoryProxy = new TransparentUpgradeableProxy2Step(
                implementations.rewarderFactory,
                proxyAdmin,
                abi.encodeWithSelector(RewarderFactory.initialize.selector, Parameters.multisig)
            );

            require(proxies.rewarderFactory == address(rewarderFactoryProxy), "run::7");
        }

        {
            TransparentUpgradeableProxy2Step masterChefProxy = new TransparentUpgradeableProxy2Step(
                implementations.masterChef,
                proxyAdmin,
                abi.encodeWithSelector(MasterChef.initialize.selector, Parameters.multisig, Parameters.treasury, vestings.futureFunding, vestings.team)
            );

            require(proxies.masterChef == address(masterChefProxy), "run::8");
        }

        {
            TransparentUpgradeableProxy2Step moeStakingProxy = new TransparentUpgradeableProxy2Step(
                implementations.moeStaking,
                proxyAdmin,
                ""
            );

            require(proxies.moeStaking == address(moeStakingProxy), "run::9");
        }

        {
            TransparentUpgradeableProxy2Step joeStakingProxy = new TransparentUpgradeableProxy2Step(
                implementations.joeStaking,
                proxyAdmin,
                ""
            );

            require(proxies.joeStaking == address(joeStakingProxy), "run::10");
        }

        {
            TransparentUpgradeableProxy2Step veMoeProxy = new TransparentUpgradeableProxy2Step(
                implementations.veMoe,
                proxyAdmin,
                abi.encodeWithSelector(VeMoe.initialize.selector, Parameters.multisig)
            );

            require(proxies.veMoe == address(veMoeProxy), "run::10");
        }

        {
            TransparentUpgradeableProxy2Step sMoeProxy = new TransparentUpgradeableProxy2Step(
                implementations.sMoe,
                proxyAdmin,
                abi.encodeWithSelector(StableMoe.initialize.selector, Parameters.multisig)
            );

            require(proxies.sMoe == address(sMoeProxy), "run::11");
        }

        // Deploy Rewarders

        {
            rewarders[0] = new JoeStakingRewarder(proxies.joeStaking);
            rewarders[1] = new MasterChefRewarder(proxies.masterChef);
            rewarders[2] = new VeMoeRewarder(proxies.veMoe);
        }

        moe.transfer(vestings.seed1, Parameters.seed1Percent * Parameters.maxSupply / 1e18);
        moe.transfer(vestings.seed2, Parameters.seed2Percent * Parameters.maxSupply / 1e18);

        require(
            moe.balanceOf(deployer)
                == Parameters.maxSupply * Parameters.airdropPercent / 1e18
                    + Parameters.maxSupply * Parameters.stakingPercent / 1e18,
            "run::16"
        );

        moe.transfer(Parameters.treasury, moe.balanceOf(deployer));

        vm.stopBroadcast();
    }

    function _computeAddresses(address deployer) internal returns (Addresses memory addresses) {
        addresses.rewarderFactory = computeCreateAddress(deployer, nonce++);
        addresses.masterChef = computeCreateAddress(deployer, nonce++);
        addresses.moeStaking = computeCreateAddress(deployer, nonce++);
        addresses.joeStaking = computeCreateAddress(deployer, nonce++);
        addresses.veMoe = computeCreateAddress(deployer, nonce++);
        addresses.sMoe = computeCreateAddress(deployer, nonce++);
    }

    function _computeVestings(address deployer) internal returns (Vestings memory vestings) {
        vestings.futureFunding = computeCreateAddress(deployer, nonce++);
        vestings.team = computeCreateAddress(deployer, nonce++);
        vestings.seed1 = computeCreateAddress(deployer, nonce++);
        vestings.seed2 = computeCreateAddress(deployer, nonce++);
    }
}

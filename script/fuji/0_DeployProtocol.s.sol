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

    struct Vestings {
        address futureFunding;
        address team;
        address seed1;
        address seed2;
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
            Vestings memory vestings,
            MoeLens lens
        )
    {
        vm.createSelectFork(StdChains.getChain("avalanche_fuji").rpcUrl);

        pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        deployer = vm.addr(pk);

        nonce = vm.getNonce(deployer);

        address proxyAdminAddress = computeCreateAddress(deployer, nonce++);
        address moeAddress = computeCreateAddress(deployer, nonce++);
        address moeLensAddress = computeCreateAddress(deployer, nonce++);

        address[] memory rewarderAddresses = new address[](3);

        rewarderAddresses[0] = computeCreateAddress(deployer, nonce++);
        rewarderAddresses[1] = computeCreateAddress(deployer, nonce++);
        rewarderAddresses[2] = computeCreateAddress(deployer, nonce++);

        implementations = _computeAddresses(deployer);
        vestings = _computeVestings(deployer);
        proxies = _computeAddresses(deployer);

        address joeAddress = computeCreateAddress(deployer, nonce++);

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

        // Deploy Lens

        {
            lens =
                new MoeLens(IMasterChef(proxies.masterChef), IJoeStaking(proxies.joeStaking), Parameters.nativeSymbol);

            require(moeLensAddress == address(lens), "run::3");
        }

        // Deploy Rewarders

        {
            IBaseRewarder joeStakingRewarder = new JoeStakingRewarder(proxies.joeStaking);
            IBaseRewarder masterChefRewarder = new MasterChefRewarder(proxies.masterChef);
            IBaseRewarder veMoeRewarder = new VeMoeRewarder(proxies.veMoe);

            _implementations[IRewarderFactory.RewarderType.JoeStakingRewarder] = joeStakingRewarder;
            _implementations[IRewarderFactory.RewarderType.MasterChefRewarder] = masterChefRewarder;
            _implementations[IRewarderFactory.RewarderType.VeMoeRewarder] = veMoeRewarder;

            rewarders[0] = _implementations[IRewarderFactory.RewarderType.JoeStakingRewarder];
            rewarders[1] = _implementations[IRewarderFactory.RewarderType.MasterChefRewarder];
            rewarders[2] = _implementations[IRewarderFactory.RewarderType.VeMoeRewarder];

            require(rewarderAddresses[0] == address(joeStakingRewarder), "run::3");
            require(rewarderAddresses[1] == address(masterChefRewarder), "run::3");
            require(rewarderAddresses[2] == address(veMoeRewarder), "run::3");
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
                new JoeStaking(IERC20(joeAddress), IRewarderFactory(proxies.rewarderFactory));

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
                proxies.masterChef, IERC20(moeAddress), Parameters.start + Parameters.teamCliff, Parameters.teamDuration
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

            require(proxies.rewarderFactory == address(rewarderFactoryProxy), "run::7");
        }

        {
            TransparentUpgradeableProxy2Step masterChefProxy = new TransparentUpgradeableProxy2Step(
                implementations.masterChef,
                proxyAdmin,
                abi.encodeWithSelector(
                    MasterChef.initialize.selector,
                    Parameters.multisig,
                    Parameters.treasury,
                    vestings.futureFunding,
                    vestings.team
                )
            );

            require(proxies.masterChef == address(masterChefProxy), "run::8");
        }

        {
            TransparentUpgradeableProxy2Step moeStakingProxy =
                new TransparentUpgradeableProxy2Step(implementations.moeStaking, proxyAdmin, "");

            require(proxies.moeStaking == address(moeStakingProxy), "run::9");
        }

        {
            TransparentUpgradeableProxy2Step joeStakingProxy = new TransparentUpgradeableProxy2Step(
                implementations.joeStaking,
                proxyAdmin,
                abi.encodeWithSelector(JoeStaking.initialize.selector, Parameters.multisig)
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

        // Deploy JOE

        {
            Moe joe = new Moe(Parameters.multisig, 0, 500_000_000e18);

            require(joeAddress == address(joe), "run::3");
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

    function _computeAddresses(address deployer_) internal returns (Addresses memory addresses) {
        addresses.rewarderFactory = computeCreateAddress(deployer_, nonce++);
        addresses.masterChef = computeCreateAddress(deployer_, nonce++);
        addresses.moeStaking = computeCreateAddress(deployer_, nonce++);
        addresses.joeStaking = computeCreateAddress(deployer_, nonce++);
        addresses.veMoe = computeCreateAddress(deployer_, nonce++);
        addresses.sMoe = computeCreateAddress(deployer_, nonce++);
    }

    function _computeVestings(address deployer_) internal returns (Vestings memory vestings) {
        vestings.futureFunding = computeCreateAddress(deployer_, nonce++);
        vestings.team = computeCreateAddress(deployer_, nonce++);
        vestings.seed1 = computeCreateAddress(deployer_, nonce++);
        vestings.seed2 = computeCreateAddress(deployer_, nonce++);
    }
}

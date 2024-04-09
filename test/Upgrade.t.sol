pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../script/mantle/3_Deploy.s.sol";

import "../src/transparent/ProxyAdmin2Step.sol";
import "../src/transparent/TransparentUpgradeableProxy2Step.sol";

contract UpgradeTest is Test {
    function test_UpgradeVeMoe() public {
        DeployScript deployer = new DeployScript();

        (VeMoe newVeMoeImplementation, MasterChef newMasterChefImplementation,,,) = deployer.run();

        assertEq(
            address(IVeMoe(Addresses.veMoeProxy).getMoeStaking()),
            address(newVeMoeImplementation.getMoeStaking()),
            "test_UpgradeVeMoe::1"
        );
        assertEq(
            address(IVeMoe(Addresses.veMoeProxy).getMasterChef()),
            address(newVeMoeImplementation.getMasterChef()),
            "test_UpgradeVeMoe::2"
        );
        assertEq(
            address(IVeMoe(Addresses.veMoeProxy).getRewarderFactory()),
            address(newVeMoeImplementation.getRewarderFactory()),
            "test_UpgradeVeMoe::3"
        );
        assertEq(
            IVeMoe(Addresses.veMoeProxy).getMaxVeMoePerMoe(),
            newVeMoeImplementation.getMaxVeMoePerMoe(),
            "test_UpgradeVeMoe::4"
        );

        assertEq(
            address(IMasterChef(Addresses.masterChefProxy).getMoe()),
            address(newMasterChefImplementation.getMoe()),
            "test_UpgradeVeMoe::5"
        );
        assertEq(
            address(IMasterChef(Addresses.masterChefProxy).getVeMoe()),
            address(newMasterChefImplementation.getVeMoe()),
            "test_UpgradeVeMoe::6"
        );
        assertEq(
            address(IMasterChef(Addresses.masterChefProxy).getRewarderFactory()),
            address(newMasterChefImplementation.getRewarderFactory()),
            "test_UpgradeVeMoe::7"
        );
        assertEq(
            IMasterChef(Addresses.masterChefProxy).getTreasuryShare(),
            newMasterChefImplementation.getTreasuryShare(),
            "test_UpgradeVeMoe::8"
        );

        address moeStaking = address(IVeMoe(Addresses.veMoeProxy).getMoeStaking());
        address masterChef = address(IVeMoe(Addresses.veMoeProxy).getMasterChef());
        address rewarderFactory = address(IVeMoe(Addresses.veMoeProxy).getRewarderFactory());
        address moe = address(IMasterChef(Addresses.masterChefProxy).getMoe());
        address veMoe = address(IMasterChef(Addresses.masterChefProxy).getVeMoe());

        uint256 maxVeMoePerMoe = IVeMoe(Addresses.veMoeProxy).getMaxVeMoePerMoe();
        uint256 totalVotes = IVeMoe(Addresses.veMoeProxy).getTotalVotes();
        uint256 topPidsTotalVotes = IVeMoe(Addresses.veMoeProxy).getTopPidsTotalVotes();
        uint256 veMoePerSecond = IVeMoe(Addresses.veMoeProxy).getVeMoePerSecondPerMoe();
        uint256 treasuryShare = IMasterChef(Addresses.masterChefProxy).getTreasuryShare();

        vm.startPrank(Parameters.multisig);
        ProxyAdmin2Step(Addresses.proxyAdmin).upgradeAndCall(
            ITransparentUpgradeableProxy(Addresses.veMoeProxy),
            address(newVeMoeImplementation),
            abi.encodeWithSelector(VeMoe.initialize.selector, Addresses.devMultisig)
        );

        ProxyAdmin2Step(Addresses.proxyAdmin).upgradeAndCall(
            ITransparentUpgradeableProxy(Addresses.masterChefProxy), address(newMasterChefImplementation), ""
        );

        vm.stopPrank();

        assertEq(address(IVeMoe(Addresses.veMoeProxy).getMoeStaking()), moeStaking, "test_UpgradeVeMoe::9");
        assertEq(address(IVeMoe(Addresses.veMoeProxy).getMasterChef()), masterChef, "test_UpgradeVeMoe::10");
        assertEq(address(IVeMoe(Addresses.veMoeProxy).getRewarderFactory()), rewarderFactory, "test_UpgradeVeMoe::11");
        assertEq(IVeMoe(Addresses.veMoeProxy).getMaxVeMoePerMoe(), maxVeMoePerMoe, "test_UpgradeVeMoe::12");

        assertEq(IVeMoe(Addresses.veMoeProxy).getTotalVotes(), totalVotes, "test_UpgradeVeMoe::13");
        assertEq(IVeMoe(Addresses.veMoeProxy).getTopPidsTotalVotes(), topPidsTotalVotes, "test_UpgradeVeMoe::14");
        assertEq(IVeMoe(Addresses.veMoeProxy).getVeMoePerSecondPerMoe(), veMoePerSecond, "test_UpgradeVeMoe::15");

        assertEq(address(IMasterChef(Addresses.masterChefProxy).getMoe()), moe, "test_UpgradeVeMoe::16");
        assertEq(address(IMasterChef(Addresses.masterChefProxy).getVeMoe()), veMoe, "test_UpgradeVeMoe::17");
        assertEq(
            address(IMasterChef(Addresses.masterChefProxy).getRewarderFactory()),
            rewarderFactory,
            "test_UpgradeVeMoe::18"
        );
        assertEq(IMasterChef(Addresses.masterChefProxy).getTreasuryShare(), treasuryShare, "test_UpgradeVeMoe::19");

        uint256 nbFarm = IMasterChef(Addresses.masterChefProxy).getNumberOfFarms();
        uint256 totalWeight = IVeMoe(Addresses.veMoeProxy).getTotalWeight();
        uint256 moePerSecond = IMasterChef(Addresses.masterChefProxy).getMoePerSecond();

        assertEq(totalWeight, topPidsTotalVotes, "test_UpgradeVeMoe::20");

        for (uint256 i = 0; i < nbFarm; i++) {
            uint256 expectedWeight =
                IVeMoe(Addresses.veMoeProxy).isInTopPoolIds(i) ? IVeMoe(Addresses.veMoeProxy).getVotes(i) : 0;

            assertEq(IVeMoe(Addresses.veMoeProxy).getWeight(i), expectedWeight, "test_UpgradeVeMoe::21");
            assertEq(
                IMasterChef(Addresses.masterChefProxy).getMoePerSecondForPid(i),
                totalWeight == 0 ? 0 : (expectedWeight * moePerSecond) / totalWeight,
                "test_UpgradeVeMoe::22"
            );
        }
    }
}

pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../script/mantle/2_DeployVeMoe.s.sol";
import "../src/transparent/ProxyAdmin2Step.sol";
import "../src/transparent/TransparentUpgradeableProxy2Step.sol";

contract UpgradeVeMoeTest is Test {
    function test_UpgradeVeMoe() public {
        DeployVeMoeScript deployer = new DeployVeMoeScript();

        VeMoe newVeMoeImplementation = deployer.run();

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

        address moeStaking = address(IVeMoe(Addresses.veMoeProxy).getMoeStaking());
        address masterChef = address(IVeMoe(Addresses.veMoeProxy).getMasterChef());
        address rewarderFactory = address(IVeMoe(Addresses.veMoeProxy).getRewarderFactory());
        uint256 maxVeMoePerMoe = IVeMoe(Addresses.veMoeProxy).getMaxVeMoePerMoe();

        uint256 totalVotes = IVeMoe(Addresses.veMoeProxy).getTotalVotes();
        uint256 topPidsTotalVotes = IVeMoe(Addresses.veMoeProxy).getTopPidsTotalVotes();
        uint256 veMoePerSecond = IVeMoe(Addresses.veMoeProxy).getVeMoePerSecondPerMoe();

        vm.prank(Parameters.multisig);
        ProxyAdmin2Step(Addresses.proxyAdmin).upgradeAndCall(
            ITransparentUpgradeableProxy(Addresses.veMoeProxy),
            address(newVeMoeImplementation),
            abi.encodeWithSelector(VeMoe.initialize.selector, Addresses.devMultisig)
        );

        assertEq(address(IVeMoe(Addresses.veMoeProxy).getMoeStaking()), moeStaking, "test_UpgradeVeMoe::5");
        assertEq(address(IVeMoe(Addresses.veMoeProxy).getMasterChef()), masterChef, "test_UpgradeVeMoe::6");
        assertEq(address(IVeMoe(Addresses.veMoeProxy).getRewarderFactory()), rewarderFactory, "test_UpgradeVeMoe::7");
        assertEq(IVeMoe(Addresses.veMoeProxy).getMaxVeMoePerMoe(), maxVeMoePerMoe, "test_UpgradeVeMoe::8");

        assertEq(IVeMoe(Addresses.veMoeProxy).getTotalVotes(), totalVotes, "test_UpgradeVeMoe::9");
        assertEq(IVeMoe(Addresses.veMoeProxy).getTopPidsTotalVotes(), topPidsTotalVotes, "test_UpgradeVeMoe::10");
        assertEq(IVeMoe(Addresses.veMoeProxy).getVeMoePerSecondPerMoe(), veMoePerSecond, "test_UpgradeVeMoe::11");

        assertEq(IVeMoe(Addresses.veMoeProxy).getTotalWeight(), 0, "test_UpgradeVeMoe::12");
    }
}

pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../script/mantle/Parameters.sol";
import "../script/mantle/Addresses.sol";

import "../src/MoeLens.sol";
import "../src/rewarders/VeMoeRewarder.sol";

contract UpgradeTest is Test {
    MoeLens moeLens;

    function setUp() public {
        setChain(
            Parameters.chainAlias,
            StdChains.ChainData({name: Parameters.chainName, chainId: Parameters.chainId, rpcUrl: Parameters.rpcUrl})
        );

        vm.createSelectFork(StdChains.getChain(Parameters.chainAlias).rpcUrl, 50344826);

        moeLens = new MoeLens(
            IMasterChef(Addresses.masterChefProxy), IJoeStaking(Addresses.joeStakingProxy), Parameters.nativeSymbol
        );
    }

    function test_GetVersion() public {
        MoeLens.Rewarder memory rewarder = moeLens.getVeMoeRewarderDataAt(218);

        assertEq(rewarder.version, 1, "test_GetVersion::1");

        VeMoeRewarder imp = new VeMoeRewarder(Addresses.veMoeProxy);

        vm.prank(Addresses.devMultisig);
        IRewarderFactory(Addresses.rewarderFactoryProxy).setRewarderImplementation(
            IRewarderFactory.RewarderType.VeMoeRewarder, IBaseRewarder(imp)
        );

        IRewarderFactory(Addresses.rewarderFactoryProxy).createRewarder(
            IRewarderFactory.RewarderType.VeMoeRewarder, IERC20(address(0)), 0
        );
        uint256 length = IRewarderFactory(Addresses.rewarderFactoryProxy).getRewarderCount(
            IRewarderFactory.RewarderType.VeMoeRewarder
        );

        rewarder = moeLens.getVeMoeRewarderDataAt(length - 1);

        assertEq(rewarder.version, 2, "test_GetVersion::2");
    }
}

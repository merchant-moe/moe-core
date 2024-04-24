pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../script/mantle/Parameters.sol";
import {Addresses as mantleAddresses} from "../script/mantle/Addresses.sol";
import {Addresses as fujiAddresses} from "../script/fuji/Addresses.sol";

import "../src/MoeLens.sol";
import "../src/rewarders/VeMoeRewarder.sol";

contract UpgradeTest is Test {
    MoeLens moeLens;

    function test_GetVersion() public {
        setChain(
            Parameters.chainAlias,
            StdChains.ChainData({name: Parameters.chainName, chainId: Parameters.chainId, rpcUrl: Parameters.rpcUrl})
        );

        vm.createSelectFork(StdChains.getChain(Parameters.chainAlias).rpcUrl, 50344826);

        moeLens = new MoeLens(
            IMasterChef(mantleAddresses.masterChefProxy),
            IJoeStaking(mantleAddresses.joeStakingProxy),
            Parameters.nativeSymbol
        );

        MoeLens.Rewarder memory rewarder = moeLens.getVeMoeRewarderDataAt(218);

        assertEq(rewarder.version, 1, "test_GetVersion::1");

        VeMoeRewarder imp = new VeMoeRewarder(mantleAddresses.veMoeProxy);

        vm.prank(mantleAddresses.devMultisig);
        IRewarderFactory(mantleAddresses.rewarderFactoryProxy).setRewarderImplementation(
            IRewarderFactory.RewarderType.VeMoeRewarder, IBaseRewarder(imp)
        );

        IRewarderFactory(mantleAddresses.rewarderFactoryProxy).createRewarder(
            IRewarderFactory.RewarderType.VeMoeRewarder, IERC20(address(0)), 0
        );
        uint256 length = IRewarderFactory(mantleAddresses.rewarderFactoryProxy).getRewarderCount(
            IRewarderFactory.RewarderType.VeMoeRewarder
        );

        rewarder = moeLens.getVeMoeRewarderDataAt(length - 1);

        assertEq(rewarder.version, 2, "test_GetVersion::2");
    }

    function test_GetReserves() public {
        vm.createSelectFork(StdChains.getChain("avalanche_fuji").rpcUrl, 32197710);

        moeLens =
            new MoeLens(IMasterChef(fujiAddresses.masterChefProxy), IJoeStaking(fujiAddresses.joeStakingProxy), "AVAX");

        MoeLens.FarmData memory farms = moeLens.getFarmData(3, 5, address(0));

        assertEq(farms.farms[0].reserves.token0.symbol, "Mock COIN", "test_GetReserves::1");
        assertEq(farms.farms[0].reserves.token1.symbol, "Mock USDC", "test_GetReserves::2");
        assertEq(farms.farms[0].reserves.binStep, 0, "test_GetReserves::3");
        assertEq(farms.farms[0].lpToken.symbol, "MoeLP", "test_GetReserves::4");

        assertEq(farms.farms[1].reserves.token0.symbol, "USDT", "test_GetReserves::5");
        assertEq(farms.farms[1].reserves.token1.symbol, "USDC", "test_GetReserves::6");
        assertEq(farms.farms[1].reserves.binStep, 1, "test_GetReserves::7");
        assertEq(farms.farms[1].lpToken.symbol, "Vote LB USDT-USDC:1", "test_GetReserves::8");

        assertEq(farms.farms[2].reserves.token0.symbol, "WAVAX", "test_GetReserves::9");
        assertEq(farms.farms[2].reserves.token1.symbol, "USDC", "test_GetReserves::10");
        assertEq(farms.farms[2].reserves.binStep, 15, "test_GetReserves::11");
        assertEq(farms.farms[2].lpToken.symbol, "Vote LB WAVAX-USDC:15", "test_GetReserves::12");
    }
}

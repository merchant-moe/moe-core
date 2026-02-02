pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../script/mantle/Parameters.sol";
import {Addresses as mantleAddresses} from "../script/mantle/Addresses.sol";
import {Addresses as fujiAddresses} from "../script/fuji/Addresses.sol";

import "../src/transparent/TransparentUpgradeableProxy2Step.sol";
import "../src/MoeLens.sol";
import "../src/MasterChef.sol";
import "../src/rewarders/VeMoeRewarder.sol";

contract MoeLensTest is Test {
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

        address implementation = address(
            new MasterChef(
                IMoe(fujiAddresses.moe),
                IVeMoe(fujiAddresses.veMoeProxy),
                IRewarderFactory(fujiAddresses.rewarderFactoryProxy),
                address(0),
                IMasterChef(fujiAddresses.masterChefProxy).getTreasuryShare()
            )
        );

        vm.prank(fujiAddresses.devMultisig);
        ProxyAdmin2Step(fujiAddresses.proxyAdmin).upgradeAndCall(
            ITransparentUpgradeableProxy(fujiAddresses.masterChefProxy), address(implementation), ""
        );

        moeLens =
            new MoeLens(IMasterChef(fujiAddresses.masterChefProxy), IJoeStaking(fujiAddresses.joeStakingProxy), "AVAX");

        MoeLens.FarmData memory farms = moeLens.getFarmData(3, 5, address(0));

        assertEq(farms.staticShare, 0, "test_GetReserves::1");
        assertEq(farms.totalStaticPoolShares, 0, "test_GetReserves::2");
        assertEq(farms.treasuryShare, 368421052631578947, "test_GetReserves::3");

        assertEq(farms.farms[0].isVotable, true, "test_GetReserves::4");
        assertEq(farms.farms[0].isStatic, false, "test_GetReserves::5");
        assertEq(farms.farms[0].isRewardable, true, "test_GetReserves::6");
        assertEq(farms.farms[0].staticPoolShare, 0, "test_GetReserves::7");
        assertEq(farms.farms[0].reserves.token0.symbol, "Mock COIN", "test_GetReserves::8");
        assertEq(farms.farms[0].reserves.token1.symbol, "Mock USDC", "test_GetReserves::9");
        assertEq(farms.farms[0].reserves.binStep, 0, "test_GetReserves::10");
        assertEq(farms.farms[0].reserves.baseFee, 0.003e18, "test_GetReserves::11");
        assertEq(farms.farms[0].reserves.variableFee, 0, "test_GetReserves::12");
        assertEq(farms.farms[0].reserves.protocolShare, uint256(1e18) / 6, "test_GetReserves::13");
        assertEq(farms.farms[0].lpToken.symbol, "MoeLP", "test_GetReserves::14");

        assertEq(farms.farms[1].isVotable, true, "test_GetReserves::15");
        assertEq(farms.farms[1].isStatic, false, "test_GetReserves::16");
        assertEq(farms.farms[0].isRewardable, true, "test_GetReserves::17");
        assertEq(farms.farms[1].staticPoolShare, 0, "test_GetReserves::18");
        assertEq(farms.farms[1].reserves.token0.symbol, "USDT", "test_GetReserves::19");
        assertEq(farms.farms[1].reserves.token1.symbol, "USDC", "test_GetReserves::20");
        assertEq(farms.farms[1].reserves.binStep, 1, "test_GetReserves::21");
        assertEq(farms.farms[1].reserves.baseFee, 0.0002e18, "test_GetReserves::22");
        assertEq(farms.farms[1].reserves.variableFee, 0, "test_GetReserves::23");
        assertEq(farms.farms[1].reserves.protocolShare, 0.05e18, "test_GetReserves::24");
        assertEq(farms.farms[1].lpToken.symbol, "Vote LB USDT-USDC:1", "test_GetReserves::25");

        assertEq(farms.farms[2].isVotable, true, "test_GetReserves::26");
        assertEq(farms.farms[2].isStatic, false, "test_GetReserves::27");
        assertEq(farms.farms[0].isRewardable, true, "test_GetReserves::28");
        assertEq(farms.farms[2].staticPoolShare, 0, "test_GetReserves::29");
        assertEq(farms.farms[2].reserves.token0.symbol, "WAVAX", "test_GetReserves::30");
        assertEq(farms.farms[2].reserves.token1.symbol, "USDC", "test_GetReserves::31");
        assertEq(farms.farms[2].reserves.binStep, 15, "test_GetReserves::32");
        assertEq(farms.farms[2].reserves.baseFee, 0.0015e18, "test_GetReserves::33");
        assertEq(farms.farms[2].reserves.variableFee, 0, "test_GetReserves::34");
        assertEq(farms.farms[2].reserves.protocolShare, 0.1e18, "test_GetReserves::35");
        assertEq(farms.farms[2].lpToken.symbol, "Vote LB WAVAX-USDC:15", "test_GetReserves::36");

        vm.startPrank(fujiAddresses.devMultisig);
        uint256[] memory pids = new uint256[](3);
        pids[0] = 1;
        pids[1] = 2;
        pids[2] = 5;
        IVeMoe(fujiAddresses.veMoeProxy).setTopPoolIds(pids);

        IMasterChef(fujiAddresses.masterChefProxy).setStaticShare(0.5e18);
        IMasterChef(fujiAddresses.masterChefProxy).setStaticPoolShare(3, 1e18);
        IMasterChef(fujiAddresses.masterChefProxy).setStaticPoolShare(4, 2e18);
        vm.stopPrank();

        farms = moeLens.getFarmData(3, 5, address(0));

        assertEq(farms.staticShare, 0.5e18, "test_GetReserves::37");
        assertEq(farms.totalStaticPoolShares, 3e18, "test_GetReserves::38");
        assertEq(farms.treasuryShare, 368421052631578947, "test_GetReserves::39");

        assertEq(farms.farms[0].isVotable, false, "test_GetReserves::40");
        assertEq(farms.farms[0].isStatic, true, "test_GetReserves::41");
        assertEq(farms.farms[0].isRewardable, true, "test_GetReserves::42");
        assertEq(farms.farms[0].staticPoolShare, 1e18, "test_GetReserves::43");
        assertEq(farms.farms[0].reserves.token0.symbol, "Mock COIN", "test_GetReserves::44");
        assertEq(farms.farms[0].reserves.token1.symbol, "Mock USDC", "test_GetReserves::45");
        assertEq(farms.farms[0].reserves.binStep, 0, "test_GetReserves::46");
        assertEq(farms.farms[0].reserves.baseFee, 0.003e18, "test_GetReserves::47");
        assertEq(farms.farms[0].reserves.variableFee, 0, "test_GetReserves::48");
        assertEq(farms.farms[0].reserves.protocolShare, uint256(1e18) / 6, "test_GetReserves::49");
        assertEq(farms.farms[0].lpToken.symbol, "MoeLP", "test_GetReserves::50");

        assertEq(farms.farms[1].isVotable, false, "test_GetReserves::51");
        assertEq(farms.farms[1].isStatic, true, "test_GetReserves::52");
        assertEq(farms.farms[0].isRewardable, true, "test_GetReserves::53");
        assertEq(farms.farms[1].staticPoolShare, 2e18, "test_GetReserves::54");
        assertEq(farms.farms[1].reserves.token0.symbol, "USDT", "test_GetReserves::55");
        assertEq(farms.farms[1].reserves.token1.symbol, "USDC", "test_GetReserves::56");
        assertEq(farms.farms[1].reserves.binStep, 1, "test_GetReserves::57");
        assertEq(farms.farms[1].reserves.baseFee, 0.0002e18, "test_GetReserves::58");
        assertEq(farms.farms[1].reserves.variableFee, 0, "test_GetReserves::59");
        assertEq(farms.farms[1].reserves.protocolShare, 0.05e18, "test_GetReserves::60");
        assertEq(farms.farms[1].lpToken.symbol, "Vote LB USDT-USDC:1", "test_GetReserves::61");

        assertEq(farms.farms[2].isVotable, true, "test_GetReserves::62");
        assertEq(farms.farms[2].isStatic, false, "test_GetReserves::63");
        assertEq(farms.farms[0].isRewardable, true, "test_GetReserves::64");
        assertEq(farms.farms[2].staticPoolShare, 0, "test_GetReserves::65");
        assertEq(farms.farms[2].reserves.token0.symbol, "WAVAX", "test_GetReserves::66");
        assertEq(farms.farms[2].reserves.token1.symbol, "USDC", "test_GetReserves::67");
        assertEq(farms.farms[2].reserves.binStep, 15, "test_GetReserves::68");
        assertEq(farms.farms[2].reserves.baseFee, 0.0015e18, "test_GetReserves::69");
        assertEq(farms.farms[2].reserves.variableFee, 0, "test_GetReserves::70");
        assertEq(farms.farms[2].reserves.protocolShare, 0.1e18, "test_GetReserves::71");
        assertEq(farms.farms[2].lpToken.symbol, "Vote LB WAVAX-USDC:15", "test_GetReserves::72");

        vm.prank(fujiAddresses.devMultisig);
        IMasterChef(fujiAddresses.masterChefProxy).setStaticPoolShare(4, 0);

        farms = moeLens.getFarmData(4, 4, address(0));

        assertEq(farms.farms[0].isVotable, false, "test_GetReserves::73");
        assertEq(farms.farms[0].isStatic, false, "test_GetReserves::74");
        assertEq(farms.farms[0].isRewardable, false, "test_GetReserves::75");
    }
}
